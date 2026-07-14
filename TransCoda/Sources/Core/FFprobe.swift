import Foundation

enum FFprobe {
    /// Returns the media duration in seconds, or nil when it cannot be
    /// determined. A missing duration only degrades progress reporting;
    /// the conversion itself still runs.
    static func duration(of url: URL, ffprobe: URL) async -> Double? {
        let arguments = [
            "-v", "error",
            "-show_entries", "format=duration",
            "-of", "default=noprint_wrappers=1:nokey=1",
            url.path,
        ]
        guard let output = try? await ProcessRunner.run(ffprobe, arguments: arguments),
              output.exitCode == 0 else { return nil }
        return Double(output.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
