import AppKit
import Foundation
import SwiftUI

@MainActor
final class CompressionViewModel: ObservableObject {
    @Published var mediaInfo: MediaInfo?
    @Published var state: CompressionState = .idle
    @Published var inputURL: URL?
    @Published var outputURL: URL?
    @Published var exportDirectoryURL: URL?
    @Published var estimate: SizeEstimate?
    @Published var estimateUsesFallback = false
    @Published var estimatedCompressionTimeSec: Double?
    @Published var remainingTimeSec: Double?
    @Published var errorMessage: String?

    @Published var selectedPreset: CompressionPreset = .medium
    @Published var outputWidth: Int = 1280
    @Published var outputHeight: Int = 720
    @Published var lockAspectRatio: Bool = true
    @Published var outputFPS: Int = 30
    @Published var qualityPercent: Int = 60
    @Published var audioBitrateKbps: Int = 128
    @Published var audioSampleRate: Int = 44_100
    @Published var audioChannels: Int = 2

    private let mediaProbeService = MediaProbeService()
    private let estimator = SizeEstimator()
    private let commandBuilder = FFmpegCommandBuilder()
    private let executor = FFmpegExecutor()
    private let fileNameResolver = FileNameResolver()
    private let exportPathService = ExportPathService()
    private let timeEstimator = CompressionTimeEstimator()
    private let binaryLocator = BinaryLocator()

    private var compressionTask: Task<Void, Never>?
    private var compressionStartDate: Date?

    var isCompressing: Bool {
        if case .compressing = state {
            return true
        }
        return false
    }

    var progressValue: Double {
        if case .compressing(let progress) = state {
            return progress
        }
        if case .completed = state {
            return 1
        }
        return 0
    }

    var canStart: Bool {
        guard !isCompressing,
              let mediaInfo,
              let outputURL else {
            return false
        }
        let dir = outputURL.deletingLastPathComponent()
        return exportPathService.isWritableDirectory(dir) && mediaInfo.durationSec > 0
    }

    var aspectRatioText: String? {
        guard outputWidth > 0, outputHeight > 0 else {
            return nil
        }
        let divisor = gcd(outputWidth, outputHeight)
        let w = outputWidth / max(1, divisor)
        let h = outputHeight / max(1, divisor)
        return "\(w):\(h)"
    }

    var statusText: String {
        switch state {
        case .idle:
            return L10n.tr("status_idle")
        case .ready:
            return L10n.tr("status_ready")
        case .compressing(let progress):
            return L10n.fmt("status_compressing", Int(progress * 100))
        case .completed(let url):
            return L10n.fmt("status_completed", url.lastPathComponent)
        case .failed(let message):
            return message
        case .canceled:
            return L10n.tr("status_canceled")
        }
    }

