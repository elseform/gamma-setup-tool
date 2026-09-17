# GAMMA Setup Tool

Native macOS tool for creating a Wine `.app` wrapper, built on [gamma-wine-engine](https://github.com/elseform/gamma-wine-engine), around an existing S.T.A.L.K.E.R. G.A.M.M.A. installation.

GAMMA Setup Tool does not install G.A.M.M.A. itself. It requires an existing G.A.M.M.A. installation.

See [CHANGELOG.md](CHANGELOG.md) for release highlights and notable behavior changes.

## Description

Choose an app name, select the GAMMA folder that contains `ModOrganizer.exe`, then pick a gamma-wine-engine archive and review the wrapper settings. The tool then creates the `.app` wrapper in `~/Applications`.

The engine is DXMT-only — there's no Wine engine, renderer, or display-behavior choice. Drive mapping always mounts the game root as `G:` and the host root as `Z:`. Runtime dependencies always install from the bundled redistributables (no winetricks verb selection).

The tool checks that `ModOrganizer.exe` exists, but it does not validate the contents or health of the GAMMA installation.

The setup flow creates a new wrapper and will not overwrite an existing app. If you encounter a problem, use the Discord support link in the app and attach the detailed setup log when available.

## What It Does

The app uses the selected `ModOrganizer.exe` path to create a native macOS app wrapper that launches G.A.M.M.A. through ModOrganizer.

The guided flow handles:

- GAMMA and ModOrganizer folder selection.
- gamma-wine-engine archive selection and drive-mapping review.
- Bundled runtime dependencies and automatic USVFS updates.

## How to Use

Open the [latest GitHub release](https://github.com/elseform/gamma-setup-tool/releases/latest) and download the GAMMA Setup Tool archive from its **Assets** section.

Extract it, then run:

```text
GAMMA Setup Tool.app
```

Because the release is not notarized, macOS may require you to approve the app in System Settings.

## Developer Notes

### Build

Build the app:

```text
swift build
```

Building from source requires Apple's Command Line Tools or Xcode.

SwiftPM writes build products under:

```text
.build/
```

For UI iteration, build and immediately run the app target:

```text
swift run GAMMASetupTool
```

Build artifacts, Swift module cache, and intermediates are kept under `.build/` so repeat builds are faster. To remove them:

```text
swift package clean
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
- `sources/GAMMASetupCore/`: shared setup engine models, path helpers, CLI preflight support, and installation services.
- `sources/GAMMASetupEngine/`: the setup backend launched by the GUI.

The Swift package builds both the GUI and the `gamma-setup-engine` backend.

### Logs

Setup logs are optional. Enable `Save detailed setup log` in the wrapper settings to create a log in `~/`:

```text
gamma-setup-tool.YYYYMMDD-HHMMSS.log
```

Dry-run logs use:

```text
gamma-setup-tool.dry-run.YYYYMMDD-HHMMSS.log
```

Logs are ignored by git. Private engine behavior, cache layout, and preset details are maintained in the `gamma-project` command-center documentation.
