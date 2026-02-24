import Foundation
@testable import VideoCompressor

#if canImport(XCTest)
import XCTest

final class FileNameResolverTests: XCTestCase {
    func testGeneratesIncrementalSuffixWhenFileExists() throws {
        let resolver = FileNameResolver()
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let first = tempDir.appendingPathComponent("video_compressed.mp4")
        _ = FileManager.default.createFile(atPath: first.path, contents: Data())

        let second = tempDir.appendingPathComponent("video_compressed-1.mp4")
        _ = FileManager.default.createFile(atPath: second.path, contents: Data())

        let resolved = resolver.uniqueOutputURL(directory: tempDir, baseName: "video_compressed", ext: "mp4")
        XCTAssertEqual(resolved.lastPathComponent, "video_compressed-2.mp4")
    }
}

#elseif canImport(Testing)
import Testing

struct FileNameResolverTests {
    @Test
    func generatesIncrementalSuffixWhenFileExists() throws {
        let resolver = FileNameResolver()
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let first = tempDir.appendingPathComponent("video_compressed.mp4")
        _ = FileManager.default.createFile(atPath: first.path, contents: Data())

        let second = tempDir.appendingPathComponent("video_compressed-1.mp4")
        _ = FileManager.default.createFile(atPath: second.path, contents: Data())

        let resolved = resolver.uniqueOutputURL(directory: tempDir, baseName: "video_compressed", ext: "mp4")
        #expect(resolved.lastPathComponent == "video_compressed-2.mp4")
    }
}
#endif
