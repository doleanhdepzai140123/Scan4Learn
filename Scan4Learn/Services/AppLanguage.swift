import Foundation
import ObjectiveC

/// In-app language choice; `.system` follows the device language.
enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case vi
    case en
    case zhHans = "zh-Hans"
    case ru
    case fr
    case de

    var id: String { rawValue }

    /// The language's own name, deliberately shown untranslated.
    var displayName: String {
        switch self {
        case .system: return String(localized: "Follows the system language")
        case .vi: return "Tiếng Việt"
        case .en: return "English"
        case .zhHans: return "中文"
        case .ru: return "Русский"
        case .fr: return "Français"
        case .de: return "Deutsch"
        }
    }

    /// BCP-47 code, or nil to follow the system.
    var code: String? {
        switch self {
        case .system: return nil
        default: return rawValue
        }
    }

    /// Language used for first-run sample seeding: the override first, then the system.
    static var seedingCode: String? {
        if let stored = UserDefaults.standard.string(forKey: AppSettings.languageKey),
           let language = AppLanguage(rawValue: stored), let code = language.code { return code }
        return Bundle.main.preferredLocalizations.first
    }
}

private var overrideBundleKey: UInt8 = 0

extension Bundle {
    /// Points string lookups at the selected language's tables. Apply once at launch
    /// and whenever the user changes the language; SwiftUI re-renders pick it up
    /// because the root view is rebuilt on language change.
    static func activateLanguageOverride(_ code: String?) {
        let bundle = code.flatMap { code in
            Bundle.main.path(forResource: code, ofType: "lproj").flatMap { Bundle(path: $0) }
        }
        objc_setAssociatedObject(Bundle.main, &overrideBundleKey, bundle, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    static func applyLanguageSwizzle() {
        guard let original = class_getInstanceMethod(Bundle.self, #selector(localizedString(forKey:value:table:))),
              let swizzled = class_getInstanceMethod(Bundle.self, #selector(localizedStringOverride(forKey:value:table:)))
        else { return }
        method_exchangeImplementations(original, swizzled)
    }

    @objc private func localizedStringOverride(forKey key: String, value: String?, table tableName: String?) -> String {
        if self === Bundle.main,
           let override = objc_getAssociatedObject(Bundle.main, &overrideBundleKey) as? Bundle {
            return override.localizedString(forKey: key, value: value, table: tableName)
        }
        // After swizzling this call reaches the original implementation.
        return localizedStringOverride(forKey: key, value: value, table: tableName)
    }
}
