import SwiftUI
import AppKit
import UniformTypeIdentifiers

#if SWIFT_PACKAGE
import GAMMASetupCore
#endif

extension AppModel {
    // MARK: - Request Construction

    /// Reuses the existing MO2 detection (`selectedLaunchExecutablePath`,
    /// already correct for both the auto-detected and custom-exe cases) and
    /// appName/installDirectory fields. Backend is hardcoded to "dxmt": the
    /// engine archives this tool installs (CX26W11-GAMMA-DXMT-<N>) carry no
    /// D3DMetal payload (`lib64/apple_gptk` is absent), so selecting it would
    /// hard-fail interactive_setup.py's own backend-presence check. No
    /// runtime-mode or dxmt-only choice either: redist installs exactly the
    /// set the engine declares, pinned and checksummed, so there's no reason
    /// to expose winetricks verbs as an alternative; dxmt-only only matters
    /// for interactive_setup.py's own *interactive* prompt-skipping —
    /// irrelevant here since backend and runtime-mode are always passed
    /// explicitly as flags.
    ///
    /// `gammaRoot` is computed directly from the resolved MO2 path — two
    /// directory levels up (MO2's own folder, then that folder's parent) —
    /// NOT from `preflight?.shortWineDriveRoot`. That field looked correct
    /// on paper (same computation, `zShortRoot`, one level above MO2's own
    /// folder so `ModOrganizer.ini`'s own stored `gamePath=G:\anomaly`-style
    /// paths resolve once mounted) but `model.preflight` is never actually
    /// populated anywhere in this app — the `gamma-setup-engine preflight`
    /// command exists but nothing calls it, so it's always nil. Confirmed
    /// live: it silently produced an empty `gammaRoot`, which then resolved
    /// to the *process's own working directory* (this app's own
    /// Contents/Resources) instead of erroring, since `URL(fileURLWithPath:
    /// "")` defaults to cwd. Computing directly here avoids depending on
    /// that dead code path entirely. Also makes the drive letter actually
    /// stored in a given user's `ModOrganizer.ini` (`Z:` for most, `G:` for
    /// some) a non-issue without any extra detection: `interactive_setup.py`
    /// always mounts *both* Z: (host root) and G: (this resolved root)
    /// unconditionally, so whichever one a given ini already references
    /// just resolves.
    func wineEngineRequest() -> WineEngineSetupRequest {
        let mo2URL = URL(fileURLWithPath: selectedLaunchExecutablePath)
        let gammaRoot = selectedLaunchExecutableFound
            ? mo2URL.deletingLastPathComponent().deletingLastPathComponent().standardizedFileURL.path
            : ""
        return WineEngineSetupRequest(
            archivePath: wineEngineArchivePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? nil : wineEngineArchivePath,
            releaseArchiveURL: nil,
            appName: appName,
            appParent: installDirectory,
            gammaRoot: gammaRoot,
            mo2Path: selectedLaunchExecutablePath,
            exeRelPath: nil,
            backend: "dxmt",
            runtimeMode: "redist",
            // Written into the Configurator's paths file as dxmtOnly. The
            // Configurator also detects a DXMT-only engine on its own; this
            // flag can only narrow what it offers, never widen it.
            dxmtOnly: true,
            yes: true,
            skipFinderAlias: false,
            forceExe: false,
            updateUSVFS: true,
            usvfsSource: SetupDefaults.defaultUSVFSSource,
            redistInstallerDirectory: redistInstallerDirectory,
            logFile: saveVerboseLog ? Self.newSetupLogPath(appName: appName) : nil
        )
    }

    /// ~/Library/Logs/gamma-setup-tool/<app name>-<timestamp>.log
    static func newSetupLogPath(appName: String, date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let logs = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Logs/gamma-setup-tool", isDirectory: true)
        let name = appName.isEmpty ? "setup" : appName
        return logs.appendingPathComponent("\(name)-\(formatter.string(from: date)).log").path
    }

    // MARK: - Process Execution

    /// Runs `gamma-setup-engine` and returns its exit status once every byte
    /// of its output has been handled. Output is read on a background queue
    /// until EOF and handed to the main queue in order; the exit status is
    /// delivered through that same queue, so the caller never sees the run
    /// finish before its last events are applied.
    func runEngine<Request: Encodable>(command: String, request: Request) async throws -> Int32 {
        let engine = engineURL
        let requestURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("gamma-setup-engine-\(UUID().uuidString).json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(request).write(to: requestURL, options: .atomic)

        let process = Process()
        process.executableURL = engine
        process.arguments = [command, "--request-file", requestURL.path]
        process.currentDirectoryURL = engine.deletingLastPathComponent()
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
        } catch {
            try? FileManager.default.removeItem(at: requestURL)
            throw error
        }

        return await withCheckedContinuation { continuation in
            let reader = pipe.fileHandleForReading
            DispatchQueue.global(qos: .userInitiated).async {
                while true {
                    let chunk = reader.availableData
                    if chunk.isEmpty { break }
                    DispatchQueue.main.async {
                        MainActor.assumeIsolated { self.receiveEngineOutput(chunk) }
                    }
                }
                process.waitUntilExit()
                try? FileManager.default.removeItem(at: requestURL)
                let status = process.terminationStatus
                DispatchQueue.main.async {
                    MainActor.assumeIsolated {
                        self.finishEngineOutput()
                        continuation.resume(returning: status)
                    }
                }
            }
        }
    }

