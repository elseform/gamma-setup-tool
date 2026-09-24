import Foundation

/// Whether an engine archive may be installed, checked immediately after it
/// is resolved and before `WineEngineSetup.create()` runs anything
/// destructive.
public enum EngineArchiveDecision: Equatable {
    case accept(EngineBuildVersion)
    case refuse(EngineArchiveRefusal)
}

public enum EngineArchiveRefusal: Equatable, CustomStringConvertible {
    /// The build number is below the current floor. No override exists —
    /// bisecting an old build is done with interactive_setup.py directly.
    case olderThanFloor(archive: EngineBuildVersion, floor: EngineBuildVersion, floorSource: EngineFloor.Source)
    case macOSTooOld(required: String, current: String)
    case setupToolTooOld(required: String, current: String)
    case unreadableManifest(String)
    case unknownBuildNumber(String)

    public var description: String {
        switch self {
        case .olderThanFloor(let archive, let floor, let source):
            let sourceText: String
            switch source {
            case .liveRelease: sourceText = "the latest published release"
            case .cachedRelease: sourceText = "the last release this machine saw"
            case .compiledMinimum: sourceText = "the oldest build this version of the setup tool still supports"
            }
            return "this engine (\(archive)) is older than \(floor), \(sourceText). Choose a newer engine archive."
        case .macOSTooOld(let required, let current):
            return "this engine needs macOS \(required) or newer; this Mac runs \(current)."
        case .setupToolTooOld(let required, let current):
            return "this engine needs GAMMA Setup Tool \(required) or newer; this is \(current). Update the setup tool."
        case .unreadableManifest(let reason):
            return "could not read this engine's manifest: \(reason)"
        case .unknownBuildNumber(let reason):
            return "could not tell which build this engine is (\(reason)); refusing rather than assuming it is current."
        }
    }
}

public enum EngineArchiveGate {
    /// `floor` is `nil` when no floor could be established at all (no
    /// network and no cache and a broken compiled default) — callers should
    /// treat that as its own hard error before reaching this gate; passing a
    /// concrete floor is what every real caller does.
    public static func evaluate(
        manifest: EngineManifest,
        archiveName: String?,
        floor: EngineBuildVersion,
        floorSource: EngineFloor.Source,
        currentOperatingSystem: DottedVersion = .currentOperatingSystem,
        currentToolVersion: String = SetupDefaults.toolVersion
    ) -> EngineArchiveDecision {
        let version: EngineBuildVersion
        do {
            version = try EngineVersionParser.version(manifest: manifest, name: archiveName)
        } catch let error as EngineVersionParseError {
            switch error {
            case .unreadableLabel(let raw):
                return .refuse(.unreadableManifest(raw))
            case .unknownBuildNumber(let raw):
                return .refuse(.unknownBuildNumber(raw))
            }
        } catch {
            return .refuse(.unreadableManifest(error.localizedDescription))
        }

        // "older", not "not newer": an equal or newer local build is accepted.
        if version < floor {
            return .refuse(.olderThanFloor(archive: version, floor: floor, floorSource: floorSource))
        }

        if let requiredMacOSRaw = manifest.minimumMacOS, let requiredMacOS = DottedVersion(requiredMacOSRaw),
           currentOperatingSystem < requiredMacOS {
            return .refuse(.macOSTooOld(required: requiredMacOSRaw, current: currentOperatingSystem.description))
        }

        if let requiredToolRaw = manifest.minimumSetupToolVersion, let requiredTool = DottedVersion(requiredToolRaw),
           let currentTool = DottedVersion(currentToolVersion), currentTool < requiredTool {
            return .refuse(.setupToolTooOld(required: requiredToolRaw, current: currentToolVersion))
        }

        return .accept(version)
    }
}
