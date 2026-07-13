import Foundation

enum OutputFormat: String, CaseIterable, Identifiable, Codable {
    case mp4, mkv, mov, webm
    case m4a, mp3, flac, opus, wav

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .m4a: "M4A (AAC)"
        default: rawValue.uppercased()
        }
    }

    var fileExtension: String { rawValue }

    var isAudioOnly: Bool {
        switch self {
        case .mp4, .mkv, .mov, .webm: false
        default: true
        }
    }

    var supportedVideoCodecs: [VideoCodec] {
        switch self {
        case .mp4: [.h264, .hevc, .av1]
        case .mkv: [.h264, .hevc, .av1, .vp9]
        case .mov: [.h264, .hevc]
        case .webm: [.vp9, .av1]
        default: []
        }
    }

    var supportedAudioCodecs: [AudioCodec] {
        switch self {
        case .mp4, .mov, .m4a: [.aac]
        case .mkv: [.aac, .opus, .mp3, .flac]
        case .webm, .opus: [.opus]
        case .mp3: [.mp3]
        case .flac: [.flac]
        case .wav: [.pcm]
        }
    }

    static let videoFormats: [OutputFormat] = [.mp4, .mkv, .mov, .webm]
    static let audioFormats: [OutputFormat] = [.m4a, .mp3, .flac, .opus, .wav]
}

enum VideoCodec: String, CaseIterable, Identifiable, Codable {
    case h264, hevc, av1, vp9

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .h264: "H.264 / AVC"
        case .hevc: "H.265 / HEVC"
        case .av1: "AV1"
        case .vp9: "VP9"
        }
    }
}

enum AudioCodec: String, CaseIterable, Identifiable, Codable {
    case aac, opus, mp3, flac, pcm

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .aac: "AAC"
        case .opus: "Opus"
        case .mp3: "MP3"
        case .flac: "FLAC"
        case .pcm: "PCM (uncompressed)"
        }
    }

    var supportsBitrate: Bool {
        switch self {
        case .aac, .opus, .mp3: true
        case .flac, .pcm: false
        }
    }
}
