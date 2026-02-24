import Foundation

struct FFmpegCommand {
    let launchPath: String
    let arguments: [String]
}

struct FFmpegCommandBuilder {
    let estimator = SizeEstimator()

    func build(
        ffmpegPath: String,
        mediaInfo: MediaInfo,
        settings: CompressionSettings
    ) -> FFmpegCommand {
        let bitrateResult = estimator.targetVideoBitrate(mediaInfo: mediaInfo, settings: settings)
        let targetVideoBitrateKbps = bitrateResult.targetVideoBitrateKbps
        let maxKbps = max(300, Int(Double(targetVideoBitrateKbps) * 1.2))
        let bufKbps = max(600, Int(Double(targetVideoBitrateKbps) * 2.0))

        // First scale to target box while keeping ratio, then force even dimensions for x264.
        let vf = "scale=\(settings.outputWidth):\(settings.outputHeight):force_original_aspect_ratio=decrease,scale=trunc(iw/2)*2:trunc(ih/2)*2"

        let args: [String] = [
            "-nostdin",
            "-stats_period", "0.5",
            "-y",
            "-fflags", "+genpts",
            "-ignore_editlist", "1",
            "-i", mediaInfo.url.path,
            "-map", "0:v:0",
            "-map", "0:a:0?",
            "-map_metadata", "0",
            "-vf", vf,
            "-r", "\(settings.outputFPS)",
            "-c:v", "h264_videotoolbox",
            "-allow_sw", "1",
            "-profile:v", "high",
            "-tag:v", "avc1",
            "-b:v", "\(targetVideoBitrateKbps)k",
            "-maxrate", "\(maxKbps)k",
            "-bufsize", "\(bufKbps)k",
            "-c:a", "aac",
            "-b:a", "\(settings.audioBitrateKbps)k",
            "-ar", "\(settings.audioSampleRate)",
            "-ac", "\(settings.audioChannels)",
            "-movflags", "+faststart",
            "-progress", "pipe:1",
            "-nostats",
            settings.outputURL.path
        ]

        return FFmpegCommand(launchPath: ffmpegPath, arguments: args)
    }
}
