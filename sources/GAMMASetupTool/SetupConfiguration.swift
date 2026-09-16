import Foundation

#if SWIFT_PACKAGE
import GAMMASetupCore
#endif

struct SetupConfiguration {
    static let defaultInstallDirectory = AppSettingsStore.defaultInstallDirectory
    var appName = "stalker-gamma"
    var installDirectory = SetupConfiguration.defaultInstallDirectory
    var programBatch = "/mo2.bat"
    var launchBatches: [LaunchBatch] = []
    var launchArguments = ""
    var saveVerboseLog = true
    var manualModOrganizerPath = ""

    var outputAppPath: String {
        let cleanName = appName.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseName = cleanName.hasSuffix(".app") ? String(cleanName.dropLast(4)) : cleanName
        let name = "\(baseName).app"
        return URL(fileURLWithPath: installDirectory).appendingPathComponent(name).path
    }

    var wrapperNameIsValid: Bool {
        Self.isValidWrapperName(appName)
    }

    static func isValidWrapperName(_ name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        guard trimmed != "." && trimmed != ".." else { return false }
        return trimmed.rangeOfCharacter(from: CharacterSet(charactersIn: "/:")) == nil
    }

    var selectedLaunchExecutablePath: String {
        if programBatch == "/mo2.bat" {
            let manualPath = manualModOrganizerPath.trimmingCharacters(in: .whitespacesAndNewlines)
            return manualPath.isEmpty ? "ModOrganizer.exe" : manualPath
        }
        return launchBatches.first { $0.batchPath == programBatch }?.executablePath ?? programBatch
    }

    var selectedLaunchExecutableLabel: String {
        if programBatch == "/mo2.bat" { return "ModOrganizer" }
        return URL(fileURLWithPath: selectedLaunchExecutablePath).lastPathComponent
    }

    var selectedLaunchExecutableFound: Bool {
        if programBatch == "/mo2.bat" {
            // manualModOrganizerPath is the only source now (no more
            // preflight-detected fallback — that field was always nil in
            // practice, see AppModel+Engine.swift's wineEngineRequest()
            // comment for the full story).
            return AppSettingsStore.isValidModOrganizerExecutable(selectedLaunchExecutablePath)
        }
        let path = selectedLaunchExecutablePath.trimmingCharacters(in: .whitespacesAndNewlines)
        return URL(fileURLWithPath: path).pathExtension.caseInsensitiveCompare("exe") == .orderedSame
            && FileManager.default.fileExists(atPath: path)
    }

    var launchArgumentsAreValid: Bool {
        !SetupLaunchBatchTools.containsLineBreak(launchArguments)
    }

    var environmentOK: Bool {
        selectedModOrganizerExecutableFound
    }

    var requiredToolsOK: Bool {
        true
    }

    // Every other gate in the app (ContentView+Setup.swift,
    // ContentView+Navigation.swift, ContentView+Flow.swift,
    // AppModel+Computed.swift) reads this by name expecting "is a launch
    // target currently properly selected" — MO2 by default, or a custom
    // exe override.
    var selectedModOrganizerExecutableFound: Bool {
        selectedLaunchExecutableFound
    }

    var createFlowEnvironmentOK: Bool {
        selectedModOrganizerExecutableFound
    }

    // gamma-wine-engine's interactive_setup.py always mounts both Z:
    // (host root) and G: (the resolved flat-install root) unconditionally
    // — there is no drive-mapping mode choice for this pipeline.
    var plannedWineDriveMapping: String {
        optionalGDriveRoot.isEmpty ? "Z: -> /" : "G: -> \(optionalGDriveRoot)"
    }

    var optionalGDriveRoot: String {
        guard selectedLaunchExecutableFound else { return "" }
        return URL(fileURLWithPath: selectedLaunchExecutablePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .standardizedFileURL.path
    }

    var driveMappingReady: Bool {
        !optionalGDriveRoot.isEmpty
    }
}
