import Foundation

struct BitrateEstimate {
    let targetVideoBitrateKbps: Int
    let estimatedFromFallback: Bool
}

struct SizeEstimator {
    func targetVideoBitrate(mediaInfo: MediaInfo, settings: CompressionSettings) -> BitrateEstimate {
        let srcPixels = max(1, mediaInfo.width * mediaInfo.height)
        let outPixels = max(1, settings.outputWidth * settings.outputHeight)
        let srcFPS = max(1.0, mediaInfo.fps)
        let outFPS = max(1.0, Double(settings.outputFPS))

        let qualityFactor = 0.25 + (Double(settings.qualityPercent) / 100.0) * 0.95
        let resolutionScale = Double(outPixels) / Double(srcPixels)
        let fpsScale = outFPS / srcFPS

        let srcBitrate = mediaInfo.videoBitrateKbps > 0 ? mediaInfo.videoBitrateKbps : fallbackVideoBitrate(mediaInfo: mediaInfo)
        let fallback = mediaInfo.videoBitrateKbps <= 0
        let target = max(300, Int(Double(srcBitrate) * resolutionScale * fpsScale * qualityFactor))
        return BitrateEstimate(targetVideoBitrateKbps: target, estimatedFromFallback: fallback)
    }

    func estimateSize(mediaInfo: MediaInfo, settings: CompressionSettings) -> SizeEstimate {
        let bitrate = targetVideoBitrate(mediaInfo: mediaInfo, settings: settings).targetVideoBitrateKbps
        let estimatedBits = mediaInfo.durationSec * Double(bitrate + settings.audioBitrateKbps) * 1000
        let estimatedBytes = Int64((estimatedBits / 8.0) * 1.02)
        let ratio = mediaInfo.fileSizeBytes > 0
            ? 1.0 - (Double(estimatedBytes) / Double(mediaInfo.fileSizeBytes))
            : 0
        return SizeEstimate(
            estimatedBytes: max(0, estimatedBytes),
            estimatedCompressionRatio: min(max(ratio, -9.99), 0.99)
        )
    }

    private func fallbackVideoBitrate(mediaInfo: MediaInfo) -> Int {
        guard mediaInfo.durationSec > 0 else {
            return 2_000
        }
        let totalKbps = Double(mediaInfo.fileSizeBytes) * 8.0 / mediaInfo.durationSec / 1000.0
        let audio = Double(mediaInfo.audioBitrateKbps ?? 128)
        return max(500, Int(totalKbps - audio))
    }
}
