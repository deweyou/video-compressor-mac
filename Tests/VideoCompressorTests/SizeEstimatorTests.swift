import Foundation
@testable import VideoCompressor

#if canImport(XCTest)
import XCTest

final class SizeEstimatorTests: XCTestCase {
    private let estimator = SizeEstimator()

    func testEstimateDecreasesWhenQualityDrops() {
        let media = fixtureMedia(fps: 30)
        var settings = CompressionSettings.makeDefault(for: media, outputURL: URL(fileURLWithPath: "/tmp/out.mp4"))
        settings.qualityPercent = 80
        let high = estimator.estimateSize(mediaInfo: media, settings: settings)
        settings.qualityPercent = 40
        let low = estimator.estimateSize(mediaInfo: media, settings: settings)

        XCTAssertLessThan(low.estimatedBytes, high.estimatedBytes)
    }

    func testEstimateDecreasesWhenResolutionDrops() {
        let media = fixtureMedia(fps: 30)
        var settings = CompressionSettings.makeDefault(for: media, outputURL: URL(fileURLWithPath: "/tmp/out.mp4"))
        settings.outputWidth = 1920
        settings.outputHeight = 1080
        let full = estimator.estimateSize(mediaInfo: media, settings: settings)

        settings.outputWidth = 854
        settings.outputHeight = 480
        let reduced = estimator.estimateSize(mediaInfo: media, settings: settings)

        XCTAssertLessThan(reduced.estimatedBytes, full.estimatedBytes)
    }

    func testEstimateDecreasesWhenFpsDrops() {
        let media = fixtureMedia(fps: 60)
        var settings = CompressionSettings.makeDefault(for: media, outputURL: URL(fileURLWithPath: "/tmp/out.mp4"))
        settings.outputFPS = 60
        let full = estimator.estimateSize(mediaInfo: media, settings: settings)

        settings.outputFPS = 24
        let reduced = estimator.estimateSize(mediaInfo: media, settings: settings)

        XCTAssertLessThan(reduced.estimatedBytes, full.estimatedBytes)
    }

    private func fixtureMedia(fps: Double) -> MediaInfo {
        MediaInfo(
            url: URL(fileURLWithPath: "/tmp/input.mp4"),
            durationSec: 60,
            width: 1920,
            height: 1080,
            fps: fps,
            videoBitrateKbps: 4_000,
            audioBitrateKbps: 128,
            fileSizeBytes: 40_000_000
        )
    }
}

#elseif canImport(Testing)
import Testing

struct SizeEstimatorTests {
    private let estimator = SizeEstimator()

    @Test
    func estimateDecreasesWhenQualityDrops() {
        let media = fixtureMedia(fps: 30)
        var settings = CompressionSettings.makeDefault(for: media, outputURL: URL(fileURLWithPath: "/tmp/out.mp4"))
        settings.qualityPercent = 80
        let high = estimator.estimateSize(mediaInfo: media, settings: settings)
        settings.qualityPercent = 40
        let low = estimator.estimateSize(mediaInfo: media, settings: settings)

        #expect(low.estimatedBytes < high.estimatedBytes)
    }

    @Test
    func estimateDecreasesWhenResolutionDrops() {
        let media = fixtureMedia(fps: 30)
        var settings = CompressionSettings.makeDefault(for: media, outputURL: URL(fileURLWithPath: "/tmp/out.mp4"))
        settings.outputWidth = 1920
        settings.outputHeight = 1080
        let full = estimator.estimateSize(mediaInfo: media, settings: settings)

        settings.outputWidth = 854
        settings.outputHeight = 480
        let reduced = estimator.estimateSize(mediaInfo: media, settings: settings)

        #expect(reduced.estimatedBytes < full.estimatedBytes)
    }

    @Test
    func estimateDecreasesWhenFpsDrops() {
        let media = fixtureMedia(fps: 60)
        var settings = CompressionSettings.makeDefault(for: media, outputURL: URL(fileURLWithPath: "/tmp/out.mp4"))
        settings.outputFPS = 60
        let full = estimator.estimateSize(mediaInfo: media, settings: settings)

        settings.outputFPS = 24
        let reduced = estimator.estimateSize(mediaInfo: media, settings: settings)

        #expect(reduced.estimatedBytes < full.estimatedBytes)
    }

    private func fixtureMedia(fps: Double) -> MediaInfo {
        MediaInfo(
            url: URL(fileURLWithPath: "/tmp/input.mp4"),
            durationSec: 60,
            width: 1920,
            height: 1080,
            fps: fps,
            videoBitrateKbps: 4_000,
            audioBitrateKbps: 128,
            fileSizeBytes: 40_000_000
        )
    }
}
#endif
