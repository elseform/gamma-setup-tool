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

    /// "<name>", as Finder shows the created app (without ".app").
    var outputAppName: String {
        URL(fileURLWithPath: outputAppPath).deletingPathExtension().lastPathComponent
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
    /// (see WineEngineSetup.resolveArchive). A non-empty path is a local
    /// archive, used as is.
    var setupReady: Bool {
        selectedLaunchExecutableFound && wrapperNameIsValid
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
        installFailed ? "Something went wrong" : "Installation in progress"
    }

    var createHeaderSubtitle: String {
        if installFailed {
            return "Setup stopped before the app was finished."
        }
        return "This takes a few minutes."
    }

    var plannedWineDriveMapping: String {
        configuration.plannedWineDriveMapping
    }
}
