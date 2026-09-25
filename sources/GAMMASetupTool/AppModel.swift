import Foundation
import Observation

#if SWIFT_PACKAGE
import GAMMASetupCore
#endif

@MainActor
@Observable
final class AppModel {
    var appName = ""
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
    /// What setup will do to ModOrganizer's USVFS files, for the selected
    /// launch target; nil until checked or when the bundled copies are
    /// unavailable. `usvfsPlanForRun` freezes it when a run starts, since
    /// a successful run turns every `.updated` into `.upToDate`.
    var usvfsPlan: USVFSUpdater.Outcome?
    var usvfsPlanForRun: USVFSUpdater.Outcome?
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
        if selectedLaunchExecutableFound {
            suggestAppName()
        }
    }
}
