import Foundation

struct AppSettings: Codable, Equatable {
    var gammaPath: String?

    init(gammaPath: String? = nil) {
        self.gammaPath = gammaPath
    }
}

enum AppSettingsStore {
    static let defaultInstallDirectory = NSString(string: "~/Applications").expandingTildeInPath

    static func defaultSettingsURL(fileManager: FileManager = .default) -> URL? {
        fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("gamma-setup-tool", isDirectory: true)
            .appendingPathComponent("settings.json")
    }

    static func loadSettings(from settingsURL: URL?) -> AppSettings {
        guard let settingsURL,
              let data = try? Data(contentsOf: settingsURL),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            return AppSettings()
        }
        return settings
    }

    static func save(settings: AppSettings, to settingsURL: URL?) throws {
        guard let settingsURL else { return }
        try FileManager.default.createDirectory(
            at: settingsURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(settings).write(to: settingsURL, options: .atomic)
    }

    static func ensureSettingsFileExists(at settingsURL: URL?) {
        guard let settingsURL else { return }
        if !FileManager.default.fileExists(atPath: settingsURL.path) {
            try? save(settings: AppSettings(), to: settingsURL)
        }
    }

    static func isValidModOrganizerExecutable(_ path: String, fileManager: FileManager = .default) -> Bool {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let url = URL(fileURLWithPath: trimmed)
        return url.lastPathComponent.caseInsensitiveCompare("ModOrganizer.exe") == .orderedSame
            && fileManager.fileExists(atPath: url.path)
    }

}
