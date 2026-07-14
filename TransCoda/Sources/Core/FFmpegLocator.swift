import Foundation

enum FFmpegLocator {
    struct Installation {
        let ffmpeg: URL
        let ffprobe: URL?
    }

    static func locate() -> Installation? {
        guard let ffmpeg = find("ffmpeg") else { return nil }
        return Installation(ffmpeg: ffmpeg, ffprobe: find("ffprobe"))
    }

    static func find(_ tool: String) -> URL? {
        // 1. Binary bundled inside the app (Contents/MacOS).
        if let bundled = Bundle.main.url(forAuxiliaryExecutable: tool),
           FileManager.default.isExecutableFile(atPath: bundled.path) {
            return bundled
        }

        // 2. Well-known install locations (Homebrew on Apple silicon and
        //    Intel, MacPorts, system).
        let knownPaths = [
            "/opt/homebrew/bin/\(tool)",
            "/usr/local/bin/\(tool)",
            "/opt/local/bin/\(tool)",
            "/usr/bin/\(tool)",
        ]
        for path in knownPaths where FileManager.default.isExecutableFile(atPath: path) {
            return URL(fileURLWithPath: path)
        }

        // 3. Anything on PATH. GUI apps get a minimal PATH, so this is a
        //    last resort rather than the primary mechanism.
        let searchPath = ProcessInfo.processInfo.environment["PATH"] ?? ""
        for directory in searchPath.split(separator: ":") {
            let candidate = "\(directory)/\(tool)"
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return URL(fileURLWithPath: candidate)
            }
        }

        return nil
    }
}
