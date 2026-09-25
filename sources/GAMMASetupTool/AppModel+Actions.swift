import SwiftUI
import AppKit
import UniformTypeIdentifiers

#if SWIFT_PACKAGE
import GAMMASetupCore
#endif

extension AppModel {
    // MARK: - Saved Settings

    private var settingsURL: URL? {
        AppSettingsStore.defaultSettingsURL()
    }

    func loadSettings() {
        AppSettingsStore.ensureSettingsFileExists(at: settingsURL)
        let settings = AppSettingsStore.loadSettings(from: settingsURL)
        if let gammaPath = settings.gammaPath?.trimmingCharacters(in: .whitespacesAndNewlines), !gammaPath.isEmpty {
            manualModOrganizerPath = URL(fileURLWithPath: gammaPath).appendingPathComponent("ModOrganizer.exe").path
        }
        if wineEngineArchivePath.isEmpty, let detected = Self.devArchiveFromEnvironment() {
            wineEngineArchivePath = detected
        }
    }

    /// Local-build prefill for development only, opted into by setting
    /// GAMMA_ENGINE_ARTIFACTS_DIR — never a path baked into the app. With the
    /// field left empty (the default for every user), the engine resolves and
    /// downloads the newest published release itself; see
    /// WineEngineSetup.resolveArchive.
    static func devArchiveFromEnvironment() -> String? {
        guard let dir = ProcessInfo.processInfo.environment["GAMMA_ENGINE_ARTIFACTS_DIR"], !dir.isEmpty else {
            return nil
        }
        let artifactsDir = URL(fileURLWithPath: (dir as NSString).expandingTildeInPath)
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: artifactsDir,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }

        let candidates = entries.filter {
            $0.lastPathComponent.hasSuffix(".tar.zst") || $0.lastPathComponent.hasSuffix(".tar.xz")
        }

        return candidates.max { lhs, rhs in
            let lhsDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            let rhsDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            return lhsDate < rhsDate
        }?.path
    }

    // MARK: - Selection

    /// No `.tar.zst`/`.tar.xz` UTType exists to filter on, so this is an
    /// unrestricted file picker (mirrors interactive_setup.py's own
    /// unrestricted archive-path prompt).
    func chooseWineEngineArchive() {
        let panel = NSOpenPanel()
        panel.title = "Choose engine archive"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.canCreateDirectories = false
        panel.allowsMultipleSelection = false
        if !wineEngineArchivePath.isEmpty {
            panel.directoryURL = URL(fileURLWithPath: wineEngineArchivePath).deletingLastPathComponent()
        }
        if panel.runModal() == .OK, let url = panel.url {
            wineEngineArchivePath = url.path
        }
    }

    /// The redistributables themselves are never picked by hand — this only
    /// points the fetcher at installers the user already downloaded, so it
    /// can skip the network.
    func chooseRedistInstallerDirectory() {
        let panel = NSOpenPanel()
        panel.title = "Choose downloaded installers folder"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = false
        panel.allowsMultipleSelection = false
        if !redistInstallerDirectory.isEmpty {
            panel.directoryURL = URL(fileURLWithPath: redistInstallerDirectory)
        }
        if panel.runModal() == .OK, let url = panel.url {
            redistInstallerDirectory = url.path
        }
    }

    func chooseLaunchExecutable() {
        let panel = NSOpenPanel()
        panel.title = "Choose Windows executable"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.canCreateDirectories = false
        panel.allowsMultipleSelection = false
        if let exeType = UTType(filenameExtension: "exe") {
            panel.allowedContentTypes = [exeType]
        }
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let detectedModOrganizerPath = manualModOrganizerPath.trimmingCharacters(in: .whitespacesAndNewlines)
        if !detectedModOrganizerPath.isEmpty,
           URL(fileURLWithPath: detectedModOrganizerPath).standardizedFileURL == url.standardizedFileURL {
            customLaunchExecutablePath = nil
        } else {
            customLaunchExecutablePath = url.path
        }
    }

    func createWineEngine() async -> Bool {
        isRunning = true
        frozenSetupSummaryItems = setupSummaryItems
        installStageIndex = 0
        installStageCompletedIndex = -1
        installFailed = false
        progress = 0
        logText = ""
        pendingLogText = ""
        savedLogPath = ""
        statusText = "Creating"
        pendingEngineOutput = Data()
        let succeeded: Bool
        do {
            let exitCode = try await runEngine(command: "create-wine-engine", request: wineEngineRequest())
            succeeded = exitCode == 0
            if !succeeded && !(logText + pendingLogText).localizedCaseInsensitiveContains("error:") {
                appendLog("\nerror: setup exited while running \(installStageName(at: installStageIndex)).\n")
            }
        } catch {
            succeeded = false
            appendLog("\n\(error.localizedDescription)\n")
        }
        flushLog()
        isRunning = false
        if succeeded {
            progress = 1
            statusText = WrapperCreatedCopy.title
            frozenSetupSummaryItems = nil
            installStageIndex = -1
            installStageCompletedIndex = -1
            installFailed = false
        } else {
            statusText = "Failed"
            installFailed = true
        }
        return succeeded
    }

    func showExistingApp() {
        guard outputAppAlreadyExists else { return }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: outputAppPath)])
    }

    func showCreatedAppAndQuit() {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: outputAppPath)])
        NSApp.terminate(nil)
    }

    func openSavedLog() {
        let trimmed = savedLogPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let logURL = URL(fileURLWithPath: trimmed)
        let textEditURL = URL(fileURLWithPath: "/System/Applications/TextEdit.app")
        if FileManager.default.fileExists(atPath: textEditURL.path) {
            NSWorkspace.shared.open([logURL], withApplicationAt: textEditURL, configuration: NSWorkspace.OpenConfiguration())
        } else {
            NSWorkspace.shared.open(logURL)
        }
    }
}
