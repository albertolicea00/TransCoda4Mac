import Foundation

enum TranscodeError: LocalizedError {
    case cancelled
    case ffmpegFailed(exitCode: Int32, log: String)

    var errorDescription: String? {
        switch self {
        case .cancelled:
            return "The conversion was cancelled."
        case .ffmpegFailed(let exitCode, let log):
            let detail = log.trimmingCharacters(in: .whitespacesAndNewlines)
            return detail.isEmpty ? "FFmpeg exited with code \(exitCode)." : detail
        }
    }
}

/// Runs a single FFmpeg conversion and reports progress parsed from FFmpeg's
/// machine-readable `-progress` stream on stdout.
final class TranscodeEngine: @unchecked Sendable {
    private let lock = NSLock()
    private var process: Process?
    private var cancelled = false

    func cancel() {
        lock.lock()
        cancelled = true
        let running = process
        lock.unlock()
        running?.terminate()
    }

    func run(
        ffmpeg: URL,
        arguments: [String],
        durationSeconds: Double?,
        onProgress: @escaping @Sendable (Double) -> Void
    ) async throws {
        let process = Process()
        process.executableURL = ffmpeg
        process.arguments = arguments
        process.standardInput = FileHandle.nullDevice

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        // The stream buffers the exit code even if the process finishes
        // before we start awaiting it, so there is no termination race.
        let exitCodes = AsyncStream<Int32> { continuation in
            process.terminationHandler = { finished in
                continuation.yield(finished.terminationStatus)
                continuation.finish()
            }
        }

        lock.lock()
        if cancelled {
            lock.unlock()
            throw TranscodeError.cancelled
        }
        self.process = process
        lock.unlock()

        try process.run()

        // Drain stderr concurrently so a chatty FFmpeg cannot fill the pipe
        // buffer and stall; only the tail is kept for error reporting.
        let errorTail = Task.detached {
            let data = stderr.fileHandleForReading.readDataToEndOfFile()
            let text = String(data: data, encoding: .utf8) ?? ""
            return String(text.suffix(4000))
        }

        for try await line in stdout.fileHandleForReading.bytes.lines {
            if let seconds = Self.outTimeSeconds(fromProgressLine: line),
               let durationSeconds, durationSeconds > 0 {
                onProgress(min(seconds / durationSeconds, 0.999))
            }
        }

        var exitCode: Int32 = -1
        for await code in exitCodes { exitCode = code }
        let log = await errorTail.value

        lock.lock()
        let wasCancelled = cancelled
        self.process = nil
        lock.unlock()

        if wasCancelled {
            throw TranscodeError.cancelled
        }
        guard exitCode == 0 else {
            throw TranscodeError.ffmpegFailed(exitCode: exitCode, log: log)
        }
        onProgress(1)
    }

    /// FFmpeg emits `out_time_us=…` on its progress stream, and historically
    /// `out_time_ms=…` — which, despite the name, is also microseconds.
    static func outTimeSeconds(fromProgressLine line: String) -> Double? {
        for key in ["out_time_us=", "out_time_ms="] where line.hasPrefix(key) {
            guard let microseconds = Double(line.dropFirst(key.count)), microseconds >= 0 else {
                return nil
            }
            return microseconds / 1_000_000
        }
        return nil
    }
}
