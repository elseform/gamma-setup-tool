import Foundation
import CryptoKit

/// Downloads a resolved engine release into the archive cache, verifying it
/// against the manifest's `artifactSHA256` before it is trusted.
///
/// Runs inside `gamma-setup-engine`, so its stdout already is the NDJSON
/// stream `WineEngineSetup`'s reporter writes — progress goes through the same
/// `JSONEventReporter`, no separate channel.
public final class EngineArchiveDownloader {
    private let cacheDirectory: URL
    private let reporter: JSONEventReporter
    private let fileManager = FileManager.default

    public init(cacheDirectory: URL, reporter: JSONEventReporter) {
        self.cacheDirectory = cacheDirectory
        self.reporter = reporter
    }

    /// Cache hit is by checksum, never filename: a same-named file that
    /// doesn't hash to `expectedSHA256` is treated as absent and re-downloaded,
    /// because a size/name match can't catch a truncated or bit-rotted file.
    public func fetch(release: ResolvedEngineRelease, manifest: EngineManifest) async throws -> URL {
        try fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        let destination = cacheDirectory.appendingPathComponent(release.archiveName)
        guard let expectedSHA256 = manifest.artifactSHA256?.lowercased() else {
            throw WineEngineSetupError.message("release manifest for \(release.archiveName) has no artifactSHA256; refusing to trust an unverifiable download")
        }

        if fileManager.fileExists(atPath: destination.path),
           let existingHash = try? Self.sha256(of: destination), existingHash == expectedSHA256 {
            reporter.log("Using cached engine archive: \(destination.path)")
            return destination
        }

        reporter.log("Downloading engine archive: \(release.archiveName)")
        let downloadedTemp = try await download(url: release.archiveURL)
        let actualHash = try Self.sha256(of: downloadedTemp)
        guard actualHash == expectedSHA256 else {
            try? fileManager.removeItem(at: downloadedTemp)
            throw WineEngineSetupError.message(
                "downloaded \(release.archiveName) checksum mismatch (expected \(expectedSHA256), got \(actualHash)); not retrying automatically"
            )
        }

        // Atomic publish into the cache: download to a temp name, then move.
        if fileManager.fileExists(atPath: destination.path) {
            try? fileManager.removeItem(at: destination)
        }
        try fileManager.moveItem(at: downloadedTemp, to: destination)
        return destination
    }

    // MARK: - Download

    private func download(url: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let delegate = DownloadDelegate(reporter: reporter, continuation: continuation)
            // The session keeps its delegate alive until it is invalidated;
            // finishTasksAndInvalidate() releases both once the task is done.
            let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
            session.downloadTask(with: url).resume()
            session.finishTasksAndInvalidate()
        }
    }

    private final class DownloadDelegate: NSObject, URLSessionDownloadDelegate {
        let reporter: JSONEventReporter
        private var continuation: CheckedContinuation<URL, Error>?
        private var lastReportedPercent = -1
        private var lastReportedAt = Date.distantPast

        init(reporter: JSONEventReporter, continuation: CheckedContinuation<URL, Error>) {
            self.reporter = reporter
            self.continuation = continuation
        }

        /// Delegate callbacks arrive on the session's serial queue; this
        /// makes sure the continuation is resumed exactly once.
        private func resume(with result: Result<URL, Error>) {
            continuation?.resume(with: result)
            continuation = nil
        }

        func urlSession(
            _ session: URLSession,
            downloadTask: URLSessionDownloadTask,
            didFinishDownloadingTo location: URL
        ) {
            // A 404 or rate-limit page still "finishes downloading"; report
            // the HTTP status instead of a misleading checksum mismatch.
            if let http = downloadTask.response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                resume(with: .failure(WineEngineSetupError.message(
                    "could not download \(downloadTask.originalRequest?.url?.lastPathComponent ?? "engine archive"): HTTP \(http.statusCode)"
                )))
                return
            }
            // URLSession deletes the temp file as soon as this method returns,
            // so the move to a stable temp location must happen synchronously
            // here, not after hopping back to the caller.
            let stableTemp = FileManager.default.temporaryDirectory
                .appendingPathComponent("gamma-engine-download-\(UUID().uuidString).tmp")
            do {
                try FileManager.default.moveItem(at: location, to: stableTemp)
                resume(with: .success(stableTemp))
            } catch {
                resume(with: .failure(error))
            }
        }

        func urlSession(
            _ session: URLSession,
            downloadTask: URLSessionDownloadTask,
            didWriteData bytesWritten: Int64,
            totalBytesWritten: Int64,
            totalBytesExpectedToWrite: Int64
        ) {
            guard totalBytesExpectedToWrite > 0 else { return }
            let percent = Int((Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)) * 100)
            let now = Date()
            // Throttle to one event per whole percent or 500ms, whichever is
            // coarser, so a fast connection doesn't flood the event stream.
            guard percent != lastReportedPercent || now.timeIntervalSince(lastReportedAt) >= 0.5 else { return }
            lastReportedPercent = percent
            lastReportedAt = now
            reporter.log("Downloading engine archive… \(percent)%")
        }

        func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
            if let error {
                resume(with: .failure(error))
            } else {
                // Normally already resumed by didFinishDownloadingTo.
                resume(with: .failure(WineEngineSetupError.message("engine archive download ended without a file")))
            }
        }
    }

    // MARK: - Checksum

    /// Streams the file in 1 MiB chunks; a 130+ MB archive is never loaded
    /// into memory whole.
    static func sha256(of url: URL) throws -> String {
        guard let handle = FileHandle(forReadingAtPath: url.path) else {
            throw WineEngineSetupError.message("cannot open \(url.path) to checksum it")
        }
        defer { try? handle.close() }
        var hasher = CryptoKit.SHA256()
        while true {
            let chunk = handle.readData(ofLength: 1 << 20)
            if chunk.isEmpty { break }
            hasher.update(data: chunk)
        }
        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
