import Foundation

final class AppSettingsStoreTests {
    func testModOrganizerValidationRequiresExecutableNameAndFile() throws {
        let temp = try makeTempDir("gamma-settings-mo2-validation")
        defer { try? FileManager.default.removeItem(at: temp) }
        let mo2 = temp.appendingPathComponent("ModOrganizer.exe")
        let other = temp.appendingPathComponent("Other.exe")
        FileManager.default.createFile(atPath: mo2.path, contents: Data())
        FileManager.default.createFile(atPath: other.path, contents: Data())

        XCTAssertTrue(AppSettingsStore.isValidModOrganizerExecutable(mo2.path))
        XCTAssertFalse(AppSettingsStore.isValidModOrganizerExecutable(other.path))
        XCTAssertFalse(AppSettingsStore.isValidModOrganizerExecutable(mo2.path + ".missing"))
        // Whitespace-only and empty paths are rejected before touching the disk.
        XCTAssertFalse(AppSettingsStore.isValidModOrganizerExecutable("   "))
        XCTAssertFalse(AppSettingsStore.isValidModOrganizerExecutable(""))
    }

    /// The store now round-trips a whole `AppSettings`; the old
    /// `save(gammaPath:to:)` / `loadManualModOrganizerPath(from:)` pair and the
    /// folder-scan helper are gone — the app takes an explicit ModOrganizer.exe
    /// through NSOpenPanel instead.
    func testAppSettingsSaveAndLoadRoundTripsGammaPath() throws {
        let temp = try makeTempDir("gamma-settings-save")
        defer { try? FileManager.default.removeItem(at: temp) }
        let settingsURL = temp.appendingPathComponent("settings/settings.json")
        let mo2 = temp.appendingPathComponent("GAMMA/ModOrganizer.exe")

        try AppSettingsStore.save(settings: AppSettings(gammaPath: mo2.path), to: settingsURL)

        // save() creates the intermediate directory itself.
        XCTAssertTrue(FileManager.default.fileExists(atPath: settingsURL.path))
        XCTAssertEqual(AppSettingsStore.loadSettings(from: settingsURL).gammaPath, mo2.path)
    }

    func testAppSettingsLoadIgnoresMissingAndMalformedFiles() throws {
        let temp = try makeTempDir("gamma-settings-malformed")
        defer { try? FileManager.default.removeItem(at: temp) }
        let missing = temp.appendingPathComponent("missing.json")
        let malformed = temp.appendingPathComponent("malformed.json")
        try "{bad json}\n".write(to: malformed, atomically: true, encoding: .utf8)

        XCTAssertEqual(AppSettingsStore.loadSettings(from: missing), AppSettings())
        XCTAssertEqual(AppSettingsStore.loadSettings(from: malformed), AppSettings())
        XCTAssertEqual(AppSettingsStore.loadSettings(from: nil), AppSettings())
    }

    func testEnsureSettingsFileExistsCreatesDefaultJson() throws {
        let temp = try makeTempDir("gamma-settings-ensure")
        defer { try? FileManager.default.removeItem(at: temp) }
        let settingsURL = temp.appendingPathComponent("settings.json")

        XCTAssertFalse(FileManager.default.fileExists(atPath: settingsURL.path))
        AppSettingsStore.ensureSettingsFileExists(at: settingsURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: settingsURL.path))
        XCTAssertNil(AppSettingsStore.loadSettings(from: settingsURL).gammaPath)
    }

    func testEnsureSettingsFileExistsDoesNotOverwriteAnExistingFile() throws {
        let temp = try makeTempDir("gamma-settings-preserve")
        defer { try? FileManager.default.removeItem(at: temp) }
        let settingsURL = temp.appendingPathComponent("settings.json")
        try AppSettingsStore.save(settings: AppSettings(gammaPath: "/Games/GAMMA/ModOrganizer.exe"), to: settingsURL)

        AppSettingsStore.ensureSettingsFileExists(at: settingsURL)

        XCTAssertEqual(
            AppSettingsStore.loadSettings(from: settingsURL).gammaPath,
            "/Games/GAMMA/ModOrganizer.exe"
        )
    }

    private func makeTempDir(_ prefix: String) throws -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("\(prefix)-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
