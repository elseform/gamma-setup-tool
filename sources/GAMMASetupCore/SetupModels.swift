import Foundation

/// Declared in the order a setup run reaches them: `dependencies` is the
/// Swift side's archive resolution, the rest come from interactive_setup.py.
/// The GUI's stage rows follow this order.
public enum SetupEngineStage: String, Codable, CaseIterable {
    case dependencies
    case engine
    case prefix
    case driveMapping
    case winetricks
    case wrapper
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

/// Request shape for the gamma-wine-engine-backed pipeline
/// (interactive_setup.py) — the only pipeline gamma-setup-tool drives.
/// USVFS stays (MO2 still needs virtualization under this engine). The
/// graphics backend is always DXMT and the runtime DLLs always come from the
/// engine's redist manifest, so neither has a field. Keys an older request
/// file still carries (`backend`, `runtimeMode`, `dxmtOnly`,
/// `releaseArchiveURL`) are ignored when decoding.
public struct WineEngineSetupRequest: Codable {
    /// A local engine archive; nil or empty resolves and downloads the newest
    /// published gamma-wine-engine release.
    public var archivePath: String?
    public var appName: String
    public var appParent: String
    public var gammaRoot: String
    public var mo2Path: String
    public var exeRelPath: String?
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
        appName: String = "GAMMA",
        appParent: String = NSString(string: "~/Applications").expandingTildeInPath,
        gammaRoot: String = "",
        mo2Path: String = "",
        exeRelPath: String? = nil,
        yes: Bool = true,
        skipFinderAlias: Bool = false,
        forceExe: Bool = false,
        updateUSVFS: Bool = true,
        usvfsSource: String = SetupDefaults.defaultUSVFSSource,
        redistInstallerDirectory: String? = nil,
        logFile: String? = nil
    ) {
        self.archivePath = archivePath
        self.appName = appName
        self.appParent = appParent
        self.gammaRoot = gammaRoot
        self.mo2Path = mo2Path
        self.exeRelPath = exeRelPath
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
