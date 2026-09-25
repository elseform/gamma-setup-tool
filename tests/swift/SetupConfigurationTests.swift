import Foundation

final class SetupConfigurationTests {
    func testOutputAppPathAddsAppSuffix() {
        let config = SetupConfiguration(appName: "stalker-gamma", installDirectory: "/tmp/GAMMA")

        XCTAssertEqual(config.outputAppPath, "/tmp/GAMMA/stalker-gamma.app")
    }

    func testOutputAppPathDoesNotDuplicateAppSuffix() {
        let config = SetupConfiguration(appName: "  stalker-gamma.app  ", installDirectory: "/tmp/GAMMA")

        XCTAssertEqual(config.outputAppPath, "/tmp/GAMMA/stalker-gamma.app")
    }

    func testDefaultOutputAppPathUsesApplicationsFolder() {
        let expected = URL(fileURLWithPath: SetupConfiguration.defaultInstallDirectory)
            .appendingPathComponent("stalker-gamma.app")
            .path

        XCTAssertEqual(SetupConfiguration().outputAppPath, expected)
    }

    func testWrapperNameValidationRejectsUnsafeNames() {
        XCTAssertTrue(SetupConfiguration.isValidWrapperName("GAMMA"))
        XCTAssertTrue(SetupConfiguration.isValidWrapperName("GAMMA.app"))
        XCTAssertFalse(SetupConfiguration.isValidWrapperName(""))
        XCTAssertFalse(SetupConfiguration.isValidWrapperName("../GAMMA"))
        XCTAssertFalse(SetupConfiguration.isValidWrapperName("GAMMA:Test"))
    }

    /// `manualModOrganizerPath` is the only MO2 source, and the file has to
    /// actually be there.
    func testModOrganizerTargetRequiresAnExistingExecutable() throws {
        let temp = try makeTempDir("gamma-environment")
        defer { try? FileManager.default.removeItem(at: temp) }
        let mo2 = temp.appendingPathComponent("ModOrganizer.exe")
        FileManager.default.createFile(atPath: mo2.path, contents: Data())

        XCTAssertTrue(SetupConfiguration(manualModOrganizerPath: mo2.path).selectedLaunchExecutableFound)
        XCTAssertFalse(SetupConfiguration().selectedLaunchExecutableFound)
        XCTAssertFalse(SetupConfiguration(manualModOrganizerPath: mo2.path + ".missing").selectedLaunchExecutableFound)
    }

    func testLaunchExecutableFallsBackToBareModOrganizerName() {
        let config = SetupConfiguration()

        XCTAssertEqual(config.selectedLaunchExecutablePath, "ModOrganizer.exe")
        XCTAssertEqual(config.selectedLaunchExecutableLabel, "ModOrganizer")
        // A bare relative name is not a resolved target.
        XCTAssertFalse(config.selectedLaunchExecutableFound)
    }

    func testCustomLaunchExecutableReplacesModOrganizer() throws {
        let temp = try makeTempDir("gamma-custom-launch")
        defer { try? FileManager.default.removeItem(at: temp) }
        let executable = temp.appendingPathComponent("AnomalyDX11AVX.exe")
        FileManager.default.createFile(atPath: executable.path, contents: Data())
        let config = SetupConfiguration(customLaunchExecutablePath: executable.path, manualModOrganizerPath: "/elsewhere/ModOrganizer.exe")

        XCTAssertEqual(config.selectedLaunchExecutablePath, executable.path)
        XCTAssertEqual(config.selectedLaunchExecutableLabel, "AnomalyDX11AVX.exe")
        XCTAssertTrue(config.selectedLaunchExecutableFound)
    }

    func testCustomLaunchExecutableMustStillExist() throws {
        let temp = try makeTempDir("gamma-custom-launch-missing")
        defer { try? FileManager.default.removeItem(at: temp) }
        let executable = temp.appendingPathComponent("AnomalyDX11AVX.exe")
        FileManager.default.createFile(atPath: executable.path, contents: Data())
        let config = SetupConfiguration(customLaunchExecutablePath: executable.path)

        XCTAssertTrue(config.selectedLaunchExecutableFound)
        try FileManager.default.removeItem(at: executable)
        XCTAssertFalse(config.selectedLaunchExecutableFound)
    }

    /// interactive_setup.py mounts both Z: and G: unconditionally, so there is
    /// no drive-mapping mode any more — G: is simply derived from the resolved
    /// launch target, two components up.
    func testDriveMappingIsDerivedFromTheResolvedLaunchTarget() throws {
        let temp = try makeTempDir("gamma-drive-mapping")
        defer { try? FileManager.default.removeItem(at: temp) }
        let gamesRoot = temp.appendingPathComponent("Games", isDirectory: true)
        let gammaRoot = gamesRoot.appendingPathComponent("GAMMA", isDirectory: true)
        try FileManager.default.createDirectory(at: gammaRoot, withIntermediateDirectories: true)
        let mo2 = gammaRoot.appendingPathComponent("ModOrganizer.exe")
        FileManager.default.createFile(atPath: mo2.path, contents: Data())

        let config = SetupConfiguration(manualModOrganizerPath: mo2.path)
        let expectedRoot = gamesRoot.standardizedFileURL.path
        XCTAssertEqual(config.optionalGDriveRoot, expectedRoot)
        XCTAssertEqual(config.plannedWineDriveMapping, "G: -> \(expectedRoot)")
    }

    /// Without a resolved launch target there is no G: root to derive, so the
    /// mapping falls back to plain Z:.
    func testDriveMappingIsNotReadyWithoutAResolvedLaunchTarget() {
        let config = SetupConfiguration()

        XCTAssertEqual(config.optionalGDriveRoot, "")
        XCTAssertEqual(config.plannedWineDriveMapping, "Z: -> /")
    }
}

private func makeTempDir(_ prefix: String) throws -> URL {
    let url = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("\(prefix)-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}
