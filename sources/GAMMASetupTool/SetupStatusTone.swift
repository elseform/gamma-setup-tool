import Foundation

enum SetupStatusTone: String {
    case success
    case warning
    case error

    static func checkRow(ok: Bool, warning: Bool) -> SetupStatusTone {
        ok ? .success : (warning ? .warning : .error)
    }
}
