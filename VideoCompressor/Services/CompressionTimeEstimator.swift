import Foundation

struct CompressionTimeEstimator {
    private let speedKey = "video_compressor_average_speed"

    func estimateDurationSec(mediaInfo: MediaInfo, settings: CompressionSettings) -> Double {
        guard mediaInfo.durationSec > 0 else {
            return 0
        }

        let baselineSpeed = storedAverageSpeed() ?? 1.25
        let srcPixels = max(1, mediaInfo.width * mediaInfo.height)
        let outPixels = max(1, settings.outputWidth * settings.outputHeight)
        let srcFPS = max(1.0, mediaInfo.fps)

        let resolutionFactor = sqrt(Double(outPixels) / Double(srcPixels))
        let fpsFactor = Double(settings.outputFPS) / srcFPS
        let qualityFactor = 0.7 + Double(settings.qualityPercent) / 100.0 * 0.8
        let audioFactor = 1.0 + (Double(settings.audioBitrateKbps) / 256.0) * 0.1
        let complexity = max(0.35, min(2.5, resolutionFactor * fpsFactor * qualityFactor * audioFactor))

        let predictedSpeed = max(0.15, baselineSpeed / complexity)
        return mediaInfo.durationSec / predictedSpeed
    }

    func recordCompression(mediaDurationSec: Double, elapsedSec: Double) {
        guard mediaDurationSec > 0, elapsedSec > 0 else {
            return
        }
        let measuredSpeed = mediaDurationSec / elapsedSec
        let current = storedAverageSpeed() ?? measuredSpeed
        let smoothed = current * 0.7 + measuredSpeed * 0.3
        UserDefaults.standard.set(smoothed, forKey: speedKey)
    }

    private func storedAverageSpeed() -> Double? {
        let value = UserDefaults.standard.double(forKey: speedKey)
        return value > 0 ? value : nil
    }
}
