import Foundation

/// Covers picking the newest published release (EngineBuildVersion ordering,
/// EngineVersionParser, EngineReleaseResolver) and reading the checksum out of
/// its manifest. All synchronous and offline.
final class EngineArchiveTests {
    // MARK: - EngineBuildVersion

    func testComparatorOrdersByCrossoverThenWineThenGammaThenBuild() {
        let base = EngineBuildVersion(crossover: [26, 3, 0], wineMajor: 11, gamma: 87, build: 10)
        XCTAssertTrue(base < EngineBuildVersion(crossover: [26, 3, 0], wineMajor: 11, gamma: 87, build: 11))
        XCTAssertTrue(base < EngineBuildVersion(crossover: [26, 3, 0], wineMajor: 11, gamma: 88, build: 1))
        XCTAssertTrue(base < EngineBuildVersion(crossover: [26, 3, 0], wineMajor: 12, gamma: 1, build: 1))
        XCTAssertTrue(base < EngineBuildVersion(crossover: [27, 0, 0], wineMajor: 1, gamma: 1, build: 1))
        XCTAssertFalse(base < EngineBuildVersion(crossover: [26, 3, 0], wineMajor: 11, gamma: 87, build: 9))
    }

    func testComparatorTreatsShortAndLongCrossoverFormsAsEqual() {
        // engineId's "26.3" and versionLabel's "26.3.0" must compare equal.
        let short = EngineBuildVersion(crossover: [26, 3], wineMajor: 11, gamma: 87, build: 14)
        let long = EngineBuildVersion(crossover: [26, 3, 0], wineMajor: 11, gamma: 87, build: 14)
        XCTAssertTrue(short == long)
        XCTAssertFalse(short < long)
        XCTAssertFalse(long < short)
    }

    // MARK: - EngineVersionParser

    func testParseLabelHandlesTheVersionLabelForm() {
        let parsed = EngineVersionParser.parseLabel("CX26.3.0-W11-Gamma087")
        XCTAssertEqual(parsed?.crossover, [26, 3, 0])
        XCTAssertEqual(parsed?.wineMajor, 11)
        XCTAssertEqual(parsed?.gamma, 87)
    }

    func testParseLabelHandlesTheEngineIdSlugForm() {
        let parsed = EngineVersionParser.parseLabel("cx26.3-w11-gamma087")
        XCTAssertEqual(parsed?.crossover, [26, 3])
        XCTAssertEqual(parsed?.wineMajor, 11)
        XCTAssertEqual(parsed?.gamma, 87)
    }

    func testParseLabelRejectsGarbage() {
        XCTAssertNil(EngineVersionParser.parseLabel("not-an-engine-label"))
    }

    func testParseBuildCounterFromCurrentAndLegacyNames() {
        XCTAssertEqual(EngineVersionParser.parseBuildCounter(fromName: "CX26W11-GAMMA-DXMT-14.tar.zst"), 14)
        XCTAssertEqual(EngineVersionParser.parseBuildCounter(fromName: "CX26W11-Gamma086-4.tar.xz"), 4)
        XCTAssertEqual(EngineVersionParser.parseBuildCounter(fromName: "engine-cx26.3-w11-gamma087-14"), 14)
        // The string-sort trap this exists to avoid: -7 must not "beat" -10.
        XCTAssertTrue((EngineVersionParser.parseBuildCounter(fromName: "x-7") ?? 0)
            < (EngineVersionParser.parseBuildCounter(fromName: "x-10") ?? 0))
        XCTAssertNil(EngineVersionParser.parseBuildCounter(fromName: "no-dash-here"))
    }

    // MARK: - EngineManifest decoding

    func testDecodesTheSidecarManifestShape() throws {
        let json = """
        {"schemaVersion":1,"versionLabel":"CX26.3.0-W11-Gamma087","buildNumber":14,
         "artifact":"CX26W11-GAMMA-DXMT-14.tar.zst","artifactSHA256":"abc123"}
        """
        let manifest = try EngineManifest.decode(from: Data(json.utf8))
        XCTAssertEqual(manifest.artifact, "CX26W11-GAMMA-DXMT-14.tar.zst")
        XCTAssertEqual(manifest.artifactSHA256, "abc123")
    }

    func testRejectsAnUnsupportedSchemaVersion() {
        let json = #"{"schemaVersion":0}"#
        XCTAssertThrows(try EngineManifest.decode(from: Data(json.utf8)))
    }

