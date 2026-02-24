import Foundation

struct CompressionSettings: Equatable {
    var preset: CompressionPreset
    var outputWidth: Int
    var outputHeight: Int
    var outputFPS: Int
    var qualityPercent: Int
    var audioBitrateKbps: Int
    var audioSampleRate: Int
    var audioChannels: Int
    var outputURL: URL

    static func makeDefault(for mediaInfo: MediaInfo, outputURL: URL, preset: CompressionPreset = .medium) -> CompressionSettings {
        var settings = CompressionSettings(
            preset: preset,
            outputWidth: mediaInfo.width,
            outputHeight: mediaInfo.height,
            outputFPS: min(Int(mediaInfo.fps.rounded()), 30),
            qualityPercent: 60,
            audioBitrateKbps: 128,
            audioSampleRate: 44_100,
            audioChannels: 2,
            outputURL: outputURL
        )
        settings.applyPreset(preset, mediaInfo: mediaInfo)
        return settings
    }

    mutating func applyPreset(_ preset: CompressionPreset, mediaInfo: MediaInfo) {
        self.preset = preset
        switch preset {
        case .high:
            qualityPercent = 80
            outputFPS = min(max(1, Int(mediaInfo.fps.rounded())), 30)
            outputWidth = mediaInfo.width
            outputHeight = mediaInfo.height
            audioBitrateKbps = 160
            audioSampleRate = 48_000
            audioChannels = 2
        case .medium:
            qualityPercent = 60
            outputFPS = min(max(1, Int(mediaInfo.fps.rounded())), 30)
            let size = Self.scaledEvenSize(
                sourceWidth: mediaInfo.width,
                sourceHeight: mediaInfo.height,
                targetLongSide: 1280
            )
            outputWidth = size.width
            outputHeight = size.height
            audioBitrateKbps = 128
            audioSampleRate = 44_100
            audioChannels = 2
        case .small:
            qualityPercent = 40
            outputFPS = min(max(1, Int(mediaInfo.fps.rounded())), 24)
            let size = Self.scaledEvenSize(
                sourceWidth: mediaInfo.width,
                sourceHeight: mediaInfo.height,
                targetLongSide: 854
            )
            outputWidth = size.width
            outputHeight = size.height
            audioBitrateKbps = 96
            audioSampleRate = 44_100
            audioChannels = 2
        }
    }

    static func scaledEvenSize(sourceWidth: Int, sourceHeight: Int, targetLongSide: Int) -> (width: Int, height: Int) {
        guard sourceWidth > 0, sourceHeight > 0 else {
            return (2, 2)
        }
        let longSide = max(sourceWidth, sourceHeight)
        guard longSide > targetLongSide else {
            return (
                width: max(2, sourceWidth - sourceWidth % 2),
                height: max(2, sourceHeight - sourceHeight % 2)
            )
        }
        let scale = Double(targetLongSide) / Double(longSide)
        let width = max(2, Int((Double(sourceWidth) * scale).rounded()) / 2 * 2)
        let height = max(2, Int((Double(sourceHeight) * scale).rounded()) / 2 * 2)
        return (width, height)
    }
}
