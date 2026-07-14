import Foundation

/// Ordered conversion queue. Jobs run one at a time — a single FFmpeg encode
/// already saturates the media engine or CPU, and serial processing keeps
/// memory usage flat regardless of queue size.
@MainActor
final class JobQueue: ObservableObject {
    @Published private(set) var jobs: [ConversionJob] = []
    @Published var settings = ConversionSettings()

    /// Destination folder; nil saves next to each source file.
    @Published var outputDirectory: URL?

    @Published private(set) var isProcessing = false
    @Published private(set) var installation: FFmpegLocator.Installation?
    @Published private(set) var hardware: HardwareCapabilities = .none
    @Published private(set) var bootstrapped = false

    private var activeEngine: TranscodeEngine?

    static let supportedExtensions: Set<String> = [
        "mp4", "m4v", "mkv", "webm", "mov", "avi", "wmv", "flv",
        "ts", "mts", "m2ts", "3gp", "mpg", "mpeg", "ogv",
        "mp3", "m4a", "aac", "flac", "wav", "ogg", "oga", "opus", "wma", "aiff",
    ]

    init() {
        Task { await bootstrap() }
    }

    private func bootstrap() async {
        let found = FFmpegLocator.locate()
        installation = found
        if let found {
            hardware = await HardwareCapabilities.detect(ffmpeg: found.ffmpeg)
        }
        bootstrapped = true
    }

    var ffmpegMissing: Bool { bootstrapped && installation == nil }

    // MARK: - Queue management

    func add(urls: [URL]) {
        let pending = Set(jobs.filter { !$0.isFinished }.map(\.sourceURL))
        let newJobs = urls
            .filter { Self.supportedExtensions.contains($0.pathExtension.lowercased()) }
            .filter { !pending.contains($0) }
            .map { ConversionJob(sourceURL: $0, settings: settings) }
        jobs.append(contentsOf: newJobs)
    }

    func remove(_ job: ConversionJob) {
        cancel(job)
        jobs.removeAll { $0.id == job.id }
    }

    func clearFinished() {
        jobs.removeAll(where: \.isFinished)
    }

    func cancel(_ job: ConversionJob) {
        switch job.status {
        case .waiting:
            job.status = .cancelled
        case .probing, .running:
            activeEngine?.cancel()
        case .completed, .failed, .cancelled:
            break
        }
    }

    // MARK: - Processing

    func start() {
        guard !isProcessing, installation != nil else { return }
        isProcessing = true
        Task {
            while let next = jobs.first(where: { $0.status == .waiting }) {
                await process(next)
            }
            isProcessing = false
        }
    }

    private func process(_ job: ConversionJob) async {
        guard let installation else {
            job.status = .failed("FFmpeg is not installed.")
            return
        }

        // Settings are captured when the job starts, so tweaks made while
        // earlier jobs run still apply to the rest of the queue.
        job.settings = settings.normalized()
        job.status = .probing

        if let ffprobe = installation.ffprobe {
            job.durationSeconds = await FFprobe.duration(of: job.sourceURL, ffprobe: ffprobe)
        }

        let outputURL = availableOutputURL(for: job)
        job.outputURL = outputURL

        let builder = FFmpegCommandBuilder(
            inputURL: job.sourceURL,
            outputURL: outputURL,
            settings: job.settings,
            hardware: hardware
        )

        let engine = TranscodeEngine()
        activeEngine = engine
        job.status = .running

        do {
            try await engine.run(
                ffmpeg: installation.ffmpeg,
                arguments: builder.arguments(),
                durationSeconds: job.durationSeconds
            ) { progress in
                Task { @MainActor [weak job] in job?.progress = progress }
            }
            job.progress = 1
            job.status = .completed
        } catch TranscodeError.cancelled {
            job.status = .cancelled
            try? FileManager.default.removeItem(at: outputURL)
        } catch {
            job.status = .failed(error.localizedDescription)
            try? FileManager.default.removeItem(at: outputURL)
        }

        activeEngine = nil
    }

    private func availableOutputURL(for job: ConversionJob) -> URL {
        let directory = outputDirectory ?? job.sourceURL.deletingLastPathComponent()
        let baseName = job.sourceURL.deletingPathExtension().lastPathComponent
        let ext = job.settings.format.fileExtension

        var candidate = directory.appendingPathComponent("\(baseName).\(ext)")
        var suffix = 1
        while FileManager.default.fileExists(atPath: candidate.path) {
            suffix += 1
            candidate = directory.appendingPathComponent("\(baseName) \(suffix).\(ext)")
        }
        return candidate
    }
}
