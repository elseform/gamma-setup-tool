#!/usr/bin/env bash
# CLI integration tests for gamma-setup-engine.
#
# The engine now exposes exactly one real command, `create-wine-engine`
# (sources/GAMMASetupEngine/main.swift), which drives gamma-wine-engine's
# interactive_setup.py. The former preflight / install-dependencies /
# install-dependency / create commands went away with the Sikarugir pipeline,
# so everything here exercises argument handling and the failure paths that
# WineEngineSetup.create() reaches *before* it touches the filesystem.
set -euo pipefail

ROOT_DIR="${1:?root dir is required}"
ENGINE="${2:?engine binary is required}"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/gamma-setup-engine-cli.XXXXXX")"
trap 'rm -rf "$TMP_ROOT"' EXIT

# Never reach GitHub: with a real release published, release resolution would
# download a 130 MB engine. Port 9 (discard) on loopback refuses immediately.
export GAMMA_ENGINE_RELEASES_URL="http://127.0.0.1:9/releases"

fail() {
  printf 'not ok - %s\n' "$1" >&2
  exit 1
}

assert_contains() {
  local file="$1"
  local expected="$2"
  if ! grep -Fq -- "$expected" "$file"; then
    printf 'Expected %s to contain:\n%s\n\nActual:\n' "$file" "$expected" >&2
    cat "$file" >&2
    exit 1
  fi
}

# Runs the engine, expecting a non-zero exit, and captures both streams.
# Usage: expect_failure <label> <stdout-file> <stderr-file> -- <args...>
expect_failure() {
  local label="$1" out="$2" err="$3"
  shift 4 # label, out, err, and the literal --
  if "$ENGINE" "$@" >"$out" 2>"$err"; then
    fail "$label: expected a non-zero exit"
  fi
}

# A local engine archive is used as given, so tests past archive resolution
# only need the file to exist; interactive_setup.py is never reached.
write_archive_fixture() {
  local path="$1"
  local staging
  staging="$(mktemp -d "$TMP_ROOT/fixture.XXXXXX")"
  mkdir -p "$staging/wswine.bundle"
  (cd "$staging" && tar -cJf "$path" wswine.bundle)
}

# A request whose only interesting property is which field is missing.
# appParent points somewhere that must stay untouched, so we can prove no
# wrapper was created on the failure paths.
write_request() {
  local file="$1"
  local archive_path="$2"
  local mo2_path="$3"
  cat >"$file" <<JSON
{
  "archivePath" : "$archive_path",
  "appName" : "stalker-gamma",
  "appParent" : "$TMP_ROOT/apps",
  "gammaRoot" : "$TMP_ROOT/stage/GAMMA",
  "mo2Path" : "$mo2_path",
  "yes" : true,
  "skipFinderAlias" : true,
  "forceExe" : false,
  "updateUSVFS" : false,
  "usvfsSource" : ""
}
JSON
}

printf '==> CLI help names the only supported command\n'
"$ENGINE" --help >"$TMP_ROOT/help.out"
assert_contains "$TMP_ROOT/help.out" "create-wine-engine"
assert_contains "$TMP_ROOT/help.out" "--request-file"
"$ENGINE" -h >/dev/null

printf '==> CLI with no arguments prints usage and exits 2\n'
set +e
"$ENGINE" >"$TMP_ROOT/noargs.out" 2>"$TMP_ROOT/noargs.err"
noargs_status=$?
set -e
if [ "$noargs_status" -ne 2 ]; then
  fail "expected exit 2 with no arguments, got $noargs_status"
fi
assert_contains "$TMP_ROOT/noargs.err" "Usage:"

printf '==> CLI rejects an unknown command and still emits a completed event\n'
expect_failure "unknown command" "$TMP_ROOT/bogus.out" "$TMP_ROOT/bogus.err" -- bogus
assert_contains "$TMP_ROOT/bogus.err" "error: unknown command: bogus"
# The GUI reads the NDJSON stream, not the exit code, so a failure has to be
# visible there too.
assert_contains "$TMP_ROOT/bogus.out" '"success":false'
assert_contains "$TMP_ROOT/bogus.out" '"type":"completed"'

