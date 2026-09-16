import Foundation

enum SetupStatusTone: String {
    case success
    case warning
    case error
    case secondary
    case accent

    static func checkRow(ok: Bool, warning: Bool) -> SetupStatusTone {
        ok ? .success : (warning ? .warning : .error)
    }

    static func statusRow(ok: Bool, warning: Bool) -> SetupStatusTone {
        checkRow(ok: ok, warning: warning)
    }
}
