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
            programBatch: programBatch,
            launchBatches: launchBatches,
            launchArguments: launchArguments,
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

    var wrapperStageTitle: String {
        "Create wrapper"
    }

    var environmentOK: Bool {
        configuration.environmentOK
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

    var createFlowEnvironmentOK: Bool {
        configuration.createFlowEnvironmentOK
    }

    var setupReady: Bool {
        configuration.createFlowEnvironmentOK
            && driveMappingReady
            && wrapperNameIsValid
            && selectedLaunchExecutableFound
            && configuration.launchArgumentsAreValid
            && !wineEngineArchivePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var selectedModOrganizerExecutableFound: Bool {
        configuration.selectedModOrganizerExecutableFound
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

    var launchConfigurationIsValid: Bool {
        selectedLaunchExecutableFound && configuration.launchArgumentsAreValid
    }

    var launchSelectionMessage: String {
        if !configuration.launchArgumentsAreValid {
            return "Launch flags must be a single line."
        }
        if !selectedLaunchExecutableFound {
            return "Selected executable was not found."
        }
        return "The executable and flags are written to the wrapper's launch batch."
    }

    var requiredToolsOK: Bool {
        configuration.requiredToolsOK
    }

    var primaryButtonTitle: String {
        "Create wrapper"
    }

    var createHeaderTitle: String {
        if installFailed {
            return "Installation failed"
        }
        if isRunning {
            return "Installation in progress"
        }
        return "Review settings"
    }

    var createHeaderSubtitle: String {
        if installFailed {
            return "Check the logs for the failed setup step."
        }
        if isRunning {
            return statusText.isEmpty ? "Applying changes" : statusText
        }
        return "Confirm options"
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

        add("App", outputAppPath)
        add("Executable", configuration.selectedLaunchExecutablePath)
        add("Engine archive", wineEngineArchivePath.isEmpty ? "Not selected" : wineEngineArchivePath)
        add("Backend", "DXMT")
        add(SetupOptionCopy.usvfsBinaries, "Checked automatically, updated if outdated")
        if saveVerboseLog {
            add(SetupOptionCopy.logTitle, SetupOptionCopy.logAction)
        }

        return rows
    }

    var plannedWineDriveMapping: String {
        configuration.plannedWineDriveMapping
    }

    var driveMappingReady: Bool {
        configuration.driveMappingReady
    }

    var environmentMessage: String {
        if !selectedModOrganizerExecutableFound {
            return "Select the ModOrganizer folder."
        }
        return ""
    }

}
