import Foundation

final class SetupStatusToneTests {
    func testCheckRowTonesMatchEnvironmentColoringRules() {
        XCTAssertEqual(SetupStatusTone.checkRow(ok: true, warning: false), .success)
        XCTAssertEqual(SetupStatusTone.checkRow(ok: false, warning: true), .warning)
        XCTAssertEqual(SetupStatusTone.checkRow(ok: false, warning: false), .error)
    }

    func testStatusRowTonesMatchCheckRows() {
        XCTAssertEqual(SetupStatusTone.statusRow(ok: true, warning: false), .success)
        XCTAssertEqual(SetupStatusTone.statusRow(ok: false, warning: true), .warning)
        XCTAssertEqual(SetupStatusTone.statusRow(ok: false, warning: false), .error)
    }
}
