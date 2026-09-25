import SwiftUI
import AppKit
import UniformTypeIdentifiers

#if SWIFT_PACKAGE
import GAMMASetupCore
#endif

struct SetupSummaryItem: Identifiable {
    var id: String { label }
    let label: String
    let planned: String
}

@MainActor
final class AppModel: ObservableObject {
    @Published var appName = "stalker-gamma"
    @Published var installDirectory = SetupConfiguration.defaultInstallDirectory
    @Published var customLaunchExecutablePath: String?
    @Published var saveVerboseLog = true
    @Published var manualModOrganizerPath = ""
    @Published var logText = ""
    @Published var savedLogPath = ""
    @Published var statusText = "Ready"
    @Published var isRunning = false
    @Published var showOutput = false
    @Published var progress = 0.0
    @Published var frozenSetupSummaryItems: [SetupSummaryItem]?
    @Published var installStageIndex = -1
    @Published var installStageCompletedIndex = -1
    @Published var installFailed = false
    var pendingEngineOutput = Data()
    var pendingLogText = ""
    var logFlushScheduled = false

    @Published var wineEngineArchivePath = ""
    /// Optional directory of already-downloaded Microsoft installers; empty
    /// means the setup run uses its cache, then the network.
    @Published var redistInstallerDirectory = ""

    init() {
        loadSettings()
    }
}
