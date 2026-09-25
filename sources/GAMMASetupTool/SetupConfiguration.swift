import Foundation

struct SetupConfiguration {
    static let defaultInstallDirectory = AppSettingsStore.defaultInstallDirectory
    var appName = "stalker-gamma"
    var installDirectory = SetupConfiguration.defaultInstallDirectory
    /// A Windows executable chosen instead of ModOrganizer.exe; nil launches
    /// through MO2.
    var customLaunchExecutablePath: String?
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

    var usesCustomLaunchExecutable: Bool {
        customLaunchExecutablePath != nil
    }

    var selectedLaunchExecutablePath: String {
        if let customLaunchExecutablePath {
            return customLaunchExecutablePath
        }
        let manualPath = manualModOrganizerPath.trimmingCharacters(in: .whitespacesAndNewlines)
        return manualPath.isEmpty ? "ModOrganizer.exe" : manualPath
    }

    var selectedLaunchExecutableLabel: String {
        usesCustomLaunchExecutable
            ? URL(fileURLWithPath: selectedLaunchExecutablePath).lastPathComponent
            : "ModOrganizer"
    }

    /// Whether a launch target is properly selected: MO2 by default, or a
    /// custom executable that exists. Every readiness gate in the app reads
    /// this.
    var selectedLaunchExecutableFound: Bool {
        if !usesCustomLaunchExecutable {
            return AppSettingsStore.isValidModOrganizerExecutable(selectedLaunchExecutablePath)
        }
        let path = selectedLaunchExecutablePath.trimmingCharacters(in: .whitespacesAndNewlines)
        return URL(fileURLWithPath: path).pathExtension.caseInsensitiveCompare("exe") == .orderedSame
            && FileManager.default.fileExists(atPath: path)
    }

    // gamma-wine-engine's interactive_setup.py always mounts both Z:
    // (host root) and G: (the resolved flat-install root) unconditionally
    // — there is no drive-mapping mode choice for this pipeline.
    var plannedWineDriveMapping: String {
        optionalGDriveRoot.isEmpty ? "Z: -> /" : "G: -> \(optionalGDriveRoot)"
    }

    /// The G: root: two components above the launch target (MO2's own
    /// folder, then its parent), empty until a target is found.
    var optionalGDriveRoot: String {
        guard selectedLaunchExecutableFound else { return "" }
        return URL(fileURLWithPath: selectedLaunchExecutablePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .standardizedFileURL.path
    }
}
