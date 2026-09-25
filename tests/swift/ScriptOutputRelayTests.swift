import Foundation

/// interactive_setup.py's output reaches the GUI only through this relay, so
/// its line handling decides what the user sees when setup fails.
final class ScriptOutputRelayTests {
    private func makeRelay() throws -> (ScriptOutputRelay, URL) {
        let log = FileManager.default.temporaryDirectory
            .appendingPathComponent("gamma-relay-tests-\(UUID().uuidString).log")
        let reporter = JSONEventReporter(streamEvents: false)
        try reporter.attachLog(log)
        return (ScriptOutputRelay(reporter: reporter), log)
    }

    func testHoldsBackTheScriptsCompletedEventButKeepsItsFailure() throws {
        let (relay, log) = try makeRelay()
        _ = relay.receive(Data(#"{"type":"completed","success":false,"message":"zstd exited with status 1"}"#.utf8 + [0x0A]))
        XCTAssertEqual(relay.finish(), "zstd exited with status 1")
        let text = try String(contentsOf: log, encoding: .utf8)
        XCTAssertFalse(text.contains("[completed]"))
    }

    func testIgnoresASuccessfulCompletedEvent() throws {
        let (relay, _) = try makeRelay()
        _ = relay.receive(Data(#"{"type":"completed","success":true,"message":"Setup complete."}"#.utf8 + [0x0A]))
        XCTAssertNil(relay.finish())
    }

    func testRelaysLinesSplitAcrossChunksAndAFinalUnterminatedLine() throws {
        let (relay, log) = try makeRelay()
        _ = relay.receive(Data("Traceback (most recent".utf8))
        _ = relay.receive(Data(" call last)\nlast line without newline".utf8))
        XCTAssertNil(relay.finish())
        let text = try String(contentsOf: log, encoding: .utf8)
        XCTAssertContains(text, "[log] Traceback (most recent call last)")
        XCTAssertContains(text, "[log] last line without newline")
    }

    func testStopsAcceptingOutputAfterFinish() throws {
        let (relay, _) = try makeRelay()
        _ = relay.finish()
        XCTAssertFalse(relay.receive(Data("late\n".utf8)))
    }
}
