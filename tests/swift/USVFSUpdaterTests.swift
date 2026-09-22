import Foundation

/// The USVFS binaries belong to ModOrganizer's own folder. A launch executable
/// outside it must never receive them, and MO2's originals must survive a
/// replacement in a backup.
final class USVFSUpdaterTests {
    private let fileManager = FileManager.default
    private let fixedDate = Date(timeIntervalSince1970: 1_790_000_000)

    private func makeTempDirectory() throws -> URL {
        let url = fileManager.temporaryDirectory
            .appendingPathComponent("gamma-usvfs-tests-\(UUID().uuidString)")
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func write(_ text: String, to url: URL) throws {
        try Data(text.utf8).write(to: url)
    }

    private func read(_ url: URL) -> String? {
        (try? Data(contentsOf: url)).map { String(decoding: $0, as: UTF8.self) }
    }

    /// Bundled source with "new-<name>" contents.
    private func makeSource(in root: URL) throws -> URL {
        let source = root.appendingPathComponent("source")
        try fileManager.createDirectory(at: source, withIntermediateDirectories: true)
        for name in USVFSUpdater.binaryNames {
            try write("new-\(name)", to: source.appendingPathComponent(name))
        }
        return source
    }

    private func makeDirectory(_ name: String, in root: URL, withModOrganizer: Bool) throws -> URL {
        let dir = root.appendingPathComponent(name)
        try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        if withModOrganizer {
            try write("mo2", to: dir.appendingPathComponent("ModOrganizer.exe"))
        }
        return dir
    }

    private var updater: USVFSUpdater {
        let date = fixedDate
        return USVFSUpdater(now: { date })
    }

    func testNonModOrganizerFolderIsLeftUntouched() throws {
        let root = try makeTempDirectory()
        defer { try? fileManager.removeItem(at: root) }
        let source = try makeSource(in: root)
        let bin = try makeDirectory("bin", in: root, withModOrganizer: false)
        try write("game", to: bin.appendingPathComponent("AnomalyDX11.exe"))

        let outcome = try updater.update(modOrganizerDirectory: bin, from: source)

        XCTAssertEqual(outcome, .notModOrganizer(bin))
        XCTAssertEqual(try fileManager.contentsOfDirectory(atPath: bin.path), ["AnomalyDX11.exe"])
    }

    func testMatchingBinariesAreNotRewrittenOrBackedUp() throws {
        let root = try makeTempDirectory()
        defer { try? fileManager.removeItem(at: root) }
        let source = try makeSource(in: root)
        let mo2 = try makeDirectory("mo2", in: root, withModOrganizer: true)
        for name in USVFSUpdater.binaryNames {
            try write("new-\(name)", to: mo2.appendingPathComponent(name))
        }

        let outcome = try updater.update(modOrganizerDirectory: mo2, from: source)

        XCTAssertEqual(outcome, .upToDate(mo2))
        XCTAssertFalse(fileManager.fileExists(atPath: mo2.appendingPathComponent(USVFSUpdater.backupFolderName).path))
    }

    func testDifferingBinariesAreBackedUpThenReplaced() throws {
        let root = try makeTempDirectory()
        defer { try? fileManager.removeItem(at: root) }
        let source = try makeSource(in: root)
        let mo2 = try makeDirectory("mo2", in: root, withModOrganizer: true)
        // One already current, one outdated, the rest missing.
        try write("new-usvfs_x64.dll", to: mo2.appendingPathComponent("usvfs_x64.dll"))
        try write("old-proxy", to: mo2.appendingPathComponent("usvfs_proxy_x64.exe"))

        let outcome = try updater.update(modOrganizerDirectory: mo2, from: source)

        guard case let .updated(dir, replaced, backup?) = outcome else {
            recordFailure("expected an update with a backup, got \(outcome)", file: #file, line: #line)
            return
        }
        XCTAssertEqual(dir, mo2)
        XCTAssertEqual(replaced, ["usvfs_proxy_x64.exe", "usvfs_x86.dll", "usvfs_proxy_x86.exe"])
        XCTAssertEqual(try fileManager.contentsOfDirectory(atPath: backup.path), ["usvfs_proxy_x64.exe"])
        XCTAssertEqual(read(backup.appendingPathComponent("usvfs_proxy_x64.exe")), "old-proxy")
        XCTAssertContains(backup.path, "/\(USVFSUpdater.backupFolderName)/usvfs-")
        for name in USVFSUpdater.binaryNames {
            XCTAssertEqual(read(mo2.appendingPathComponent(name)), "new-\(name)")
        }
        let leftovers = try fileManager.contentsOfDirectory(atPath: mo2.path).filter { $0.hasSuffix(".gamma-setup-tool-new") }
        XCTAssertTrue(leftovers.isEmpty)
    }

    func testMissingBinariesAreInstalledWithoutABackup() throws {
        let root = try makeTempDirectory()
        defer { try? fileManager.removeItem(at: root) }
        let source = try makeSource(in: root)
        let mo2 = try makeDirectory("mo2", in: root, withModOrganizer: true)

        let outcome = try updater.update(modOrganizerDirectory: mo2, from: source)

        XCTAssertEqual(outcome, .updated(modOrganizerDirectory: mo2, replaced: USVFSUpdater.binaryNames, backupDirectory: nil))
        XCTAssertFalse(fileManager.fileExists(atPath: mo2.appendingPathComponent(USVFSUpdater.backupFolderName).path))
    }

    func testRepeatedUpdatesKeepEarlierBackups() throws {
        let root = try makeTempDirectory()
        defer { try? fileManager.removeItem(at: root) }
        let source = try makeSource(in: root)
        let mo2 = try makeDirectory("mo2", in: root, withModOrganizer: true)
        let target = mo2.appendingPathComponent("usvfs_x64.dll")

        try write("first", to: target)
        guard case let .updated(_, _, first?) = try updater.update(modOrganizerDirectory: mo2, from: source) else {
            recordFailure("expected first backup", file: #file, line: #line)
            return
        }
        try write("second", to: target)
        guard case let .updated(_, _, second?) = try updater.update(modOrganizerDirectory: mo2, from: source) else {
            recordFailure("expected second backup", file: #file, line: #line)
            return
        }

        XCTAssertFalse(first == second)
        XCTAssertEqual(read(first.appendingPathComponent("usvfs_x64.dll")), "first")
        XCTAssertEqual(read(second.appendingPathComponent("usvfs_x64.dll")), "second")
    }

    func testModOrganizerDetectionIgnoresLetterCase() throws {
        let root = try makeTempDirectory()
        defer { try? fileManager.removeItem(at: root) }
        let dir = try makeDirectory("mo2", in: root, withModOrganizer: false)
        try write("mo2", to: dir.appendingPathComponent("modorganizer.EXE"))

        XCTAssertTrue(updater.isModOrganizerDirectory(dir))
        XCTAssertFalse(updater.isModOrganizerDirectory(root))
    }
}
