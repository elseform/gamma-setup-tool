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

    func runEngine<Request: Encodable>(
        command: String,
        request: Request,
        extraArguments: [String] = [],
        stream: Bool
    ) async throws -> ToolResult {
        let engine = engineURL
        let requestURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("gamma-setup-engine-\(UUID().uuidString).json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(request).write(to: requestURL, options: .atomic)

        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = engine
            process.arguments = [command, "--request-file", requestURL.path] + extraArguments
            process.currentDirectoryURL = engine.deletingLastPathComponent()

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe

            let buffer = OutputBuffer()
            let handle = pipe.fileHandleForReading
            handle.readabilityHandler = { [weak self] handle in
                let data = handle.availableData
                guard !data.isEmpty else { return }
                buffer.append(data)
                guard stream, let text = String(data: data, encoding: .utf8) else { return }
                Task { @MainActor in
                    self?.appendLog(text)
                }
            }

            process.terminationHandler = { [process] proc in
                process.terminationHandler = nil
                handle.readabilityHandler = nil
                try? FileManager.default.removeItem(at: requestURL)
                let remaining = handle.readDataToEndOfFile()
                if !remaining.isEmpty {
                    buffer.append(remaining)
                    if stream, let text = String(data: remaining, encoding: .utf8) {
                        Task { @MainActor in
                            self.appendLog(text)
                        }
                    }
                }
                let output = buffer.stringValue()
                continuation.resume(returning: ToolResult(output: output, exitCode: proc.terminationStatus))
            }

            do {
                try process.run()
            } catch {
                handle.readabilityHandler = nil
                try? FileManager.default.removeItem(at: requestURL)
                continuation.resume(throwing: error)
            }
        }
    }

    // MARK: - Event Handling

    private func appendLog(_ text: String) {
        pendingEngineEventText += text
        var lines = pendingEngineEventText.components(separatedBy: "\n")
        pendingEngineEventText = lines.popLast() ?? ""
        for line in lines where !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if handleEngineEventLine(line) {
                continue
            }
            logText += line + "\n"
        }
    }

    private func handleEngineEventLine(_ line: String) -> Bool {
        guard let data = line.data(using: .utf8),
              let event = try? JSONDecoder().decode(SetupEngineEvent.self, from: data) else {
            return false
        }
        receivedInstallStageEvents = true

        switch event.type {
        case .log:
            let message = event.message ?? ""
            guard !message.isEmpty else { return true }
            logText += "==> \(message)\n"
            statusText = message
            progress = min(progress + 0.07, 0.95)
        case .artifact:
            if event.message == "Log file", let path = event.path {
                savedLogPath = path
                logText += "Log location: \(path)\n"
            }
        case .completed:
            if let message = event.message, !message.isEmpty {
                logText += "\(message)\n"
            }
        case .stageStarted, .stageFinished, .stageFailed:
            guard let stage = event.stage, let index = installStageIndex(for: stage) else {
                return true
            }
            switch event.type {
            case .stageStarted:
                // Reaching stage N implies every earlier stage already
                // happened, even ones this particular pipeline never emits
                // its own stageStarted/stageFinished for (interactive_setup.py's
                // first-ever event is "engine", index 2 — it has nothing to
                // say about "dependencies"/"wrapper", indices 0/1) — without
                // this, those rows stay permanently unchecked even though
                // the install has clearly already passed them.
                if index > 0 {
                    installStageCompletedIndex = max(installStageCompletedIndex, index - 1)
                }
                installStageIndex = index
                statusText = installStageName(at: index)
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
                    logText += "error: \(message)\n"
                }
            default:
                break
            }
        }
        return true
    }

    private func installStageIndex(for stage: SetupEngineStage) -> Int? {
        switch stage {
        case .dependencies: return 0
        case .wrapper: return 1
        case .engine: return 2
        case .prefix: return 3
        case .driveMapping: return 4
        case .winetricks: return 5
        case .finalize: return 6
        }
    }

    var installStageCount: Int {
        7
    }

    func installStageName(at index: Int) -> String {
        switch index {
        case 0: return "preparing"
        case 1: return "wrapper creation"
        case 2: return "engine extraction"
        case 3: return "prefix initialization"
        case 4: return "drive mapping"
        case 5: return "installing redist DLLs"
        case 6: return "finalizing"
        default: return "setup"
        }
    }
}
