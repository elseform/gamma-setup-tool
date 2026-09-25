import Foundation

/// Finds the `zstd` binary that `.tar.zst` engine archives need.
///
/// macOS's `/usr/bin/tar` (bsdtar) has no built-in zstd decoder: it shells
/// out to a `zstd` program found on `PATH`. An app launched from Finder gets
/// `PATH=/usr/bin:/bin:/usr/sbin:/sbin`, which never contains Homebrew's
/// `zstd`, so the known Homebrew locations are checked explicitly — the same
/// order `interactive_setup.py`'s `resolve_zstd()` uses.
public enum ZstdLocator {
    public static let installHint = "zstd is required for .tar.zst engine archives (install it with: brew install zstd)"

    public static func locate(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default
    ) -> URL? {
        let pathEntries = (environment["PATH"] ?? "")
            .split(separator: ":")
            .map { String($0) }
            .filter { !$0.isEmpty }
        let candidates = pathEntries.map { "\($0)/zstd" } + ["/opt/homebrew/bin/zstd", "/usr/local/bin/zstd"]
        return candidates
            .first { fileManager.isExecutableFile(atPath: $0) }
            .map { URL(fileURLWithPath: $0) }
    }

    /// Whether an archive with this name needs `zstd` to be read.
    public static func isRequired(forArchiveNamed name: String) -> Bool {
        name.hasSuffix(".tar.zst")
    }
}
