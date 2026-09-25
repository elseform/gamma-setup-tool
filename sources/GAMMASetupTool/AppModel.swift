import Foundation
import Observation

#if SWIFT_PACKAGE
import GAMMASetupCore
#endif

struct SetupSummaryItem: Identifiable {
    var id: String { label }
    let label: String
    let planned: String
}

@MainActor
@Observable
final class AppModel {
    var appName = "stalker-gamma"
    var installDirectory = SetupConfiguration.defaultInstallDirectory
    var customLaunchExecutablePath: String?
    var saveVerboseLog = true
    var manualModOrganizerPath = ""
    var logText = ""
    var savedLogPath = ""
    var statusText = "Ready"
    var isRunning = false
    var showOutput = false
    var progress = 0.0
    var frozenSetupSummaryItems: [SetupSummaryItem]?
    var installStageIndex = -1
    var installStageCompletedIndex = -1
    var installFailed = false
    // Engine-output plumbing, not state any view reads.
    @ObservationIgnored var pendingEngineOutput = Data()
    @ObservationIgnored var pendingLogText = ""
    @ObservationIgnored var logFlushScheduled = false

    var wineEngineArchivePath = ""
    /// Optional directory of already-downloaded Microsoft installers; empty
    /// means the setup run uses its cache, then the network.
    var redistInstallerDirectory = ""

    init() {
        loadSettings()
    }
}
