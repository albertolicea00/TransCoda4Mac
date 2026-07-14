import Foundation

/// Hardware encoders exposed by the local FFmpeg build. On Apple silicon and
/// recent Intel Macs, VideoToolbox offloads H.264/HEVC encoding to the media
/// engine at a fraction of the CPU cost of software encoding.
struct HardwareCapabilities: Sendable {
    let encoderNames: Set<String>

    static let none = HardwareCapabilities(encoderNames: [])

    func encoder(for codec: VideoCodec) -> String? {
        let name: String
        switch codec {
        case .h264: name = "h264_videotoolbox"
        case .hevc: name = "hevc_videotoolbox"
        case .av1, .vp9: return nil // No VideoToolbox encode path in FFmpeg.
        }
        return encoderNames.contains(name) ? name : nil
    }

    static func detect(ffmpeg: URL) async -> HardwareCapabilities {
        guard let output = try? await ProcessRunner.run(ffmpeg, arguments: ["-hide_banner", "-encoders"]),
              output.exitCode == 0 else { return .none }

        // Each encoder line looks like " V....D h264_videotoolbox  VideoToolbox H.264 Encoder".
        let names = output.standardOutput
            .split(separator: "\n")
            .compactMap { line -> String? in
                let columns = line.split(separator: " ", omittingEmptySubsequences: true)
                guard columns.count >= 2 else { return nil }
                return String(columns[1])
            }
            .filter { $0.hasSuffix("_videotoolbox") }

        return HardwareCapabilities(encoderNames: Set(names))
    }
}
