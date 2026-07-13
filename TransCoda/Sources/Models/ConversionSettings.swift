import Foundation

struct ConversionSettings: Codable, Equatable {
    var format: OutputFormat = .mp4
    var videoCodec: VideoCodec = .h264
    var audioCodec: AudioCodec = .aac

    /// CRF-style quality: lower is better. Sensible range is 18–30.
    var quality: Int = 23

    var audioBitrateKbps: Int = 192

    /// Maximum output height in pixels; nil keeps the source resolution.
    var maxHeight: Int?

    var useHardwareAcceleration = true

    /// Clamps codec choices to what the selected container supports.
    func normalized() -> ConversionSettings {
        var copy = self
        if !format.isAudioOnly, !format.supportedVideoCodecs.contains(copy.videoCodec) {
            copy.videoCodec = format.supportedVideoCodecs.first ?? .h264
        }
        if !format.supportedAudioCodecs.contains(copy.audioCodec) {
            copy.audioCodec = format.supportedAudioCodecs.first ?? .aac
        }
        copy.quality = min(max(copy.quality, 0), 51)
        return copy
    }
}
