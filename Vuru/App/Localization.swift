import Foundation

/// In-app language choice. "System" follows the phone's language, falling
/// back to English when the phone uses a language the app doesn't have.
/// SwiftUI text follows the `locale` environment set at the root; strings
/// built in code go through `L(_:)`, which reads the chosen `.lproj`.
enum AppLanguage: String, CaseIterable, Identifiable {
    // English first, then by total number of speakers worldwide
    // (L1 + L2, Ethnologue 2025, rounded).
    case system
    case en          // ~1.5 billion
    case zhHans = "zh-Hans" // ~1.2 billion (Mandarin)
    case hi          // ~610 million
    case es          // ~560 million
    case ar          // ~335 million (Modern Standard Arabic)
    case fr          // ~310 million
    case bn          // ~285 million
    case pt          // ~265 million
    case ru          // ~255 million
    case id          // ~250 million
    case de          // ~135 million
    case ja          // ~125 million
    case tr          // ~90 million

    var id: String { rawValue }

    static let storageKey = "appLanguage"
    static let fallbackCode = "en"

    /// The languages a user can pick, in display order.
    static var choices: [AppLanguage] { allCases.filter { $0 != .system } }

    static var current: AppLanguage {
        AppLanguage(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "") ?? .system
    }

    /// The app language matching a phone language such as "pt-BR" or "zh-Hant-TW".
    static func supported(matching identifier: String) -> AppLanguage? {
        guard let code = Locale.Language(identifier: identifier).languageCode?.identifier else { return nil }
        if code == "zh" { return .zhHans }
        return choices.first { $0.rawValue == code }
    }

    /// The phone's first preferred language the app has, if any.
    static var phoneLanguage: AppLanguage? {
        Locale.preferredLanguages.lazy.compactMap(supported(matching:)).first
    }

    /// The localization actually used, e.g. "tr" for system on a Turkish phone.
    var resolvedCode: String {
        switch self {
        case .system: Self.phoneLanguage?.rawValue ?? Self.fallbackCode
        default: rawValue
        }
    }

    /// Locale for text and number formatting. With "system" on a supported
    /// language the phone's own locale (and region formats) is kept.
    var locale: Locale {
        if self == .system, Self.phoneLanguage != nil { return .current }
        return Locale(identifier: resolvedCode)
    }

    /// Shown in its own language so it is recognisable whatever is selected.
    var nativeName: String {
        switch self {
        case .system: L("Telefonun dili")
        case .en: "English"
        case .zhHans: "简体中文"
        case .hi: "हिन्दी"
        case .es: "Español"
        case .ar: "العربية"
        case .fr: "Français"
        case .bn: "বাংলা"
        case .pt: "Português"
        case .ru: "Русский"
        case .id: "Bahasa Indonesia"
        case .de: "Deutsch"
        case .ja: "日本語"
        case .tr: "Türkçe"
        }
    }

    /// Also tells iOS, so permission prompts and notifications switch
    /// language from the next launch.
    static func apply(_ language: AppLanguage) {
        UserDefaults.standard.set(language.rawValue, forKey: storageKey)
        if language == .system {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.set([language.resolvedCode], forKey: "AppleLanguages")
        }
    }
}

extension Bundle {
    /// The `.lproj` bundle of the language in use, or the main bundle.
    static var appLanguage: Bundle {
        guard let path = Bundle.main.path(forResource: AppLanguage.current.resolvedCode, ofType: "lproj"),
              let bundle = Bundle(path: path) else { return .main }
        return bundle
    }
}

/// Localized string for code paths outside SwiftUI `Text` literals.
func L(_ value: String.LocalizationValue) -> String {
    String(localized: value, bundle: .appLanguage)
}

extension Double {
    /// One decimal in the app language (1,6 / 1.6).
    var oneDecimal: String {
        formatted(.number.precision(.fractionLength(1)).locale(AppLanguage.current.locale))
    }
}

/// "7 sa 20 dk" / "7 hr, 20 min"
func durationText(minutes: Double) -> String {
    Duration.seconds(Int(minutes.rounded()) * 60)
        .formatted(.units(allowed: [.hours, .minutes], width: .abbreviated)
            .locale(AppLanguage.current.locale))
}
