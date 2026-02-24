import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var languageStore: LanguageStore
    @EnvironmentObject private var themeStore: ThemeStore
    @StateObject private var viewModel = CompressionViewModel()
    @State private var isDropTargeted = false

    private let audioBitrateOptions = [64, 96, 128, 160, 192, 256, 320]
    private let sampleRateOptions = [22_050, 32_000, 44_100, 48_000]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            languageSection
            inputSection
            parameterSection
            estimateSection
            outputSection
            actionSection
            statusSection
        }
        .padding(16)
        .onAppear {
            viewModel.validateEncoderAvailability()
        }
        .onChange(of: viewModel.selectedPreset) { newValue in
            viewModel.applyPreset(newValue)
        }
        .onChange(of: viewModel.outputFPS) { _ in viewModel.syncSettingsFromUI() }
        .onChange(of: viewModel.qualityPercent) { _ in viewModel.syncSettingsFromUI() }
        .onChange(of: viewModel.audioBitrateKbps) { _ in viewModel.syncSettingsFromUI() }
        .onChange(of: viewModel.audioSampleRate) { _ in viewModel.syncSettingsFromUI() }
        .onChange(of: viewModel.audioChannels) { _ in viewModel.syncSettingsFromUI() }
    }

    private var languageSection: some View {
        HStack {
            Text("VideoCompressor")
                .font(.headline)
            Spacer()
            Picker(L10n.tr("theme_label", language: languageStore.language), selection: $themeStore.theme) {
                ForEach(AppTheme.allCases) { theme in
                    Text(L10n.tr(theme.key, language: languageStore.language)).tag(theme)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 260)

            Picker(L10n.tr("language_label", language: languageStore.language), selection: $languageStore.language) {
                ForEach(AppLanguage.allCases) { language in
                    Text(L10n.tr(language.key, language: languageStore.language)).tag(language)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 280)
        }
    }

    private var inputSection: some View {
        GroupBox(L10n.tr("section_input", language: languageStore.language)) {
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isDropTargeted ? Color.accentColor : Color.secondary, lineWidth: 1)
                        .frame(height: 96)
                    Text(viewModel.inputURL == nil ? L10n.tr("drop_hint", language: languageStore.language) : viewModel.inputURL!.lastPathComponent)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                }
                .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isDropTargeted) { providers in
                    guard let provider = providers.first else { return false }
                    provider.loadDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { data, _ in
                        guard let data,
                              let url = URL(dataRepresentation: data, relativeTo: nil) else {
                            return
                        }
                        Task { @MainActor in
                            viewModel.handleDroppedFileURL(url)
                        }
                    }
                    return true
                }

                Button(L10n.tr("button_select_file", language: languageStore.language)) {
                    viewModel.pickInputFile()
                }

                if let media = viewModel.mediaInfo {
                    Text(L10n.fmt(
                        "source_info",
                        media.width,
                        media.height,
                        Int(media.fps.rounded()),
                        viewModel.formatBytes(media.fileSizeBytes),
                        language: languageStore.language
                    ))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var parameterSection: some View {
        GroupBox(L10n.tr("section_parameters", language: languageStore.language)) {
            VStack(alignment: .leading, spacing: 10) {
                Picker(L10n.tr("preset_label", language: languageStore.language), selection: $viewModel.selectedPreset) {
                    ForEach(CompressionPreset.allCases) { preset in
                        Text(preset.localizedTitle).tag(preset)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(viewModel.mediaInfo == nil || viewModel.isCompressing)

                HStack {
                    Stepper(value: widthBinding, in: 2...7_680, step: 2) {
                        Text("\(L10n.tr("width_label", language: languageStore.language)) \(viewModel.outputWidth)")
                    }
                    Stepper(value: heightBinding, in: 2...4_320, step: 2) {
                        Text("\(L10n.tr("height_label", language: languageStore.language)) \(viewModel.outputHeight)")
                    }
                }
                .disabled(viewModel.mediaInfo == nil || viewModel.isCompressing)

                Toggle(
                    L10n.tr("lock_ratio_label", language: languageStore.language),
                    isOn: lockAspectBinding
                )
                .disabled(viewModel.mediaInfo == nil || viewModel.isCompressing)

                if let ratio = viewModel.aspectRatioText {
                    Text(L10n.fmt("aspect_ratio_value", ratio, language: languageStore.language))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Stepper(value: $viewModel.outputFPS, in: 1...120, step: 1) {
                        Text("\(L10n.tr("fps_label", language: languageStore.language)) \(viewModel.outputFPS)")
                    }
                    VStack(alignment: .leading) {
                        Text("\(L10n.tr("quality_label", language: languageStore.language)) \(viewModel.qualityPercent)")
                        Slider(value: Binding(
                            get: { Double(viewModel.qualityPercent) },
                            set: { viewModel.qualityPercent = Int($0.rounded()) }
                        ), in: 0...100, step: 1)
                    }
                }
                .disabled(viewModel.mediaInfo == nil || viewModel.isCompressing)

                HStack {
                    Picker(L10n.tr("audio_bitrate_label", language: languageStore.language), selection: $viewModel.audioBitrateKbps) {
                        ForEach(audioBitrateOptions, id: \.self) { bitrate in
                            Text("\(bitrate) kbps").tag(bitrate)
                        }
                    }
                    Picker(L10n.tr("sample_rate_label", language: languageStore.language), selection: $viewModel.audioSampleRate) {
                        ForEach(sampleRateOptions, id: \.self) { rate in
                            Text("\(rate) Hz").tag(rate)
                        }
                    }
                    Picker(L10n.tr("channels_label", language: languageStore.language), selection: $viewModel.audioChannels) {
                        Text("1").tag(1)
                        Text("2").tag(2)
                    }
                }
                .disabled(viewModel.mediaInfo == nil || viewModel.isCompressing)
            }
        }
    }

    private var estimateSection: some View {
        GroupBox(L10n.tr("section_estimate", language: languageStore.language)) {
            VStack(alignment: .leading, spacing: 6) {
                if let media = viewModel.mediaInfo,
                   let estimate = viewModel.estimate {
                    Text(L10n.fmt("estimate_original", viewModel.formatBytes(media.fileSizeBytes), language: languageStore.language))
                    Text(L10n.fmt("estimate_target", viewModel.formatBytes(estimate.estimatedBytes), language: languageStore.language))
                    Text(L10n.fmt("estimate_ratio", viewModel.formatRatio(estimate.estimatedCompressionRatio), language: languageStore.language))

                    if let estimatedTime = viewModel.estimatedCompressionTimeSec {
                        Text(L10n.fmt("estimate_time", viewModel.formatDuration(estimatedTime), language: languageStore.language))
                    }
                    if viewModel.isCompressing, let remaining = viewModel.remainingTimeSec {
                        Text(L10n.fmt("remaining_time", viewModel.formatDuration(remaining), language: languageStore.language))
                    }

                    if viewModel.estimateUsesFallback {
                        Text(L10n.tr("estimate_fallback_hint", language: languageStore.language))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text(L10n.tr("estimate_empty", language: languageStore.language))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var outputSection: some View {
        GroupBox(L10n.tr("section_output", language: languageStore.language)) {
            HStack {
                Text(viewModel.outputURL?.path ?? L10n.tr("output_empty", language: languageStore.language))
                    .lineLimit(2)
                    .textSelection(.enabled)
                Spacer()
                Button(L10n.tr("button_select_output", language: languageStore.language)) {
                    viewModel.pickExportDirectory()
                }
                .disabled(viewModel.mediaInfo == nil || viewModel.isCompressing)
            }
        }
    }

    private var actionSection: some View {
        GroupBox(L10n.tr("section_actions", language: languageStore.language)) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Button(L10n.tr("button_start", language: languageStore.language)) {
                        viewModel.startCompression()
                    }
                    .disabled(!viewModel.canStart)

                    Button(L10n.tr("button_cancel", language: languageStore.language)) {
                        viewModel.cancelCompression()
                    }
                    .disabled(!viewModel.isCompressing)
                }

                ProgressView(value: viewModel.progressValue)
            }
        }
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(L10n.tr("status_label", language: languageStore.language)) \(viewModel.statusText)")
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.footnote)
            }
            if case .failed(let message) = viewModel.state {
                Text(message)
                    .foregroundStyle(.red)
                    .font(.footnote)
            }
        }
    }

    private var widthBinding: Binding<Int> {
        Binding(
            get: { viewModel.outputWidth },
            set: { viewModel.userSetOutputWidth($0) }
        )
    }

    private var heightBinding: Binding<Int> {
        Binding(
            get: { viewModel.outputHeight },
            set: { viewModel.userSetOutputHeight($0) }
        )
    }

    private var lockAspectBinding: Binding<Bool> {
        Binding(
            get: { viewModel.lockAspectRatio },
            set: { viewModel.userSetLockAspectRatio($0) }
        )
    }
}