    func pickInputFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.movie, .mpeg4Movie, .quickTimeMovie, .audiovisualContent]
        panel.prompt = L10n.tr("button_select_file")

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }
        loadMedia(url: url)
    }

    func handleDroppedFileURL(_ url: URL) {
        loadMedia(url: url)
    }

    func pickExportDirectory() {
        let start = exportDirectoryURL ?? inputURL?.deletingLastPathComponent()
        guard let selected = exportPathService.chooseDirectory(initialURL: start) else {
            return
        }
        guard exportPathService.isWritableDirectory(selected) else {
            errorMessage = CompressionError.invalidOutputPath.localizedDescription
            return
        }
        exportDirectoryURL = selected
        rebuildOutputURL()
        refreshEstimate()
    }

    func applyPreset(_ preset: CompressionPreset) {
        guard let mediaInfo else { return }
        selectedPreset = preset
        var settings = CompressionSettings.makeDefault(for: mediaInfo, outputURL: outputURL ?? mediaInfo.url, preset: preset)
        settings.outputURL = outputURL ?? settings.outputURL
        applySettings(settings)
        refreshEstimate()
    }

    func syncSettingsFromUI() {
        rebuildOutputURLIfMissing()
        refreshEstimate()
    }

    func userSetOutputWidth(_ width: Int) {
        let evenWidth = max(2, width / 2 * 2)
        if lockAspectRatio, let mediaInfo {
            let ratio = Double(mediaInfo.height) / Double(mediaInfo.width)
            let calculatedHeight = max(2, Int((Double(evenWidth) * ratio).rounded()) / 2 * 2)
            outputWidth = evenWidth
            outputHeight = calculatedHeight
        } else {
            outputWidth = evenWidth
        }
        syncSettingsFromUI()
    }

    func userSetOutputHeight(_ height: Int) {
        let evenHeight = max(2, height / 2 * 2)
        if lockAspectRatio, let mediaInfo {
            let ratio = Double(mediaInfo.width) / Double(mediaInfo.height)
            let calculatedWidth = max(2, Int((Double(evenHeight) * ratio).rounded()) / 2 * 2)
            outputHeight = evenHeight
            outputWidth = calculatedWidth
        } else {
            outputHeight = evenHeight
        }
        syncSettingsFromUI()
    }

    func userSetLockAspectRatio(_ enabled: Bool) {
        lockAspectRatio = enabled
        guard enabled else {
            syncSettingsFromUI()
            return
        }
        userSetOutputWidth(outputWidth)
    }

    func startCompression() {
        guard let mediaInfo,
              let outputURL,
              let ffmpeg = binaryLocator.ffmpegPath() else {
            state = .failed(message: CompressionError.missingEncoder(L10n.tr("error_missing_ffmpeg_hint")).localizedDescription)
            return
        }

        guard exportPathService.isWritableDirectory(outputURL.deletingLastPathComponent()) else {
            state = .failed(message: CompressionError.invalidOutputPath.localizedDescription)
            return
        }

        errorMessage = nil
        let settings = currentSettings(outputURL: outputURL)
        state = .compressing(progress: 0)
        compressionStartDate = Date()
        remainingTimeSec = estimatedCompressionTimeSec

        compressionTask?.cancel()
        compressionTask = Task { [weak self] in
            guard let self else { return }
            do {
                let uniqueOutput = self.fileNameResolver.uniqueOutputURL(
                    directory: settings.outputURL.deletingLastPathComponent(),
                    baseName: settings.outputURL.deletingPathExtension().lastPathComponent,
                    ext: settings.outputURL.pathExtension.isEmpty ? "mp4" : settings.outputURL.pathExtension
                )
                var resolvedSettings = settings
                resolvedSettings.outputURL = uniqueOutput
                await MainActor.run { self.outputURL = uniqueOutput }

                let command = self.commandBuilder.build(
                    ffmpegPath: ffmpeg,
                    mediaInfo: mediaInfo,
                    settings: resolvedSettings
                )

                try await self.executor.execute(command: command, durationSec: mediaInfo.durationSec) { [weak self] progress in
                    Task { @MainActor in
                        self?.updateProgress(progress)
                    }
                }

                await MainActor.run {
                    self.state = .completed(outputURL: uniqueOutput)
                    self.remainingTimeSec = 0
                    if let start = self.compressionStartDate {
                        self.timeEstimator.recordCompression(
                            mediaDurationSec: mediaInfo.durationSec,
                            elapsedSec: max(0.01, Date().timeIntervalSince(start))
                        )
                    }
                    self.compressionStartDate = nil
                    self.refreshEstimate()
                }
            } catch {
                await MainActor.run {
                    if let compressionError = error as? CompressionError, case .canceled = compressionError {
                        self.state = .canceled
                    } else {
                        self.state = .failed(message: error.localizedDescription)
                    }
                    self.remainingTimeSec = nil
                    self.compressionStartDate = nil
                }
            }
        }
    }

    func cancelCompression() {
        compressionTask?.cancel()
        Task {
            await executor.cancel()
        }
    }

    func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    func formatRatio(_ ratio: Double) -> String {
        let pct = ratio * 100
        return String(format: "%.1f%%", pct)
    }

    func formatDuration(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else {
            return "--:--"
        }
        let total = Int(seconds.rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%02d:%02d", minutes, secs)
    }

    func validateEncoderAvailability() {
        if binaryLocator.ffmpegPath() == nil || binaryLocator.ffprobePath() == nil {
            errorMessage = L10n.tr("error_missing_encoder_both")
        }
    }

    private func updateProgress(_ progress: Double) {
        state = .compressing(progress: progress)
        guard let start = compressionStartDate, progress > 0.001 else {
            return
        }
        let elapsed = Date().timeIntervalSince(start)
        let total = elapsed / progress
        remainingTimeSec = max(0, total - elapsed)
    }

    private func loadMedia(url: URL) {
        errorMessage = nil
        inputURL = url
        state = .idle
        remainingTimeSec = nil
        estimatedCompressionTimeSec = nil
        compressionStartDate = nil

        Task {
            do {
                let info = try await mediaProbeService.probe(url: url)
                await MainActor.run {
                    self.mediaInfo = info
                    self.selectedPreset = .medium
                    self.exportDirectoryURL = url.deletingLastPathComponent()
                    let defaultOutput = self.makeDefaultOutputURL(for: url, directory: self.exportDirectoryURL)
                    let settings = CompressionSettings.makeDefault(for: info, outputURL: defaultOutput, preset: .medium)
                    self.applySettings(settings)
                    self.refreshEstimate()
                    self.state = .ready
                }
            } catch {
                await MainActor.run {
                    self.mediaInfo = nil
                    self.estimate = nil
                    self.estimatedCompressionTimeSec = nil
                    self.remainingTimeSec = nil
                    self.outputURL = nil
                    self.state = .failed(message: error.localizedDescription)
                }
            }
        }
    }

    private func applySettings(_ settings: CompressionSettings) {
        selectedPreset = settings.preset
        outputWidth = settings.outputWidth
        outputHeight = settings.outputHeight
        outputFPS = settings.outputFPS
        qualityPercent = settings.qualityPercent
        audioBitrateKbps = settings.audioBitrateKbps
        audioSampleRate = settings.audioSampleRate
        audioChannels = settings.audioChannels
        outputURL = settings.outputURL
    }

    private func currentSettings(outputURL: URL) -> CompressionSettings {
        CompressionSettings(
            preset: selectedPreset,
            outputWidth: max(2, outputWidth / 2 * 2),
            outputHeight: max(2, outputHeight / 2 * 2),
            outputFPS: max(1, outputFPS),
            qualityPercent: min(100, max(0, qualityPercent)),
            audioBitrateKbps: max(32, audioBitrateKbps),
            audioSampleRate: max(8_000, audioSampleRate),
            audioChannels: max(1, min(2, audioChannels)),
            outputURL: outputURL
        )
    }

    private func refreshEstimate() {
        guard let mediaInfo else {
            estimate = nil
            estimatedCompressionTimeSec = nil
            return
        }
        rebuildOutputURLIfMissing()
        guard let outputURL else {
            estimate = nil
            estimatedCompressionTimeSec = nil
            return
        }
        let settings = currentSettings(outputURL: outputURL)
        estimate = estimator.estimateSize(mediaInfo: mediaInfo, settings: settings)
        estimateUsesFallback = estimator.targetVideoBitrate(mediaInfo: mediaInfo, settings: settings).estimatedFromFallback
        estimatedCompressionTimeSec = timeEstimator.estimateDurationSec(mediaInfo: mediaInfo, settings: settings)
        if !isCompressing {
            remainingTimeSec = nil
        }
    }

    private func rebuildOutputURL() {
        guard let inputURL else {
            outputURL = nil
            return
        }
        let url = makeDefaultOutputURL(for: inputURL, directory: exportDirectoryURL)
        outputURL = url
    }

    private func rebuildOutputURLIfMissing() {
        if outputURL == nil {
            rebuildOutputURL()
        }
    }

    private func makeDefaultOutputURL(for input: URL, directory: URL?) -> URL {
        let dir = directory ?? input.deletingLastPathComponent()
        let base = input.deletingPathExtension().lastPathComponent + "_compressed"
        return fileNameResolver.uniqueOutputURL(directory: dir, baseName: base, ext: "mp4")
    }

    private func gcd(_ a: Int, _ b: Int) -> Int {
        var x = abs(a)
        var y = abs(b)
        while y != 0 {
            let temp = y
            y = x % y
            x = temp
        }
        return max(1, x)
    }
}