    func testEveryFieldExceptSchemaVersionIsOptional() throws {
        let manifest = try EngineManifest.decode(from: Data(#"{"schemaVersion":1}"#.utf8))
        XCTAssertNil(manifest.artifact)
        XCTAssertNil(manifest.artifactSHA256)
    }

    // MARK: - EngineReleaseResolver (pure selection over fixtures)

    private func makeRelease(tag: String, archiveName: String, sha: String = "abc") -> GitHubRelease {
        GitHubRelease(tagName: tag, assets: [
            GitHubReleaseAsset(name: archiveName, browserDownloadURL: "https://example.invalid/\(archiveName)"),
            GitHubReleaseAsset(name: archiveName + ".sha256", browserDownloadURL: "https://example.invalid/\(archiveName).sha256"),
            GitHubReleaseAsset(name: archiveName + ".manifest.json", browserDownloadURL: "https://example.invalid/\(archiveName).manifest.json"),
        ])
    }

    func testPicksTheNewestEngineReleaseByVersionNotArrayOrder() throws {
        let releases = [
            makeRelease(tag: "engine-cx26.3-w11-gamma087-7", archiveName: "CX26W11-GAMMA-DXMT-7.tar.zst"),
            makeRelease(tag: "engine-cx26.3-w11-gamma087-14", archiveName: "CX26W11-GAMMA-DXMT-14.tar.zst"),
            makeRelease(tag: "engine-cx26.3-w11-gamma087-10", archiveName: "CX26W11-GAMMA-DXMT-10.tar.zst"),
        ]
        let resolved = try EngineReleaseResolver.newestEngineRelease(in: releases)
        XCTAssertEqual(resolved.archiveName, "CX26W11-GAMMA-DXMT-14.tar.zst")
    }

    func testIgnoresReleasesWithoutTheEngineTagPrefix() throws {
        let releases = [
            GitHubRelease(tagName: "v0.86", assets: []),
            makeRelease(tag: "engine-cx26.3-w11-gamma087-14", archiveName: "CX26W11-GAMMA-DXMT-14.tar.zst"),
        ]
        let resolved = try EngineReleaseResolver.newestEngineRelease(in: releases)
        XCTAssertEqual(resolved.archiveName, "CX26W11-GAMMA-DXMT-14.tar.zst")
    }

    func testIgnoresAMalformedReleaseMissingSidecarAssets() throws {
        let malformed = GitHubRelease(tagName: "engine-cx26.3-w11-gamma087-99", assets: [
            GitHubReleaseAsset(name: "CX26W11-GAMMA-DXMT-99.tar.zst", browserDownloadURL: "https://example.invalid/x"),
        ])
        let releases = [malformed, makeRelease(tag: "engine-cx26.3-w11-gamma087-14", archiveName: "CX26W11-GAMMA-DXMT-14.tar.zst")]
        let resolved = try EngineReleaseResolver.newestEngineRelease(in: releases)
        XCTAssertEqual(resolved.archiveName, "CX26W11-GAMMA-DXMT-14.tar.zst")
    }

    func testThrowsWhenNoEngineReleaseExists() {
        XCTAssertThrows(try EngineReleaseResolver.newestEngineRelease(in: [GitHubRelease(tagName: "v0.86", assets: [])]))
    }

    // MARK: - Tool version stays in step with build.sh

    func testToolVersionMatchesBuildScriptAppVersion() throws {
        // build.sh has no way to read a Swift constant, so this checks the
        // other direction: SetupDefaults.toolVersion must match its
        // APP_VERSION= line.
        var dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        var buildScript: URL?
        for _ in 0..<6 {
            let candidate = dir.appendingPathComponent("build.sh")
            if FileManager.default.fileExists(atPath: candidate.path) {
                buildScript = candidate
                break
            }
            dir = dir.deletingLastPathComponent()
        }
        guard let buildScript, let contents = try? String(contentsOf: buildScript, encoding: .utf8) else {
            throw TestFailure(description: "could not find build.sh from tests/swift")
        }
        guard let line = contents.split(separator: "\n").first(where: { $0.hasPrefix("APP_VERSION=") }) else {
            throw TestFailure(description: "build.sh has no APP_VERSION= line")
        }
        let value = line
            .dropFirst("APP_VERSION=".count)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        XCTAssertEqual(value, SetupDefaults.toolVersion)
    }
}

func XCTAssertThrows<T>(_ expression: @autoclosure () throws -> T, file: StaticString = #file, line: UInt = #line) {
    do {
        _ = try expression()
        recordFailure("expected an error to be thrown", file: file, line: line)
    } catch {
        // expected
    }
}

func XCTFail(_ message: String, file: StaticString = #file, line: UInt = #line) {
    recordFailure(message, file: file, line: line)
}