printf '==> CLI requires --request-file\n'
expect_failure "missing --request-file" "$TMP_ROOT/norequest.out" "$TMP_ROOT/norequest.err" \
  -- create-wine-engine
assert_contains "$TMP_ROOT/norequest.err" "--request-file is required"

printf '==> CLI rejects a missing and a malformed request file\n'
expect_failure "missing request file" "$TMP_ROOT/absent.out" "$TMP_ROOT/absent.err" \
  -- create-wine-engine --request-file "$TMP_ROOT/does-not-exist.json"
assert_contains "$TMP_ROOT/absent.err" "error:"

printf '{bad json}\n' >"$TMP_ROOT/bad-request.json"
expect_failure "malformed request file" "$TMP_ROOT/bad.out" "$TMP_ROOT/bad.err" \
  -- create-wine-engine --request-file "$TMP_ROOT/bad-request.json"
assert_contains "$TMP_ROOT/bad.err" "error:"

printf '==> CLI falls back to release resolution with no local archive given\n'
# An empty archivePath is not itself an error any more — WineEngineSetup then
# tries to resolve the newest published gamma-wine-engine release. That fails
# here because GAMMA_ENGINE_RELEASES_URL points at a closed port, and the
# failure comes from EngineReleaseResolver, not a bare "missing archive"
# refusal.
write_request "$TMP_ROOT/no-archive.json" "" ""
expect_failure "no archive source" "$TMP_ROOT/no-archive.out" "$TMP_ROOT/no-archive.err" \
  -- create-wine-engine --request-file "$TMP_ROOT/no-archive.json"
assert_contains "$TMP_ROOT/no-archive.err" "could not resolve a published release"

printf '==> CLI rejects an archivePath that does not exist\n'
write_request "$TMP_ROOT/ghost-archive.json" "$TMP_ROOT/ghost.tar.zst" ""
expect_failure "ghost archive" "$TMP_ROOT/ghost.out" "$TMP_ROOT/ghost.err" \
  -- create-wine-engine --request-file "$TMP_ROOT/ghost-archive.json"
assert_contains "$TMP_ROOT/ghost.err" "engine archive not found:"

printf '==> Archive resolution runs before launch-target resolution\n'
# A present archive gets past resolveArchive, so the next failure proves the
# ordering inside WineEngineSetup.create() without ever reaching
# interactive_setup.py.
write_archive_fixture "$TMP_ROOT/present.tar.xz"
write_request "$TMP_ROOT/no-mo2.json" "$TMP_ROOT/present.tar.xz" ""
expect_failure "no launch target" "$TMP_ROOT/no-mo2.out" "$TMP_ROOT/no-mo2.err" \
  -- create-wine-engine --request-file "$TMP_ROOT/no-mo2.json"
assert_contains "$TMP_ROOT/no-mo2.err" "mo2Path is required when exeRelPath is not explicitly overridden"

printf '==> CLI rejects an mo2Path outside gammaRoot\n'
mkdir -p "$TMP_ROOT/elsewhere"
touch "$TMP_ROOT/elsewhere/ModOrganizer.exe"
write_request "$TMP_ROOT/outside.json" "$TMP_ROOT/present.tar.xz" "$TMP_ROOT/elsewhere/ModOrganizer.exe"
expect_failure "mo2 outside gammaRoot" "$TMP_ROOT/outside.out" "$TMP_ROOT/outside.err" \
  -- create-wine-engine --request-file "$TMP_ROOT/outside.json"
assert_contains "$TMP_ROOT/outside.err" "is not inside gammaRoot"

printf '==> No wrapper was created on any failure path\n'
if [ -e "$TMP_ROOT/apps" ]; then
  fail "appParent was created despite every run failing"
fi

printf 'All CLI integration tests passed.\n'
