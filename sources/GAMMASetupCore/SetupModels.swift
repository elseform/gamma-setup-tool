import Foundation

public enum SetupEngineStage: String, Codable, CaseIterable {
    case dependencies
    case wrapper
    case engine
    case prefix
    case driveMapping
    case winetricks
    case finalize
}

public enum SetupEngineEventType: String, Codable {
    case log
    case stageStarted
    case stageFinished
    case stageFailed
    case artifact
    case completed
}

public struct SetupEngineEvent: Codable {
    public var type: SetupEngineEventType
    public var stage: SetupEngineStage?
    public var message: String?
    public var severity: String?
    public var path: String?
    public var success: Bool?

    public init(
        type: SetupEngineEventType,
        stage: SetupEngineStage? = nil,
        message: String? = nil,
        severity: String? = nil,
        path: String? = nil,
        success: Bool? = nil
    ) {
        self.type = type
        self.stage = stage
        self.message = message
        self.severity = severity
        self.path = path
        self.success = success
    }
}

/// A custom launch target (an alternative to launching through MO2) —
/// still used by the wizard's "select any Windows executable" flow.
public struct LaunchBatch: Codable, Identifiable, Equatable {
    public var id: String { batchPath }
    public var batchPath: String
    public var executablePath: String
    public var workingDirectory: String
    public var usesModOrganizerEnvironment: Bool?

    public init(
        batchPath: String,
        executablePath: String,
        workingDirectory: String = "",
        usesModOrganizerEnvironment: Bool = false
    ) {
        self.batchPath = batchPath
        self.executablePath = executablePath
        self.workingDirectory = workingDirectory
        self.usesModOrganizerEnvironment = usesModOrganizerEnvironment
    }
}

/// Request shape for the gamma-wine-engine-backed pipeline
/// (interactive_setup.py) — the only pipeline gamma-setup-tool drives.
/// USVFS stays (MO2 still needs virtualization under this engine); there
/// is no GPTK4 field because the engine's own archive already carries
/// whichever D3DMetal/DXMT backend support it needs.
public struct WineEngineSetupRequest: Codable {
    public var archivePath: String?
    /// Superseded by automatic release resolution (EngineReleaseResolver):
    /// with archivePath empty, WineEngineSetup now resolves and downloads the
    /// newest published gamma-wine-engine release on its own. Kept, and still
    /// decoded, only so an old request file with this field set doesn't fail
    /// to decode; nothing sets or reads it any more.
    public var releaseArchiveURL: String?
    public var appName: String
    public var appParent: String
    public var gammaRoot: String
    public var mo2Path: String
    public var exeRelPath: String?
    public var backend: String
    public var runtimeMode: String
    public var dxmtOnly: Bool
    public var yes: Bool
    public var skipFinderAlias: Bool
    public var forceExe: Bool
    public var updateUSVFS: Bool
    public var usvfsSource: String
    /// Directory holding already-downloaded Microsoft installers. nil or empty
    /// means cache-then-network; a supplied one wins over both. Optional, like
    /// every other added-later field here: a synthesised `init(from:)` ignores
    /// property defaults, so a non-optional would reject every request written
    /// before this field existed.
    public var redistInstallerDirectory: String?
    /// When set, every setup event is also written to this file.
    public var logFile: String?

    public init(
        archivePath: String? = nil,
        releaseArchiveURL: String? = nil,
        appName: String = "GAMMA",
        appParent: String = NSString(string: "~/Applications").expandingTildeInPath,
        gammaRoot: String = "",
        mo2Path: String = "",
        exeRelPath: String? = nil,
        backend: String = "dxmt",
        runtimeMode: String = "redist",
        dxmtOnly: Bool = false,
        yes: Bool = true,
        skipFinderAlias: Bool = false,
        forceExe: Bool = false,
        updateUSVFS: Bool = true,
        usvfsSource: String = SetupDefaults.defaultUSVFSSource,
        redistInstallerDirectory: String? = nil,
        logFile: String? = nil
    ) {
        self.archivePath = archivePath
        self.releaseArchiveURL = releaseArchiveURL
        self.appName = appName
        self.appParent = appParent
        self.gammaRoot = gammaRoot
        self.mo2Path = mo2Path
        self.exeRelPath = exeRelPath
        self.backend = backend
        self.runtimeMode = runtimeMode
        self.dxmtOnly = dxmtOnly
        self.yes = yes
        self.skipFinderAlias = skipFinderAlias
        self.forceExe = forceExe
        self.updateUSVFS = updateUSVFS
        self.usvfsSource = usvfsSource
        self.redistInstallerDirectory = redistInstallerDirectory
        self.logFile = logFile
    }
}

public enum SetupDefaults {
    public static let defaultUSVFSSource = ""

    /// This build's own version, used both as the UI footer's fallback and as
    /// what an engine's `minimumSetupToolVersion` is checked against. Kept in
    /// step with `build.sh`'s `APP_VERSION` by a test (`build.sh` has no way to
    /// read a Swift constant, so the check runs the other direction).
    public static let toolVersion = "0.90"

    /// Below this, an engine archive is refused outright even with no
    /// network and no cached release info — the last-resort floor in
    /// EngineFloor. A full version, not just a build counter: ordering
    /// compares CrossOver/Wine/Gamma generation before the build counter, so
    /// a floor built from an all-zero placeholder generation would be
    /// outranked by any real archive regardless of its build number, making
    /// it no floor at all. Bumped only when an older build in this same
    /// generation becomes known broken, never merely because a newer one was
    /// published.
    public static let minimumSupportedEngine = EngineBuildVersion(
        crossover: [26, 3, 0], wineMajor: 11, gamma: 87, build: 1
    )
}
