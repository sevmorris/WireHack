import Foundation

enum DownloadFormat: String, CaseIterable, Identifiable {
    case nativeAudio = "Audio"
    case nativeVideo = "Video"

    var id: String { rawValue }

    var ytDlpFormatArg: String {
        switch self {
        // Prefer native audio-only streams; fall back to best combined format.
        case .nativeAudio: return "ba/b"
        case .nativeVideo: return "best"
        }
    }
}

enum YTDLPError: LocalizedError {
    case notFound(searched: [String])
    case ffmpegNotFound(searched: [String])
    case executionFailed(String)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .notFound(let paths):
            return "yt-dlp not found. Looked in: \(paths.joined(separator: ", ")). Install with: brew install yt-dlp"
        case .ffmpegNotFound(let paths):
            return "ffmpeg not found. Looked in: \(paths.joined(separator: ", ")). Install with: brew install ffmpeg"
        case .executionFailed(let message):
            return "Download failed: \(message)"
        case .cancelled:
            return "Download cancelled"
        }
    }
}

final class YTDLPService {
    static let shared = YTDLPService()

    // Searched in order. Covers Apple Silicon Homebrew, Intel Homebrew, MacPorts,
    // pipx user installs, and the system path.
    private static let candidatePaths: [String] = [
        "/opt/homebrew/bin/yt-dlp",
        "/usr/local/bin/yt-dlp",
        "/opt/local/bin/yt-dlp",
        (NSString(string: "~/.local/bin/yt-dlp") as NSString).expandingTildeInPath,
        "/usr/bin/yt-dlp"
    ]

    private static let ffmpegCandidatePaths: [String] = [
        "/opt/homebrew/bin/ffmpeg",
        "/usr/local/bin/ffmpeg",
        "/opt/local/bin/ffmpeg",
        (NSString(string: "~/.local/bin/ffmpeg") as NSString).expandingTildeInPath,
        "/usr/bin/ffmpeg"
    ]

    private func resolveBinary(in candidates: [String]) throws -> String {
        let fm = FileManager.default
        for path in candidates where fm.isExecutableFile(atPath: path) {
            return path
        }
        throw YTDLPError.notFound(searched: candidates)
    }

    private func resolveBinary() throws -> String {
        try resolveBinary(in: Self.candidatePaths)
    }

    private func resolveFFmpeg() throws -> String {
        let fm = FileManager.default
        for path in Self.ffmpegCandidatePaths where fm.isExecutableFile(atPath: path) {
            return path
        }
        throw YTDLPError.ffmpegNotFound(searched: Self.ffmpegCandidatePaths)
    }

    /// Builds the yt-dlp argument list. Kept separate so flags stay easy to audit.
    static func buildArguments(
        url: String,
        format: DownloadFormat,
        destination: String,
        outputTemplate: String
    ) -> [String] {
        var args = [
            "-f", format.ytDlpFormatArg,
            "-P", destination,
            "-o", outputTemplate,
            "--print", "after_move:\(filepathMarker)%(filepath)s",
            "--no-playlist",
            "--newline",
            "--restrict-filenames",
            "--retries", "10",
            "--fragment-retries", "10",
            "-N", "4",
            "--remote-components", "ejs",
        ]

        args.append(url)
        return args
    }

    /// Streams yt-dlp output line-by-line via `onProgress`. Cancels by terminating
    /// the child process when the surrounding `Task` is cancelled.
    /// Marker prefix used with yt-dlp's `--print` so we can pluck the resolved
    /// filepath out of stdout without exposing it to the progress callback.
    private static let filepathMarker = "WIREHACK_OUT|"

    /// Returns the absolute path of the downloaded file, or `nil` if yt-dlp
    /// didn't emit a filepath (e.g. an already-downloaded file that skipped
    /// the move step).
    func downloadMedia(
        url: String,
        format: DownloadFormat,
        downloadFolder: String? = nil,
        outputTemplate: String = "%(title)s.%(ext)s",
        onProgress: @escaping @Sendable (String) -> Void
    ) async throws -> String? {
        let binary = try resolveBinary()
        if format == .nativeVideo {
            _ = try resolveFFmpeg()
        }

        let destination = downloadFolder
            ?? FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first?.path
            ?? NSTemporaryDirectory()

        let marker = Self.filepathMarker
        let process = Process()
        process.executableURL = URL(fileURLWithPath: binary)
        process.arguments = Self.buildArguments(
            url: url,
            format: format,
            destination: destination,
            outputTemplate: outputTemplate
        )

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        // Tail recent stderr for the failure message — yt-dlp's actionable error
        // is usually within the last few hundred bytes.
        let stderrTail = StderrTail()
        let filepathCapture = FilepathCapture()

        let stdoutHandle = stdoutPipe.fileHandleForReading
        let stderrHandle = stderrPipe.fileHandleForReading

        // Drain both pipes concurrently. Reading only one to EOF before the
        // other deadlocks the child once its sibling pipe buffer fills.
        stdoutHandle.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            forEachLine(in: data) { line in
                if line.hasPrefix(marker) {
                    filepathCapture.set(String(line.dropFirst(marker.count)))
                } else {
                    onProgress(line)
                }
            }
        }
        stderrHandle.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            stderrTail.append(data)
            forEachLine(in: data) { onProgress($0) }
        }

        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                process.terminationHandler = { proc in
                    stdoutHandle.readabilityHandler = nil
                    stderrHandle.readabilityHandler = nil
                    if proc.terminationReason == .uncaughtSignal {
                        cont.resume(throwing: YTDLPError.cancelled)
                    } else if proc.terminationStatus == 0 {
                        cont.resume(returning: ())
                    } else {
                        let tail = stderrTail.snapshot().trimmingCharacters(in: .whitespacesAndNewlines)
                        let msg = tail.isEmpty
                            ? "yt-dlp exited with code \(proc.terminationStatus)"
                            : tail
                        cont.resume(throwing: YTDLPError.executionFailed(msg))
                    }
                }

                do {
                    try process.run()
                } catch {
                    stdoutHandle.readabilityHandler = nil
                    stderrHandle.readabilityHandler = nil
                    cont.resume(throwing: error)
                }
            }
        } onCancel: {
            if process.isRunning { process.terminate() }
        }

        return filepathCapture.get()
    }
}

private func forEachLine(in data: Data, _ body: (String) -> Void) {
    guard let chunk = String(data: data, encoding: .utf8) else { return }
    // yt-dlp progress can use either \n (with --newline) or \r. Split on both.
    for raw in chunk.split(whereSeparator: { $0 == "\n" || $0 == "\r" }) {
        let line = String(raw).trimmingCharacters(in: .whitespaces)
        if !line.isEmpty { body(line) }
    }
}

private final class FilepathCapture: @unchecked Sendable {
    private let lock = NSLock()
    private var path: String?

    func set(_ value: String) {
        lock.lock(); defer { lock.unlock() }
        path = value
    }

    func get() -> String? {
        lock.lock(); defer { lock.unlock() }
        return path
    }
}

private final class StderrTail: @unchecked Sendable {
    private let lock = NSLock()
    private var buffer = Data()
    private let cap = 8 * 1024

    func append(_ data: Data) {
        lock.lock(); defer { lock.unlock() }
        buffer.append(data)
        if buffer.count > cap {
            buffer.removeFirst(buffer.count - cap)
        }
    }

    func snapshot() -> String {
        lock.lock(); defer { lock.unlock() }
        return String(data: buffer, encoding: .utf8) ?? ""
    }
}
