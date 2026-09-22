import Foundation

/// The redistributables are fetched, not shipped, so two things have to hold:
/// a request written before that change still decodes, and the GUI's
/// "already downloaded / will be downloaded" answer follows the same
/// precedence the fetcher itself uses.
final class RedistInstallerTests {
    private func makeTempDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("gamma-redist-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    func testRequestWithoutARedistDirectoryStillDecodes() throws {
        // Exactly the shape the app wrote before the field existed.
        let json = """
        {
          "archivePath" : "/tmp/engine.tar.zst",
          "appName" : "stalker-gamma",
          "appParent" : "/tmp/apps",
          "gammaRoot" : "/tmp/GAMMA",
          "mo2Path" : "",
          "backend" : "dxmt",
          "runtimeMode" : "redist",
          "dxmtOnly" : true,
          "yes" : true,
          "skipFinderAlias" : true,
          "forceExe" : false,
          "updateUSVFS" : false,
          "usvfsSource" : ""
        }
        """
        let request = try JSONDecoder().decode(
            WineEngineSetupRequest.self, from: Data(json.utf8)
        )

        XCTAssertNil(request.redistInstallerDirectory)
        XCTAssertEqual(request.appName, "stalker-gamma")
    }

    func testRequestRoundTripsASuppliedRedistDirectory() throws {
        let request = WineEngineSetupRequest(
            archivePath: "/tmp/engine.tar.zst",
            redistInstallerDirectory: "/tmp/installers"
        )
        let data = try JSONEncoder().encode(request)
        let decoded = try JSONDecoder().decode(WineEngineSetupRequest.self, from: data)

        XCTAssertEqual(decoded.redistInstallerDirectory, "/tmp/installers")
    }

    func testRequestRoundTripsALogFile() throws {
        let request = WineEngineSetupRequest(archivePath: "/tmp/engine.tar.zst", logFile: "/tmp/setup.log")
        let data = try JSONEncoder().encode(request)
        let decoded = try JSONDecoder().decode(WineEngineSetupRequest.self, from: data)

        XCTAssertEqual(decoded.logFile, "/tmp/setup.log")
    }

    func testEveryPinnedInstallerIsReportedOnce() {
        let statuses = RedistInstallers.statuses(
            userDirectory: "",
            cacheDirectory: URL(fileURLWithPath: "/nonexistent-cache")
        )

        XCTAssertEqual(statuses.count, RedistInstallers.all.count)
        XCTAssertEqual(
            statuses.map(\.installer.filename).sorted(),
            RedistInstallers.all.map(\.filename).sorted()
        )
        XCTAssertTrue(statuses.allSatisfy { !$0.isPresent })
    }

    func testCachedInstallersAreReportedAsPresent() throws {
        let cache = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: cache) }
        let cached = RedistInstallers.all[0]
        FileManager.default.createFile(
            atPath: cache.appendingPathComponent(cached.filename).path, contents: Data()
        )

        let statuses = RedistInstallers.statuses(userDirectory: "", cacheDirectory: cache)
        let match = statuses.first { $0.installer == cached }

        XCTAssertEqual(match?.location, cache.appendingPathComponent(cached.filename))
        XCTAssertEqual(statuses.filter(\.isPresent).count, 1)
    }

    /// The whole point of the override: a copy the user supplied wins, so the
    /// run never has to reach the network even when the cache also has one.
    func testASuppliedDirectoryWinsOverTheCache() throws {
        let cache = try makeTempDirectory()
        let supplied = try makeTempDirectory()
        defer {
            try? FileManager.default.removeItem(at: cache)
            try? FileManager.default.removeItem(at: supplied)
        }
        let installer = RedistInstallers.all[0]
        for directory in [cache, supplied] {
            FileManager.default.createFile(
                atPath: directory.appendingPathComponent(installer.filename).path, contents: Data()
            )
        }

        let statuses = RedistInstallers.statuses(
            userDirectory: supplied.path, cacheDirectory: cache
        )

        XCTAssertEqual(
            statuses.first { $0.installer == installer }?.location,
            supplied.appendingPathComponent(installer.filename)
        )
    }
}
