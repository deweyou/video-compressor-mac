import Foundation

struct FileNameResolver {
    func uniqueOutputURL(directory: URL, baseName: String, ext: String = "mp4") -> URL {
        var candidate = directory.appendingPathComponent("\(baseName).\(ext)")
        var index = 1
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = directory.appendingPathComponent("\(baseName)-\(index).\(ext)")
            index += 1
        }
        return candidate
    }
}
