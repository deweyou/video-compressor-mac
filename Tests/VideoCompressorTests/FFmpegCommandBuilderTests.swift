import Foundation
@testable import VideoCompressor

#if canImport(XCTest)
import XCTest

final class FFmpegCommandBuilderTests: XCTestCase {
    func testBuildContainsExpectedArguments() {
        let builder = FFmpegCommandBuilder()
        let media = MediaInfo(
            url: URL(fileURLWithPath: "/tmp/in file.mp4"),
            durationSec: 120,
            width: 1920,
            height: 1080,
            fps: 30,
            videoBitrateKbps: 4_000,
            audioBitrateKbps: 128,
            fileSizeBytes: 100_000_000
        )
        let settings = CompressionSettings(
            preset: .medium,
            outputWidth: 1280,
            outputHeight: 720,
            outputFPS: 30,
            qualityPercent: 60,
            audioBitrateKbps: 128,
            audioSampleRate: 44_100,
            audioChannels: 2,
            outputURL: URL(fileURLWithPath: "/tmp/out file.mp4")
        )

        let command = builder.build(ffmpegPath: "/usr/local/bin/ffmpeg", mediaInfo: media, settings: settings)

        XCTAssertEqual(command.launchPath, "/usr/local/bin/ffmpeg")
        if let vfIndex = command.arguments.firstIndex(of: "-vf"), vfIndex + 1 < command.arguments.count {
            XCTAssertTrue(command.arguments[vfIndex + 1].contains("trunc(iw/2)*2:trunc(ih/2)*2"))
        } else {
            XCTFail("Missing -vf filter argument")
        }
        XCTAssertTrue(command.arguments.contains("-progress"))
        XCTAssertTrue(command.arguments.contains("pipe:1"))
        XCTAssertTrue(command.arguments.contains("-map_metadata"))
        XCTAssertTrue(command.arguments.contains("0"))
        XCTAssertTrue(command.arguments.contains("/tmp/in file.mp4"))
        XCTAssertTrue(command.arguments.contains("/tmp/out file.mp4"))
        XCTAssertTrue(command.arguments.contains("h264_videotoolbox"))
        XCTAssertTrue(command.arguments.contains("aac"))
    }
}

#elseif canImport(Testing)
import Testing

struct FFmpegCommandBuilderTests {
    @Test
    func buildContainsExpectedArguments() {
        let builder = FFmpegCommandBuilder()
        let media = MediaInfo(
            url: URL(fileURLWithPath: "/tmp/in file.mp4"),
            durationSec: 120,
            width: 1920,
            height: 1080,
            fps: 30,
            videoBitrateKbps: 4_000,
            audioBitrateKbps: 128,
            fileSizeBytes: 100_000_000
        )
        let settings = CompressionSettings(
            preset: .medium,
            outputWidth: 1280,
            outputHeight: 720,
            outputFPS: 30,
            qualityPercent: 60,
            audioBitrateKbps: 128,
            audioSampleRate: 44_100,
            audioChannels: 2,
            outputURL: URL(fileURLWithPath: "/tmp/out file.mp4")
        )

        let command = builder.build(ffmpegPath: "/usr/local/bin/ffmpeg", mediaInfo: media, settings: settings)

        #expect(command.launchPath == "/usr/local/bin/ffmpeg")
        #expect(command.arguments.contains("-progress"))
        #expect(command.arguments.contains("pipe:1"))
        #expect(command.arguments.contains("-map_metadata"))
        #expect(command.arguments.contains("0"))
        #expect(command.arguments.contains("/tmp/in file.mp4"))
        #expect(command.arguments.contains("/tmp/out file.mp4"))
        #expect(command.arguments.contains("h264_videotoolbox"))
        #expect(command.arguments.contains("aac"))
    }
}
#endif
