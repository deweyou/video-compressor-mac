import Foundation

private struct FFProbePayload: Decodable {
    struct Stream: Decodable {
        let codecType: String?
        let width: Int?
        let height: Int?
        let bitRate: String?
        let avgFrameRate: String?
        let rFrameRate: String?

        enum CodingKeys: String, CodingKey {
            case codecType = "codec_type"
            case width
            case height
            case bitRate = "bit_rate"
            case avgFrameRate = "avg_frame_rate"
            case rFrameRate = "r_frame_rate"
        }
    }

    struct Format: Decodable {
        let duration: String?
        let bitRate: String?

        enum CodingKeys: String, CodingKey {
            case duration
            case bitRate = "bit_rate"
        }
    }

    let streams: [Stream]?
    let format: Format?
}

struct MediaProbeService {
    private let binaryLocator = BinaryLocator()

    func probe(url: URL) async throws -> MediaInfo {
        guard let ffprobe = binaryLocator.ffprobePath() else {
            throw CompressionError.missingEncoder(L10n.tr("error_missing_ffprobe_hint"))
        }
        let args = [
            "-v", "error",
            "-print_format", "json",
            "-show_format",
            "-show_streams",
            url.path
        ]

        let output = try await runProcess(launchPath: ffprobe, arguments: args)
        let data = Data(output.utf8)
        let payload: FFProbePayload
        do {
            payload = try JSONDecoder().decode(FFProbePayload.self, from: data)
        } catch {
            throw CompressionError.unsupportedMedia("ffprobe json parse failed: \(error.localizedDescription)")
        }

        let streams = payload.streams ?? []
        guard let video = streams.first(where: { $0.codecType == "video" }) else {
            throw CompressionError.unsupportedMedia(L10n.tr("error_no_video_stream"))
        }

        let audio = streams.first(where: { $0.codecType == "audio" })
        let duration = Double(payload.format?.duration ?? "") ?? 0
        guard duration > 0 else {
            throw CompressionError.unsupportedMedia(L10n.tr("error_invalid_duration"))
        }

        let width = video.width ?? 0
        let height = video.height ?? 0
        guard width > 0, height > 0 else {
            throw CompressionError.unsupportedMedia(L10n.tr("error_invalid_resolution"))
        }

        let fps = parseFPS(video.avgFrameRate) ?? parseFPS(video.rFrameRate) ?? 30
        let formatBitrate = Int((payload.format?.bitRate ?? "") ) ?? 0
        let videoBitrate = Int(video.bitRate ?? "") ?? max(0, formatBitrate - (Int(audio?.bitRate ?? "") ?? 0))
        let audioBitrate = Int(audio?.bitRate ?? "")

        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        let fileSize = (attrs?[.size] as? NSNumber)?.int64Value ?? 0

        return MediaInfo(
            url: url,
            durationSec: duration,
            width: width,
            height: height,
            fps: fps,
            videoBitrateKbps: max(0, videoBitrate / 1000),
            audioBitrateKbps: audioBitrate.map { max(1, $0 / 1000) },
            fileSizeBytes: fileSize
        )
    }

    private func parseFPS(_ value: String?) -> Double? {
        guard let value else { return nil }
        let parts = value.split(separator: "/")
        guard parts.count == 2,
              let num = Double(parts[0]),
              let den = Double(parts[1]),
              den != 0 else {
            return Double(value)
        }
        let fps = num / den
        return fps.isFinite && fps > 0 ? fps : nil
    }

    private func runProcess(launchPath: String, arguments: [String]) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: launchPath)
            process.arguments = arguments

            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            process.terminationHandler = { proc in
                let out = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                let err = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                if proc.terminationStatus == 0 {
                    continuation.resume(returning: out)
                } else {
                    continuation.resume(throwing: CompressionError.unsupportedMedia(err.isEmpty ? "ffprobe failed" : err))
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: CompressionError.missingEncoder(error.localizedDescription))
            }
        }
    }
}
