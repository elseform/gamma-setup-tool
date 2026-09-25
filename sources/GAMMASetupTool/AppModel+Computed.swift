import SwiftUI
import AppKit
import UniformTypeIdentifiers

#if SWIFT_PACKAGE
import GAMMASetupCore
#endif

extension AppModel {
    // MARK: - Configuration

    var configuration: SetupConfiguration {
        SetupConfiguration(
            appName: appName,
            installDirectory: installDirectory,
            customLaunchExecutablePath: customLaunchExecutablePath,
            saveVerboseLog: saveVerboseLog,
            manualModOrganizerPath: manualModOrganizerPath
        )
    }

    var engineURL: URL {
        if let bundled = AppResources.bundle.url(forResource: "gamma-setup-engine", withExtension: nil) {
            return bundled
        }
        if let bundled = Bundle.main.url(forResource: "gamma-setup-engine", withExtension: nil) {
            return bundled
        }
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let builtEngine = cwd.appendingPathComponent("dist/intermediates/gamma-setup-engine")
        if FileManager.default.isExecutableFile(atPath: builtEngine.path) {
            return builtEngine
        }
        return cwd.appendingPathComponent("gamma-setup-engine")
    }

    var outputAppPath: String {
        SetupConfiguration(appName: appName, installDirectory: installDirectory).outputAppPath
    }

    var wrapperNameIsValid: Bool {
        configuration.wrapperNameIsValid && !FileManager.default.fileExists(atPath: outputAppPath)
    }

    var outputAppAlreadyExists: Bool {
        configuration.wrapperNameIsValid && FileManager.default.fileExists(atPath: outputAppPath)
    }

    var wrapperNameValidationMessage: String {
        let trimmed = appName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "Enter an app name."
        }
        if !SetupConfiguration.isValidWrapperName(appName) {
            return "Use a name without / or : characters."
        }
        if FileManager.default.fileExists(atPath: outputAppPath) {
            return "An app with this name already exists."
        }
        return ""
    }

    /// An empty wineEngineArchivePath is valid on its own: the engine then
    /// resolves and downloads the newest published gamma-wine-engine release
    /// (see WineEngineSetup.resolveArchive). A non-empty path is an explicit
    /// local override, still gated the same way a downloaded release is.
    var setupReady: Bool {
        selectedLaunchExecutableFound && wrapperNameIsValid && !zstdMissing
    }

    /// Published releases and most local builds are `.tar.zst`, which neither
    /// setup step can unpack without Homebrew's `zstd`. Only a local `.tar.xz`
    /// works without it.
    var zstdMissing: Bool {
        let archive = wineEngineArchivePath.trimmingCharacters(in: .whitespacesAndNewlines)
        let needsZstd = archive.isEmpty || ZstdLocator.isRequired(forArchiveNamed: archive)
        return needsZstd && ZstdLocator.locate() == nil
    }

    var selectedLaunchExecutablePath: String {
        configuration.selectedLaunchExecutablePath
    }

    var selectedLaunchExecutableLabel: String {
        configuration.selectedLaunchExecutableLabel
    }

    var selectedLaunchExecutableFound: Bool {
        configuration.selectedLaunchExecutableFound
    }

    var createHeaderTitle: String {
        if installFailed {
            return "Wrapper creation failed"
        }
        if isRunning {
            return "Creating wrapper"
        }
        return "Review settings"
    }

    var createHeaderSubtitle: String {
        if installFailed {
            return "Check the logs for the failed setup step."
        }
        if isRunning {
            return statusText.isEmpty ? "Preparing wrapper creation" : statusText
        }
        return "Review your choices, then create the wrapper."
    }

    var setupSummaryItems: [SetupSummaryItem] {
        if let frozenSetupSummaryItems {
            return frozenSetupSummaryItems
        }
        return makeSetupSummaryItems()
    }

    func makeSetupSummaryItems() -> [SetupSummaryItem] {
        var rows: [SetupSummaryItem] = []

        func add(_ label: String, _ planned: String) {
            rows.append(SetupSummaryItem(label: label, planned: planned))
        }

        add("Application", outputAppPath)
        add("Executable", configuration.selectedLaunchExecutablePath)
        add("Engine archive", wineEngineArchivePath.isEmpty ? "Automatic (latest release)" : wineEngineArchivePath)
        add("Graphics backend", "DXMT")
        add("Game root (G:)", configuration.optionalGDriveRoot)
        add(SetupOptionCopy.usvfsBinaries, "ModOrganizer folder only; outdated files backed up, then replaced")
        if saveVerboseLog {
            add(SetupOptionCopy.logTitle, SetupOptionCopy.logAction)
        }

        return rows
    }

    var plannedWineDriveMapping: String {
        configuration.plannedWineDriveMapping
    }
}
