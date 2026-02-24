import Foundation

struct BinaryLocator {
    func ffmpegPath() -> String? {
        bundledPath(named: "ffmpeg")
    }

    func ffprobePath() -> String? {
        bundledPath(named: "ffprobe")
    }

    private func bundledPath(named name: String) -> String? {
        if let path = Bundle.module.path(forResource: name, ofType: nil), FileManager.default.isExecutableFile(atPath: path) {
            return path
        }
        return nil
    }
}
