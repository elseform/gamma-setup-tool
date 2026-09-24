# GAMMA Setup Tool

Status: current development version, 0.90 (`dev` branch).

Native macOS tool for creating a Wine `.app` wrapper around an existing S.T.A.L.K.E.R. G.A.M.M.A. installation, using [gamma-wine-engine](https://github.com/elseform/gamma-wine-engine) and DXMT. It does not install G.A.M.M.A.

This README describes the current source. Published builds are available on the [Releases page](https://github.com/elseform/gamma-setup-tool/releases); check the version and release notes before following these instructions with an older build.

## Requirements

- An Apple Silicon Mac running macOS 15 or newer, with Rosetta 2 for the Wine engine.
- An existing G.A.M.M.A. installation and its `ModOrganizer.exe`, or another Windows executable to launch.
- Python 3 available to setup. The backend checks `/usr/bin/python3`, `/opt/homebrew/bin/python3`, then `/usr/local/bin/python3`.
- `zstd` for `.tar.zst` engine archives. `.tar.xz` archives are also supported.
- Internet access for automatic engine resolution and missing runtime downloads. For offline setup, select a local engine archive and provide or cache the runtime files described below.

An engine archive can declare a higher minimum macOS or setup-tool version, which setup checks before creating the wrapper.

## Create a Wrapper

Extract the downloaded setup-tool archive and open `GAMMA Setup Tool.app`, or [build the current source](#build-and-test). Builds made by `build.sh` are ad-hoc signed, not notarized.

1. Enter an application name. The wrapper is created in `~/Applications`; an existing app with the same name is refused.
2. Click **Choose…** and select `ModOrganizer.exe` from your existing installation. You can select another `.exe` as the launch target instead.
3. Continue to **Wrapper settings**. Leave **Engine archive** empty for automatic download, or choose a local `.tar.zst` or `.tar.xz` archive.
4. Optionally expand **Microsoft redistributables** to see which runtime files are already present or choose a folder containing downloaded copies. Leave **Save setup log** enabled for troubleshooting.
5. Continue to **Review settings**, then click **Create wrapper**.
6. Launch the created app from Finder. Use the adjacent `<app name> Configurator` alias to change game and graphics settings, including launch arguments.

Setup checks the selected executable exists; it does not validate the contents or health of the G.A.M.M.A. installation.

## Engine Selection and Downloads

With **Engine archive** empty, setup resolves the newest valid `engine-*` release from `elseform/gamma-wine-engine`, ordered by engine version. It downloads the archive and verifies its SHA-256 against the release manifest. Cached archives are checked by checksum before reuse.

A local archive is an explicit override, but it still passes the version gate. Setup refuses engines older than the highest of the currently resolved release, the cached release version, and the minimum supported by this setup-tool build. Equal or newer versions are accepted. Unreadable manifests and unidentifiable builds are rejected; there is no wizard option to bypass the gate.

Automatic selection needs access to the release listing and manifest even when the archive is cached. If no release can be resolved, select a local archive. Local selection can proceed offline using the cached version floor or the compiled minimum.

The wizard creates DXMT wrappers with the engine's declared runtime dependencies. It has no renderer, Wine-version, Winetricks-verb, or display-mode selector.

## Runtime Files and Installation Changes

The engine archive supplies the runtime manifest and fetcher. Setup obtains the declared files from checksum-pinned downloads, reusing a supplied folder before the cache. The current runtime list includes:

- `VC_redist.x64.exe` — Visual C++ 2015–2022 Redistributable.
- `directx_Jun2010_redist.exe` — DirectX End-User Runtime, June 2010.
- `d3dcompiler_47.dll` — the Microsoft compiler DLL redistributed through Mozilla's `fxc2` repository.

The engine manifest controls the actual files and checksums; selecting a folder does not bypass verification.

Setup mounts the game root as `G:` and the host root as `Z:`. The wizard derives the game root as the parent of the selected executable's containing directory; review the mapping before creating the wrapper, especially with a custom executable.

After wrapper creation, setup checks the bundled USVFS files against the selected executable's folder. It updates them only if that folder contains `ModOrganizer.exe`. Existing files that differ are backed up inside that folder under `gamma-setup-tool-backups/usvfs-<timestamp>/` before replacement; matching files are left alone. A custom executable outside a ModOrganizer folder receives no USVFS files.

## Settings, Logs, and Caches

Each wrapper has its own Wine prefix and settings outside the app bundle:

```text
~/Applications/<app name>.app
~/Applications/<app name> Configurator
~/Library/Application Support/<app name>/prefix/
~/Library/Application Support/<app name>/app.env
```

Setup seeds the wrapper's defaults, with no default launch arguments. Change settings through its Configurator. If the Finder alias could not be created, open `Contents/Resources/Configurator.app` inside the wrapper.

With **Save setup log** enabled, setup events are written to:

```text
~/Library/Logs/gamma-setup-tool/<app name>-YYYYMMDD-HHMMSS.log
```

Downloads are cached at:

```text
~/Library/Application Support/gamma-setup-tool/cache/gamma-wine-engine/
~/Library/Application Support/gamma-setup-tool/cache/redist-installers/
```

The engine cache also contains `latest-release.json`, the saved release version used by the gate. For failed setup, use the detailed log and the Discord support link in the app.

## Build and Test

Building requires Apple's Command Line Tools or Xcode. From the repository root:

```sh
./build.sh
```

This compiles the GUI and backend with `swiftc` for Apple Silicon and macOS 15, builds and ad-hoc signs `dist/GAMMA Setup Tool.app`, then replaces `~/Applications/GAMMA Setup Tool.app` with that build. No Xcode project or sibling engine checkout is required to build the setup tool.

- `./build.sh run` builds and runs the GUI from `dist/` without installing it.
- `./build.sh clean` removes `dist/`.
- `./test.sh` runs Swift unit tests, backend CLI integration tests, and a build smoke test. The smoke test invokes `build.sh`, so it also installs the setup tool into `~/Applications`.

Developers can set `GAMMA_ENGINE_ARTIFACTS_DIR` in the app's environment to prefill the local archive field with the most recently modified `.tar.zst` or `.tar.xz` in that directory. The selected archive still passes the version gate.

### Source Layout

| Path | Responsibility |
| --- | --- |
| `sources/GAMMASetupTool/` | SwiftUI wizard, setup state, request construction, and progress display. |
| `sources/GAMMASetupCore/` | Shared models, engine release resolution, checksum verification, version gate, wrapper pipeline, and USVFS updates. |
| `sources/GAMMASetupEngine/` | `gamma-setup-engine` CLI backend, called by the GUI through `create-wine-engine`. |
| `sources/GAMMASetupTool/Resources/wine-engine/interactive_setup.py` | Canonical wrapper-creation script, bundled by `build.sh`. |
| `tests/` | Swift unit tests and shell CLI integration tests. |

`Package.swift` defines both executable products. `build.sh` assembles the distributable app bundle and its backend and resources.