    // MARK: - Event Handling

    private func receiveEngineOutput(_ data: Data) {
        pendingEngineOutput.append(data)
        let newline = UInt8(ascii: "\n")
        while let index = pendingEngineOutput.firstIndex(of: newline) {
            let line = String(decoding: pendingEngineOutput[pendingEngineOutput.startIndex..<index], as: UTF8.self)
            pendingEngineOutput.removeSubrange(pendingEngineOutput.startIndex...index)
            handleEngineOutputLine(line)
        }
    }

    /// Handles a final line with no trailing newline and shows any log text
    /// still waiting for the next batched update.
    private func finishEngineOutput() {
        if !pendingEngineOutput.isEmpty {
            handleEngineOutputLine(String(decoding: pendingEngineOutput, as: UTF8.self))
            pendingEngineOutput = Data()
        }
        flushLog()
    }

    private func handleEngineOutputLine(_ line: String) {
        guard !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        if !handleEngineEventLine(line) {
            appendLog(line + "\n")
        }
    }

    /// Wine can print thousands of lines. Appending each one to the published
    /// `logText` would re-render the output view per line, so appends are
    /// batched into at most one update every 100 ms.
    func appendLog(_ text: String) {
        pendingLogText += text
        guard !logFlushScheduled else { return }
        logFlushScheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            MainActor.assumeIsolated { self.flushLog() }
        }
    }

    func flushLog() {
        logFlushScheduled = false
        guard !pendingLogText.isEmpty else { return }
        logText += pendingLogText
        pendingLogText = ""
    }

    private func handleEngineEventLine(_ line: String) -> Bool {
        guard let data = line.data(using: .utf8),
              let event = try? JSONDecoder().decode(SetupEngineEvent.self, from: data) else {
            return false
        }

        switch event.type {
        case .log:
            let message = event.message ?? ""
            guard !message.isEmpty else { return true }
            appendLog("==> \(message)\n")
            statusText = message
        case .artifact:
            if event.message == "Log file", let path = event.path {
                savedLogPath = path
                appendLog("Log location: \(path)\n")
            }
        case .completed:
            if let message = event.message, !message.isEmpty {
                appendLog("\(message)\n")
            }
        case .stageStarted, .stageFinished, .stageFailed:
            guard let stage = event.stage, let index = installStageIndex(for: stage) else {
                return true
            }
            switch event.type {
            case .stageStarted:
                // Reaching stage N implies every earlier stage already
                // happened, even one a given run has nothing to report for.
                if index > 0 {
                    installStageCompletedIndex = max(installStageCompletedIndex, index - 1)
                }
                installStageIndex = index
                statusText = installStageName(at: index)
                progress = max(progress, Double(index) / Double(installStageCount))
            case .stageFinished:
                installStageCompletedIndex = max(installStageCompletedIndex, index)
                if installStageIndex == index {
                    installStageIndex = -1
                }
                progress = max(progress, Double(index + 1) / Double(installStageCount))
            case .stageFailed:
                installStageIndex = index
                installFailed = true
                if let message = event.message {
                    appendLog("error: \(message)\n")
                }
            default:
                break
            }
        }
        return true
    }

    /// Rows follow the order stages actually run in, which is
    /// `SetupEngineStage`'s declaration order.
    private func installStageIndex(for stage: SetupEngineStage) -> Int? {
        SetupEngineStage.allCases.firstIndex(of: stage)
    }

    var installStageCount: Int {
        SetupEngineStage.allCases.count
    }

    func installStageName(at index: Int) -> String {
        guard SetupEngineStage.allCases.indices.contains(index) else { return "setup" }
        switch SetupEngineStage.allCases[index] {
        case .dependencies: return "preparing"
        case .engine: return "engine extraction"
        case .prefix: return "prefix initialization"
        case .driveMapping: return "drive mapping"
        case .winetricks: return "installing redist DLLs"
        case .wrapper: return "wrapper creation"
        case .finalize: return "finalizing"
        }
    }
}
