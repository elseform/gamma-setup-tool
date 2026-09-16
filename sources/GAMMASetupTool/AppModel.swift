import SwiftUI
import AppKit
import UniformTypeIdentifiers

#if SWIFT_PACKAGE
import GAMMASetupCore
#endif

struct ToolResult {
    let output: String
    let exitCode: Int32
}

struct SetupSummaryItem: Identifiable {
    var id: String { label }
    let label: String
    let planned: String
}

final class OutputBuffer: @unchecked Sendable {
    private var data = Data()
    private let lock = NSLock()

    func append(_ newData: Data) {
        lock.lock()
        data.append(newData)
        lock.unlock()
    }

    func stringValue() -> String {
        lock.lock()
        defer { lock.unlock() }
        let current = data
        return String(data: current, encoding: .utf8) ?? ""
    }
}

@MainActor
final class AppModel: ObservableObject {
    @Published var appName = "stalker-gamma"
    @Published var installDirectory = SetupConfiguration.defaultInstallDirectory
    @Published var programBatch = "/mo2.bat"
    @Published var launchBatches: [LaunchBatch] = []
    @Published var launchArguments = ""
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
    var receivedInstallStageEvents = false
    var pendingEngineEventText = ""

    // gamma-wine-engine-backed pipeline (create-wine-engine) — the only
    // pipeline this app drives. appName/installDirectory/saveVerboseLog and
    // the MO2 detection above (manualModOrganizerPath/selectedLaunchExecutablePath)
    // are reused as-is. Backend is hardcoded to "dxmt" and runtime-mode to
    // "redist" in wineEngineRequest() (AppModel+Engine.swift) — no fields
    // here for either, there's no choice to expose.
    @Published var wineEngineArchivePath = ""

    init() {
        loadSettings()
    }
}
