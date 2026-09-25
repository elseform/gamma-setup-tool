# Changelog

## 0.90 — unreleased

### Main improvements

- Replaced the Sikarugir wrapper pipeline with the `gamma-wine-engine` engine archive
  (CrossOver 26.3 / Wine 11 with DXMT), driven by this tool's own
  `interactive_setup.py`. The wizard no longer installs Homebrew casks or resolves
  Winetricks itself; the engine archive carries the graphics backend and a pinned list of
  the Visual C++ and DirectX files it needs, which are downloaded from Microsoft's own
  installers during setup and cached.
- Requires an Apple Silicon Mac running macOS 15 or newer, as do the wrappers it creates.
- `Save setup log` now writes a log to `~/Library/Logs/gamma-setup-tool/`.
- The graphics backend is DXMT. D3DMetal is no longer bundled, and the renderer,
  display-resolution, and drive-mapping options are gone with the pipeline that used
  them — the engine mounts both `Z:` and `G:` on its own.
- Setup progress is now reported directly from the engine script rather than parsed out
  of its console output.
- The bundled ModOrganizer `usvfs` files are only written into a folder that contains
  `ModOrganizer.exe`; a custom launch executable elsewhere no longer receives them. MO2's
  own copies that differ are backed up to `gamma-setup-tool-backups/usvfs-<timestamp>/`
  in the MO2 folder before being replaced.
- With no local archive selected, setup downloads the newest published
  `gamma-wine-engine` release, verifies its checksum, and caches it. A local
  `.tar.zst` or `.tar.xz` archive can still be selected instead.
- An engine archive older than the newest published release, or one that needs a
  newer macOS or setup tool, is refused before anything is installed.
- `.tar.zst` engine archives, including every published release, need `zstd`
  (`brew install zstd`). The setup page says so and blocks setup when it is missing.
- A failed setup no longer deletes a Wine prefix or settings file left in
  `~/Library/Application Support/<app name>/` by an earlier wrapper of the same name.
- A failed ModOrganizer USVFS update after the wrapper is built is reported as a warning
  instead of failing an otherwise working setup.
- The setup checklist follows the order the steps actually run in, the progress bar
  follows the steps, and the last lines of setup output are no longer lost when setup
  fails.

### Removals

- Removed the bundled GPTK4 D3DMetal payload, the bundled DirectX redistributable DLLs,
  and `recommended-settings.json`. None of them had a consumer left after the pipeline
  change.
- Removed the launch-flags field. Launch arguments belong to the wrapper and are set in
  its Configurator.
- Removed the D3DMetal backend option from `interactive_setup.py` (backend prompt,
  `--backend`/`--dxmt-only`, launcher branches, D3DMetal settings and the d3d10
  override); wrappers always use DXMT. Removed the setup-time winetricks `verbs`
  runtime mode (`--runtime-mode`), which no DXMT-only engine could reach; the wrapper's
  own `Contents/MacOS/winetricks` launcher is unchanged.

## 0.86 — 2026-08-07

### Main improvements

- Dropped the `stalker-gamma-cli` requirement: any GAMMA installation works as long as it has `ModOrganizer.exe`.
- Reworked the setup flow to make creating a wrapper more direct: choose an app name, locate the GAMMA installation, and use the recommended settings or review the advanced options.
- Added bundled GPTK4 D3DMetal files and made D3DMetal the recommended renderer.
- Updated the recommended Wine environment to Sikarugir Wine 10 and bundled the ModOrganizer `usvfs` files used by the wrapper.
- Added clearer advanced controls for the Wine engine, renderer, display resolution, and drive mapping.
- Added support for launching another Windows executable with optional launch flags.
- Added a Finder shortcut for opening the wrapper configuration app.
- Reduced repeated downloads by reusing cached Sikarugir and Winetricks files when available.
- Improved setup review, progress reporting, completion details, and error guidance.
- Added an optional detailed setup log for troubleshooting.
- Updated the managed Winetricks checksums for the current `vcrun2026` redistributables so repeat wrapper creation can reuse cached payloads.

### Safety and behavior

- Setup now creates new wrappers only and will not inspect, modify, or overwrite an existing app.
- The selected GAMMA installation is checked for `ModOrganizer.exe` before setup begins.
- The standard setup uses Wine's normal `Z:` drive mapping; an optional `G:` mapping remains available for installations that already rely on it.
- Removed the DXMT and DXVK tuning options, HUD toggles, MoltenVK fast math, and the mouse input compatibility toggle; a `Configure` shortcut is created beside the wrapper instead.
- D3DMetal shader fixes, including the reflex reticle fix, are no longer bundled. They are published separately at <https://github.com/elseform/gamma-mods/releases/latest>.

Earlier releases and their notes are available on the GitHub Releases page.
