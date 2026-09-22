import Foundation

/// Keeps ModOrganizer's own usvfs_*.dll/exe in line with the copies bundled
/// in this app. Those binaries belong to MO2's install folder, so nothing is
/// written unless the target folder actually holds ModOrganizer.exe — a
/// custom launch executable elsewhere (e.g. the game's bin folder) is left
/// alone. MO2's originals are backed up before anything is replaced, and only
/// the files that differ are touched.
public struct USVFSUpdater {
    public enum Outcome: Equatable {
        /// The folder has no ModOrganizer.exe; nothing was written.
        case notModOrganizer(URL)
        /// Every bundled binary already matches MO2's copy byte for byte.
        case upToDate(URL)
        /// `replaced` were written into `modOrganizerDirectory`; MO2's previous
        /// copies of the ones that existed were moved to `backupDirectory`.
        case updated(modOrganizerDirectory: URL, replaced: [String], backupDirectory: URL?)
    }

    public static let binaryNames = ["usvfs_x64.dll", "usvfs_proxy_x64.exe", "usvfs_x86.dll", "usvfs_proxy_x86.exe"]
    public static let modOrganizerExecutableName = "ModOrganizer.exe"
    public static let backupFolderName = "gamma-setup-tool-backups"

    private let fileManager: FileManager
    private let now: () -> Date

    public init(fileManager: FileManager = .default, now: @escaping () -> Date = Date.init) {
        self.fileManager = fileManager
        self.now = now
    }

    /// True when `directory` contains ModOrganizer.exe (any letter case, since
    /// the folder may come from a Windows install).
    public func isModOrganizerDirectory(_ directory: URL) -> Bool {
        guard let entries = try? fileManager.contentsOfDirectory(atPath: directory.path) else { return false }
        return entries.contains {
            $0.caseInsensitiveCompare(Self.modOrganizerExecutableName) == .orderedSame
        }
    }

    public func update(modOrganizerDirectory directory: URL, from source: URL) throws -> Outcome {
        for name in Self.binaryNames where !fileManager.fileExists(atPath: source.appendingPathComponent(name).path) {
            throw WineEngineSetupError.message("missing bundled usvfs binary: \(source.appendingPathComponent(name).path)")
        }
        guard isModOrganizerDirectory(directory) else {
            return .notModOrganizer(directory)
        }

        let outdated = Self.binaryNames.filter {
            !fileManager.contentsEqual(
                atPath: source.appendingPathComponent($0).path,
                andPath: directory.appendingPathComponent($0).path
            )
        }
        guard !outdated.isEmpty else {
            return .upToDate(directory)
        }

        let existing = outdated.filter { fileManager.fileExists(atPath: directory.appendingPathComponent($0).path) }
        var backupDirectory: URL?
        if !existing.isEmpty {
            let backup = try makeBackupDirectory(in: directory)
            for name in existing {
                try fileManager.copyItem(
                    at: directory.appendingPathComponent(name),
                    to: backup.appendingPathComponent(name)
                )
            }
            backupDirectory = backup
        }

        for name in outdated {
            let destination = directory.appendingPathComponent(name)
            let staged = directory.appendingPathComponent(".\(name).gamma-setup-tool-new")
            try? fileManager.removeItem(at: staged)
            try fileManager.copyItem(at: source.appendingPathComponent(name), to: staged)
            if fileManager.fileExists(atPath: destination.path) {
                _ = try fileManager.replaceItemAt(destination, withItemAt: staged)
            } else {
                try fileManager.moveItem(at: staged, to: destination)
            }
        }

        return .updated(modOrganizerDirectory: directory, replaced: outdated, backupDirectory: backupDirectory)
    }

    private func makeBackupDirectory(in directory: URL) throws -> URL {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let base = directory
            .appendingPathComponent(Self.backupFolderName)
            .appendingPathComponent("usvfs-\(formatter.string(from: now()))")
        var candidate = base
        var suffix = 1
        while fileManager.fileExists(atPath: candidate.path) {
            suffix += 1
            candidate = URL(fileURLWithPath: "\(base.path)-\(suffix)")
        }
        try fileManager.createDirectory(at: candidate, withIntermediateDirectories: true)
        return candidate
    }
}
