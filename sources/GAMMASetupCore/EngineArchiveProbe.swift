import Foundation

/// Reads `wswine.bundle/engine-manifest.json` out of a packed engine archive
/// without extracting it. `/usr/bin/tar -xOf` streams a single member straight
/// out of a `.tar.zst`/`.tar.xz` (`tar` decompresses through `libarchive`, no
/// separate `zstd` binary needed) in well under a second on a 130 MB archive —
/// much cheaper than unpacking to probe.
public enum EngineArchiveProbe {
    public static func readManifest(archiveURL: URL, tarPath: String = "/usr/bin/tar") throws -> EngineManifest {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tarPath)
        process.arguments = ["-xOf", archiveURL.path, "wswine.bundle/engine-manifest.json"]
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        try process.run()
        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0, !data.isEmpty else {
            let errorText = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            throw WineEngineSetupError.message(
                "could not read engine-manifest.json from \(archiveURL.lastPathComponent)"
                    + (errorText.isEmpty ? "" : ": \(errorText.trimmingCharacters(in: .whitespacesAndNewlines))")
            )
        }
        return try EngineManifest.decode(from: data)
    }
}
