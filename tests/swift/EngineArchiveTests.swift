import Foundation

/// Covers the Phase 4 version gate: EngineBuildVersion ordering,
/// EngineVersionParser, EngineManifest decoding, EngineFloor's pure
/// computation, EngineArchiveGate, and EngineReleaseResolver's pure release
/// selection. All synchronous and offline — no network, no archive
/// extraction beyond an optional local one already on disk.
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

    /// The case a synthesised Equatable would get wrong: two builds with the
    /// same ordering fields but different family/label must still be equal
    /// and neither less than the other, or sorted()/max() silently corrupts.
    func testEqualityIgnoresFamilyAndLabelByDesign() {
        let a = EngineBuildVersion(crossover: [26, 3, 0], wineMajor: 11, gamma: 87, build: 14, family: "GAMMA-DXMT", label: "CX26.3.0-W11-Gamma087")
        let b = EngineBuildVersion(crossover: [26, 3, 0], wineMajor: 11, gamma: 87, build: 14, family: nil, label: nil)
        XCTAssertTrue(a == b)
        XCTAssertFalse(a < b)
        XCTAssertFalse(b < a)
        let sorted = [a, b].sorted()
        XCTAssertEqual(sorted.count, 2)
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

    func testVersionPrefersManifestBuildNumberOverName() throws {
        let manifest = EngineManifest(versionLabel: "CX26.3.0-W11-Gamma087", buildNumber: 99)
        let version = try EngineVersionParser.version(manifest: manifest, name: "CX26W11-GAMMA-DXMT-14.tar.zst")
        XCTAssertEqual(version.build, 99)
    }

    func testVersionFallsBackToNameWhenNoBuildNumber() throws {
        let manifest = EngineManifest(versionLabel: "CX26.3.0-W11-Gamma087")
        let version = try EngineVersionParser.version(manifest: manifest, name: "CX26W11-GAMMA-DXMT-14.tar.zst")
        XCTAssertEqual(version.build, 14)
    }

    func testVersionRefusesRatherThanGuessingBuildZero() {
        let manifest = EngineManifest(versionLabel: "CX26.3.0-W11-Gamma087")
        XCTAssertThrows(try EngineVersionParser.version(manifest: manifest, name: nil))
    }

    // MARK: - EngineManifest decoding

    func testDecodesTheInArchiveManifestShape() throws {
        let json = """
        {"schemaVersion":1,"engineId":"cx26.3-w11-gamma087","versionLabel":"CX26.3.0-W11-Gamma087",
         "buildNumber":14,"minimumMacOS":"15.0","artifact":null,"artifactSHA256":null}
        """
        let manifest = try EngineManifest.decode(from: Data(json.utf8))
        XCTAssertEqual(manifest.buildNumber, 14)
        XCTAssertNil(manifest.artifact)
    }

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
        XCTAssertNil(manifest.engineId)
        XCTAssertNil(manifest.buildNumber)
        XCTAssertNil(manifest.minimumMacOS)
    }

    // MARK: - EngineFloor (pure computation)

    private var v14: EngineBuildVersion { EngineBuildVersion(crossover: [26, 3, 0], wineMajor: 11, gamma: 87, build: 14) }
    private var v10: EngineBuildVersion { EngineBuildVersion(crossover: [26, 3, 0], wineMajor: 11, gamma: 87, build: 10) }
    private var v1: EngineBuildVersion { EngineBuildVersion(crossover: [0], wineMajor: 0, gamma: 0, build: 1) }

    func testFloorFromLiveAndNoCache() {
        let floor = EngineFloor.compute(live: v14, cached: nil, compiledMinimum: v1)
        XCTAssertEqual(floor.version, v14)
        XCTAssertEqual(floor.source, .liveRelease)
    }

    func testFloorFromLiveOlderThanCacheStillUsesTheHigherCache() {
        // A machine that saw v14 once must not be talked down to v10 by a
        // later resolve that (implausibly) returns an older "latest".
        let floor = EngineFloor.compute(live: v10, cached: v14, compiledMinimum: v1)
        XCTAssertEqual(floor.version, v14)
        XCTAssertEqual(floor.source, .cachedRelease)
    }

    func testFloorFromCacheOnlyWhenLiveUnavailable() {
        let floor = EngineFloor.compute(live: nil, cached: v10, compiledMinimum: v1)
        XCTAssertEqual(floor.version, v10)
        XCTAssertEqual(floor.source, .cachedRelease)
    }

    func testFloorFallsBackToCompiledMinimumWithNoLiveAndNoCache() {
        let floor = EngineFloor.compute(live: nil, cached: nil, compiledMinimum: v1)
        XCTAssertEqual(floor.version, v1)
        XCTAssertEqual(floor.source, .compiledMinimum)
    }

    func testFloorNeverDropsBelowTheCompiledMinimumEvenIfCacheIsSomehowOlder() {
        let ancient = EngineBuildVersion(crossover: [0], wineMajor: 0, gamma: 0, build: 0)
        let floor = EngineFloor.compute(live: nil, cached: ancient, compiledMinimum: v1)
        XCTAssertEqual(floor.version, v1)
    }

    /// Regression: an earlier draft built the compiled minimum from an
    /// all-zero placeholder generation (crossover [0], wineMajor 0, gamma 0).
    /// Ordering compares generation before build counter, so that placeholder
    /// was outranked by any real CX26/Gamma87 archive regardless of its build
    /// number — build 0 of the real generation was silently accepted. The
    /// real compiled minimum must be expressed in the current generation for
    /// its build-number floor to mean anything.
    func testCompiledMinimumIsExpressedInTheCurrentGenerationSoBuildZeroIsRefused() {
        let zeroBuildSameGeneration = EngineBuildVersion(crossover: [26, 3, 0], wineMajor: 11, gamma: 87, build: 0)
        XCTAssertTrue(zeroBuildSameGeneration < SetupDefaults.minimumSupportedEngine)
        let manifest = EngineManifest(versionLabel: "CX26.3.0-W11-Gamma087", buildNumber: 0)
        let decision = EngineArchiveGate.evaluate(
            manifest: manifest, archiveName: nil,
            floor: SetupDefaults.minimumSupportedEngine, floorSource: .compiledMinimum
        )
        guard case .refuse(.olderThanFloor) = decision else {
            return XCTFail("expected the compiled minimum to refuse build 0 of its own generation")
        }
    }

    // MARK: - EngineArchiveGate

    func testAcceptsAnArchiveAtOrAboveTheFloor() {
        let manifest = EngineManifest(versionLabel: "CX26.3.0-W11-Gamma087", buildNumber: 14)
        let decision = EngineArchiveGate.evaluate(
            manifest: manifest, archiveName: nil, floor: v14, floorSource: .liveRelease
        )
        guard case .accept(let version) = decision else { return XCTFail("expected accept") }
        XCTAssertEqual(version.build, 14)
    }

    func testRefusesAnArchiveBelowTheFloorWithNoOverride() {
        let manifest = EngineManifest(versionLabel: "CX26.3.0-W11-Gamma087", buildNumber: 10)
        let decision = EngineArchiveGate.evaluate(
            manifest: manifest, archiveName: nil, floor: v14, floorSource: .liveRelease
        )
        guard case .refuse(.olderThanFloor(let archive, let floor, _)) = decision else {
            return XCTFail("expected olderThanFloor refusal")
        }
        XCTAssertEqual(archive.build, 10)
        XCTAssertEqual(floor.build, 14)
    }

    func testAcceptsANewerLocalBuildAboveTheFloor() {
        let manifest = EngineManifest(versionLabel: "CX26.3.0-W11-Gamma087", buildNumber: 20)
        let decision = EngineArchiveGate.evaluate(
            manifest: manifest, archiveName: nil, floor: v14, floorSource: .liveRelease
        )
        guard case .accept = decision else { return XCTFail("expected accept") }
    }

    func testRefusesAnArchiveNeedingANewerMacOS() {
        let manifest = EngineManifest(versionLabel: "CX26.3.0-W11-Gamma087", buildNumber: 14, minimumMacOS: "26.0")
        let decision = EngineArchiveGate.evaluate(
            manifest: manifest, archiveName: nil, floor: v1, floorSource: .compiledMinimum,
            currentOperatingSystem: DottedVersion(components: [15, 0, 0])
        )
        guard case .refuse(.macOSTooOld(let required, _)) = decision else {
            return XCTFail("expected macOSTooOld refusal")
        }
        XCTAssertEqual(required, "26.0")
    }

    func testAcceptsWhenThisMacMeetsTheRequiredMacOS() {
        let manifest = EngineManifest(versionLabel: "CX26.3.0-W11-Gamma087", buildNumber: 14, minimumMacOS: "15.0")
        let decision = EngineArchiveGate.evaluate(
            manifest: manifest, archiveName: nil, floor: v1, floorSource: .compiledMinimum,
            currentOperatingSystem: DottedVersion(components: [15, 0, 0])
        )
        guard case .accept = decision else { return XCTFail("expected accept") }
    }

    func testRefusesAnArchiveNeedingANewerSetupTool() {
        let manifest = EngineManifest(versionLabel: "CX26.3.0-W11-Gamma087", buildNumber: 14, minimumSetupToolVersion: "2.0")
        let decision = EngineArchiveGate.evaluate(
            manifest: manifest, archiveName: nil, floor: v1, floorSource: .compiledMinimum,
            currentToolVersion: "0.90"
        )
        guard case .refuse(.setupToolTooOld(let required, let current)) = decision else {
            return XCTFail("expected setupToolTooOld refusal")
        }
        XCTAssertEqual(required, "2.0")
        XCTAssertEqual(current, "0.90")
    }

    func testAcceptsAnEqualVersionNotOnlyNewer() {
        // The rule is "older", not "not newer" — equal must be accepted.
        let manifest = EngineManifest(versionLabel: "CX26.3.0-W11-Gamma087", buildNumber: 14)
        let decision = EngineArchiveGate.evaluate(
            manifest: manifest, archiveName: nil, floor: v14, floorSource: .liveRelease
        )
        guard case .accept = decision else { return XCTFail("expected accept") }
    }

    func testRefusesRatherThanGuessingWhenTheManifestLabelIsUnreadable() {
        let manifest = EngineManifest(versionLabel: "garbage")
        let decision = EngineArchiveGate.evaluate(
            manifest: manifest, archiveName: nil, floor: v1, floorSource: .compiledMinimum
        )
        guard case .refuse(.unreadableManifest) = decision else {
            return XCTFail("expected unreadableManifest refusal")
        }
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

    // MARK: - EngineArchiveProbe (only if a real archive is present)

    func testProbeReadsTheManifestFromARealLocalArchiveWhenOneExists() throws {
        let candidates = [
            "~/projects/2_2_gamma/gamma-wine-engine/dist/artifacts",
        ].map { URL(fileURLWithPath: ($0 as NSString).expandingTildeInPath) }
        guard let dir = candidates.first(where: { FileManager.default.fileExists(atPath: $0.path) }),
              let entries = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil),
              let archive = entries.first(where: { $0.lastPathComponent.hasSuffix(".tar.zst") }) else {
            return // no local engine checkout on this machine; nothing to probe
        }
        let manifest = try EngineArchiveProbe.readManifest(archiveURL: archive)
        XCTAssertTrue(manifest.schemaVersion >= 1)
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
