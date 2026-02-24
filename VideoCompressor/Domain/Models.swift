import Foundation

enum CompressionState: Equatable {
    case idle
    case ready
    case compressing(progress: Double)
    case completed(outputURL: URL)
    case failed(message: String)
    case canceled
}

struct MediaInfo: Equatable {
    let url: URL
    let durationSec: Double
    let width: Int
    let height: Int
    let fps: Double
    let videoBitrateKbps: Int
    let audioBitrateKbps: Int?
    let fileSizeBytes: Int64
}

struct SizeEstimate: Equatable {
    let estimatedBytes: Int64
    let estimatedCompressionRatio: Double
}

enum CompressionError: Error, LocalizedError {
    case missingInput
    case unsupportedMedia(String)
    case missingEncoder(String)
    case invalidOutputPath
    case ffmpegFailed(String)
    case canceled

    var errorDescription: String? {
        switch self {
        case .missingInput:
            return L10n.tr("error_missing_input")
        case .unsupportedMedia(let reason):
            return L10n.fmt("error_unsupported_media", reason)
        case .missingEncoder(let reason):
            return L10n.fmt("error_missing_encoder", reason)
        case .invalidOutputPath:
            return L10n.tr("error_invalid_output")
        case .ffmpegFailed(let reason):
            return L10n.fmt("error_ffmpeg_failed", reason)
        case .canceled:
            return L10n.tr("status_canceled")
        }
    }
}
