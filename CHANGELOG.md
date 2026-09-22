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

### Removals

- Removed the bundled GPTK4 D3DMetal payload, the bundled DirectX redistributable DLLs,
  and `recommended-settings.json`. None of them had a consumer left after the pipeline
  change.
- Removed the launch-flags field. Launch arguments belong to the wrapper and are set in
  its Configurator.

### Known limitation

- The engine archive is selected from a local file. Downloading it from a published
  `gamma-wine-engine` release is not wired up yet, because no such release exists.

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
