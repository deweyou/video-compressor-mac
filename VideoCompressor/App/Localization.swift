import Foundation
import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case zhHans = "zh-Hans"
    case english = "en"

    var id: String { rawValue }

    var key: String {
        switch self {
        case .system:
            return "language_system"
        case .zhHans:
            return "language_zh"
        case .english:
            return "language_en"
        }
    }

    var localizationCode: String? {
        switch self {
        case .system:
            return nil
        case .zhHans:
            return "zh-Hans"
        case .english:
            return "en"
        }
    }
}

enum AppTheme: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var key: String {
        switch self {
        case .system:
            return "theme_system"
        case .light:
            return "theme_light"
        case .dark:
            return "theme_dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}

@MainActor
final class LanguageStore: ObservableObject {
    @Published var language: AppLanguage {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: Self.userDefaultsKey)
        }
    }

    private static let userDefaultsKey = "video_compressor_app_language"

    init() {
        if let saved = UserDefaults.standard.string(forKey: Self.userDefaultsKey),
           let parsed = AppLanguage(rawValue: saved) {
            language = parsed
        } else {
            language = .system
        }
    }

    var locale: Locale {
        L10n.locale(for: language)
    }
}

@MainActor
final class ThemeStore: ObservableObject {
    @Published var theme: AppTheme {
        didSet {
            UserDefaults.standard.set(theme.rawValue, forKey: Self.userDefaultsKey)
        }
    }

    private static let userDefaultsKey = "video_compressor_app_theme"

    init() {
        if let saved = UserDefaults.standard.string(forKey: Self.userDefaultsKey),
           let parsed = AppTheme(rawValue: saved) {
            theme = parsed
        } else {
            theme = .system
        }
    }

    var preferredScheme: ColorScheme? {
        theme.colorScheme
    }
}

enum L10n {
    static func tr(_ key: String, language: AppLanguage? = nil) -> String {
        let selected = language ?? currentLanguage()
        let bundle = localizedBundle(for: selected)
        return NSLocalizedString(key, tableName: nil, bundle: bundle, value: key, comment: "")
    }

    static func fmt(_ key: String, _ args: CVarArg..., language: AppLanguage? = nil) -> String {
        let selected = language ?? currentLanguage()
        let template = tr(key, language: selected)
        return String(format: template, locale: locale(for: selected), arguments: args)
    }

    static func locale(for language: AppLanguage) -> Locale {
        switch language {
        case .system:
            return .autoupdatingCurrent
        case .zhHans:
            return Locale(identifier: "zh-Hans")
        case .english:
            return Locale(identifier: "en")
        }
    }

    private static func currentLanguage() -> AppLanguage {
        if let saved = UserDefaults.standard.string(forKey: "video_compressor_app_language"),
           let parsed = AppLanguage(rawValue: saved) {
            return parsed
        }
        return .system
    }

    private static func localizedBundle(for language: AppLanguage) -> Bundle {
        guard let code = language.localizationCode else {
            return Bundle.module
        }
        if let path = Bundle.module.path(forResource: code, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle
        }
        if let path = Bundle.module.path(forResource: code.lowercased(), ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle
        }
        return Bundle.module
    }
}
