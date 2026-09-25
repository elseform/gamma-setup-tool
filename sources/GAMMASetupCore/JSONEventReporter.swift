import Foundation

public final class JSONEventReporter {
    private let encoder = JSONEncoder()
    private var logURL: URL?
    private let streamEvents: Bool

    public init(streamEvents: Bool = true) {
        self.streamEvents = streamEvents
        encoder.outputFormatting = [.sortedKeys]
    }

    public func attachLog(_ url: URL) throws {
        logURL = url
        try "gamma-setup-engine log\nStarted: \(Date())\n\n".write(to: url, atomically: true, encoding: .utf8)
        emit(.init(type: .artifact, message: "Log file", path: url.path))
    }

    public func log(_ message: String, severity: String = "info") {
        emit(.init(type: .log, message: message, severity: severity))
    }

    public func stageStarted(_ stage: SetupEngineStage) {
        emit(.init(type: .stageStarted, stage: stage))
    }

    public func stageFinished(_ stage: SetupEngineStage) {
        emit(.init(type: .stageFinished, stage: stage))
    }

    public func stageFailed(_ stage: SetupEngineStage, message: String) {
        emit(.init(type: .stageFailed, stage: stage, message: message, severity: "error"))
    }

    public func completed(success: Bool, message: String) {
        emit(.init(type: .completed, message: message, success: success))
    }

    /// Re-emits an event decoded from another process's own JSON-event
    /// stdout (e.g. `interactive_setup.py --json`) verbatim, so a driven
    /// subprocess speaking this same schema composes with this reporter
    /// without a translation layer.
    public func forward(_ event: SetupEngineEvent) {
        emit(event)
    }

    private func emit(_ event: SetupEngineEvent) {
        guard let data = try? encoder.encode(event),
              let text = String(data: data, encoding: .utf8) else {
            return
        }
        if streamEvents {
            FileHandle.standardOutput.write(Data((text + "\n").utf8))
        }
        if let logURL {
            let line = event.message ?? event.type.rawValue
            if let data = "[\(event.type.rawValue)] \(line)\n".data(using: .utf8),
               let handle = try? FileHandle(forWritingTo: logURL) {
                _ = try? handle.seekToEnd()
                _ = try? handle.write(contentsOf: data)
                _ = try? handle.close()
            }
        }
    }
}
