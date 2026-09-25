import Foundation

/// Splits interactive_setup.py's output into lines and relays each one:
/// events are forwarded as-is, anything else is logged as text. The script's
/// own `completed` event is held back (setup is not complete until the USVFS
/// step after it) and only its failure message is kept. Locked because the
/// reader queue and the caller's `finish()` can overlap after a timeout.
final class ScriptOutputRelay: @unchecked Sendable {
    private let reporter: JSONEventReporter
    private let decoder = JSONDecoder()
    private let lock = NSLock()
    private var buffer = Data()
    private var failureMessage: String?
    private var finished = false

    init(reporter: JSONEventReporter) {
        self.reporter = reporter
    }

    /// Returns false once `finish()` has run, telling the reader to stop.
    func receive(_ chunk: Data) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !finished else { return false }
        buffer.append(chunk)
        let newline = UInt8(ascii: "\n")
        while let index = buffer.firstIndex(of: newline) {
            handle(buffer[buffer.startIndex..<index])
            buffer.removeSubrange(buffer.startIndex...index)
        }
        return true
    }

    /// Handles a final unterminated line and returns the script's failure
    /// message, if it reported one.
    func finish() -> String? {
        lock.lock()
        defer { lock.unlock() }
        finished = true
        handle(buffer)
        buffer.removeAll()
        return failureMessage
    }

    private func handle(_ lineData: Data) {
        guard !lineData.isEmpty else { return }
        if let event = try? decoder.decode(SetupEngineEvent.self, from: lineData) {
            if event.type == .completed {
                if event.success == false {
                    failureMessage = event.message ?? "interactive_setup.py failed"
                }
            } else {
                reporter.forward(event)
            }
        } else if let text = String(data: lineData, encoding: .utf8) {
            reporter.log(text)
        }
    }
}
