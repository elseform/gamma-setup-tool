# GAMMA Setup Tool

Native macOS tool for creating a Wine `.app` wrapper, built on [gamma-wine-engine](https://github.com/elseform/gamma-wine-engine), around an existing S.T.A.L.K.E.R. G.A.M.M.A. installation.

GAMMA Setup Tool does not install G.A.M.M.A. itself. It requires an existing G.A.M.M.A. installation and an Apple Silicon Mac running macOS 15 or newer.

See [CHANGELOG.md](CHANGELOG.md) for release highlights and notable behavior changes.

## Description

Choose an app name, select the GAMMA folder that contains `ModOrganizer.exe`, then pick a gamma-wine-engine archive and review the wrapper settings. The tool then creates the `.app` wrapper in `~/Applications`.

The engine is DXMT-only — there's no Wine engine, renderer, or display-behavior choice. Drive mapping always mounts the game root as `G:` and the host root as `Z:`. The Microsoft Visual C++ and DirectX runtime files the game needs are downloaded from Microsoft's own installers during setup (pinned by checksum and cached for later runs); no winetricks verb selection.

Game and graphics settings, including launch arguments, are not part of setup. Each wrapper has a Configurator (the `<app name> Configurator` alias next to the app) that edits them.

The tool checks that `ModOrganizer.exe` exists, but it does not validate the contents or health of the GAMMA installation.

The setup flow creates a new wrapper and will not overwrite an existing app. If you encounter a problem, use the Discord support link in the app and attach the detailed setup log when available.

## What It Does

The app uses the selected `ModOrganizer.exe` path to create a native macOS app wrapper that launches G.A.M.M.A. through ModOrganizer.

The guided flow handles:

- GAMMA and ModOrganizer folder selection.
- gamma-wine-engine archive selection and drive-mapping review.
- Runtime dependencies from Microsoft's installers and automatic USVFS updates.

## How to Use

Open the [latest GitHub release](https://github.com/elseform/gamma-setup-tool/releases/latest) and download the GAMMA Setup Tool archive from its **Assets** section.

Extract it, then run:

```text
GAMMA Setup Tool.app
```

Because the release is not notarized, macOS may require you to approve the app in System Settings.

## Developer Notes

### Build

Build and install the app (to `dist/` and `~/Applications/GAMMA Setup Tool.app`):

```text
./build.sh
```

`./build.sh run` builds and launches it; `./build.sh clean` removes build output. The script compiles with `swiftc` directly (no Xcode project), for Apple Silicon and macOS 15. Building requires Apple's Command Line Tools or Xcode.

Run the tests (Swift unit tests, the `gamma-setup-engine` CLI tests, and a build smoke test):

```text
./test.sh
```

### Source Layout

Swift GUI sources live in:

```text
sources/GAMMASetupTool/
```

The app is split into:

- `AppModel.swift` and `AppModel+*.swift`: setup state, derived state, user actions, request construction, and process event handling.
- `Components.swift`: reusable SwiftUI rows, tips, icons, and wizard step metadata.
- `ContentView.swift` and `ContentView+*.swift`: wizard layout, navigation, and screens.
- `GAMMASetupToolApp.swift`: app entry point.
- `sources/GAMMASetupCore/`: shared request and event models, the wrapper-creation pipeline that runs `interactive_setup.py`, and the USVFS and redistributable-installer services.
- `sources/GAMMASetupTool/Resources/wine-engine/interactive_setup.py`: builds the wrapper from an engine archive.
- `sources/GAMMASetupEngine/`: the setup backend launched by the GUI.

The Swift package builds both the GUI and the `gamma-setup-engine` backend.

### Logs

Setup logs are optional. With `Save setup log` enabled, every setup event is written to:

```text
~/Library/Logs/gamma-setup-tool/<app name>-YYYYMMDD-HHMMSS.log
```

Private engine behavior, cache layout, and preset details are maintained in the `gamma-project` command-center documentation.
