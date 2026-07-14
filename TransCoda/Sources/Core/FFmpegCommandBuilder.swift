import Foundation

/// Turns conversion settings into an FFmpeg argument list. Arguments are
/// always passed as a list to Process — no shell is ever involved, so paths
/// need no quoting or escaping.
struct FFmpegCommandBuilder {
    let inputURL: URL
    let outputURL: URL
    let settings: ConversionSettings
    let hardware: HardwareCapabilities

    func arguments() -> [String] {
        var args: [String] = ["-hide_banner", "-loglevel", "error", "-y", "-i", inputURL.path]

        if settings.format.isAudioOnly {
            args += ["-vn"]
        } else {
            args += videoArguments()
        }
        args += audioArguments()
        args += containerArguments()
        args += ["-progress", "pipe:1", "-nostats", outputURL.path]
        return args
    }

    // MARK: - Video

    private func videoArguments() -> [String] {
        var args: [String] = []
        let quality = String(settings.quality)
        let hardwareEncoder = settings.useHardwareAcceleration ? hardware.encoder(for: settings.videoCodec) : nil

        if let hardwareEncoder {
            args += ["-c:v", hardwareEncoder]
            // VideoToolbox has no CRF mode; it rates quality 1–100 with
            // higher meaning better, so map from the CRF-style value.
            let mapped = max(1, min(100, 100 - settings.quality * 2))
            args += ["-q:v", String(mapped)]
        } else {
            switch settings.videoCodec {
            case .h264:
                args += ["-c:v", "libx264", "-preset", "medium", "-crf", quality]
            case .hevc:
                args += ["-c:v", "libx265", "-preset", "medium", "-crf", quality]
            case .av1:
                args += ["-c:v", "libsvtav1", "-preset", "8", "-crf", quality]
            case .vp9:
                args += ["-c:v", "libvpx-vp9", "-b:v", "0", "-crf", quality, "-row-mt", "1"]
            }
        }

        if let maxHeight = settings.maxHeight {
            // -2 keeps the width even, which most encoders require; min()
            // avoids upscaling sources smaller than the limit.
            args += ["-vf", "scale=-2:min(ih\\,\(maxHeight))"]
        }

        if settings.videoCodec == .hevc, settings.format == .mp4 || settings.format == .mov {
            // hvc1 tag so QuickTime and Apple devices recognize the track.
            args += ["-tag:v", "hvc1"]
        }

        return args
    }

    // MARK: - Audio

    private func audioArguments() -> [String] {
        var args: [String]
        switch settings.audioCodec {
        case .aac: args = ["-c:a", "aac"]
        case .opus: args = ["-c:a", "libopus"]
        case .mp3: args = ["-c:a", "libmp3lame"]
        case .flac: args = ["-c:a", "flac"]
        case .pcm: args = ["-c:a", "pcm_s16le"]
        }
        if settings.audioCodec.supportsBitrate {
            args += ["-b:a", "\(settings.audioBitrateKbps)k"]
        }
        return args
    }

    // MARK: - Container

    private func containerArguments() -> [String] {
        switch settings.format {
        case .mp4, .mov, .m4a:
            // Move the moov atom up front so files start playing immediately
            // when streamed.
            return ["-movflags", "+faststart"]
        default:
            return []
        }
    }
}
