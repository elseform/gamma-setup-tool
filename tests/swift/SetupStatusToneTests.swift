import Foundation

final class SetupStatusToneTests {
    func testCheckRowTonesMatchEnvironmentColoringRules() {
        XCTAssertEqual(SetupStatusTone.checkRow(ok: true, warning: false), .success)
        XCTAssertEqual(SetupStatusTone.checkRow(ok: false, warning: true), .warning)
        XCTAssertEqual(SetupStatusTone.checkRow(ok: false, warning: false), .error)
    }
}
