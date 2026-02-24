import Foundation

enum CompressionPreset: String, CaseIterable, Identifiable {
    case high
    case medium
    case small

    var id: String { rawValue }

    var localizedTitle: String {
        switch self {
        case .high:
            return L10n.tr("preset_high")
        case .medium:
            return L10n.tr("preset_medium")
        case .small:
            return L10n.tr("preset_small")
        }
    }
}
