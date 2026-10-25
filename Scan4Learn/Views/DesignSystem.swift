import Observation
import SwiftUI

enum AppTheme: String, CaseIterable, Codable, Identifiable {
    case forest, ocean, sun, rose, grape
    var id: String { rawValue }
    var name: String {
        switch self {
        case .forest: String(localized: "Forest green")
        case .ocean: String(localized: "Ocean blue")
        case .sun: String(localized: "Sunny yellow")
        case .rose: String(localized: "Red")
        case .grape: String(localized: "Grape purple")
        }
    }
    /// Deep brand colour for prominent cards and primary buttons.
    var accent: Color {
        switch self {
        case .forest: Color(red: 0.09, green: 0.23, blue: 0.19)
        case .ocean: Color(red: 0.04, green: 0.20, blue: 0.42)
        case .sun: Color(red: 0.42, green: 0.29, blue: 0.04)
        case .rose: Color(red: 0.47, green: 0.09, blue: 0.16)
        case .grape: Color(red: 0.29, green: 0.14, blue: 0.44)
        }
    }
    /// Bright companion colour highlighted on top of the accent.
    var glow: Color {
        switch self {
        case .forest: Color(red: 0.82, green: 0.95, blue: 0.48)
        case .ocean: Color(red: 0.56, green: 0.85, blue: 0.98)
        case .sun: Color(red: 1.00, green: 0.85, blue: 0.35)
        case .rose: Color(red: 1.00, green: 0.70, blue: 0.72)
        case .grape: Color(red: 0.88, green: 0.80, blue: 0.98)
        }
    }
    var canvas: Color {
        switch self {
        case .forest: AppTheme.dynamic(light: UIColor(red: 0.96, green: 0.96, blue: 0.93, alpha: 1), dark: UIColor(red: 0.07, green: 0.09, blue: 0.09, alpha: 1))
        case .ocean: AppTheme.dynamic(light: UIColor(red: 0.93, green: 0.95, blue: 0.98, alpha: 1), dark: UIColor(red: 0.05, green: 0.08, blue: 0.12, alpha: 1))
        case .sun: AppTheme.dynamic(light: UIColor(red: 0.98, green: 0.96, blue: 0.87, alpha: 1), dark: UIColor(red: 0.10, green: 0.09, blue: 0.05, alpha: 1))
        case .rose: AppTheme.dynamic(light: UIColor(red: 0.98, green: 0.94, blue: 0.94, alpha: 1), dark: UIColor(red: 0.11, green: 0.06, blue: 0.07, alpha: 1))
        case .grape: AppTheme.dynamic(light: UIColor(red: 0.96, green: 0.94, blue: 0.98, alpha: 1), dark: UIColor(red: 0.08, green: 0.06, blue: 0.11, alpha: 1))
        }
    }
    var ink: Color {
        switch self {
        case .forest: AppTheme.dynamic(light: UIColor(red: 0.11, green: 0.17, blue: 0.16, alpha: 1), dark: .white)
        case .ocean: AppTheme.dynamic(light: UIColor(red: 0.06, green: 0.13, blue: 0.25, alpha: 1), dark: .white)
        case .sun: AppTheme.dynamic(light: UIColor(red: 0.24, green: 0.16, blue: 0.03, alpha: 1), dark: .white)
        case .rose: AppTheme.dynamic(light: UIColor(red: 0.26, green: 0.07, blue: 0.11, alpha: 1), dark: .white)
        case .grape: AppTheme.dynamic(light: UIColor(red: 0.16, green: 0.09, blue: 0.27, alpha: 1), dark: .white)
        }
    }
    private static func dynamic(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? dark : light })
    }
}

/// App-wide user settings: theme, FSRS target retention, ChatGPT thinking mode
/// and the language override. Everything is persisted in user defaults.
@Observable
final class AppSettings {
    static let themeKey = "appTheme"
    static let retentionKey = "targetRetention"
    static let thinkingKey = "chatgptThinking"
    static let languageKey = "appLanguage"
    static let defaultRetention = 0.9

    var theme: AppTheme {
        didSet { UserDefaults.standard.set(theme.rawValue, forKey: Self.themeKey) }
    }
    var targetRetention: Double {
        didSet { UserDefaults.standard.set(targetRetention, forKey: Self.retentionKey) }
    }
    var prefersThinking: Bool {
        didSet { UserDefaults.standard.set(prefersThinking, forKey: Self.thinkingKey) }
    }
    var language: AppLanguage {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: Self.languageKey)
            Bundle.activateLanguageOverride(language.code)
        }
    }

    init(theme: AppTheme? = nil, retention: Double? = nil, thinking: Bool? = nil, language: AppLanguage? = nil) {
        let defaults = UserDefaults.standard
        self.theme = theme ?? AppTheme(rawValue: defaults.string(forKey: Self.themeKey) ?? "") ?? .forest
        self.targetRetention = retention ?? defaults.object(forKey: Self.retentionKey) as? Double ?? Self.defaultRetention
        self.prefersThinking = thinking ?? defaults.bool(forKey: Self.thinkingKey)
        self.language = language ?? AppLanguage(rawValue: defaults.string(forKey: Self.languageKey) ?? "") ?? .system
        Bundle.activateLanguageOverride(self.language.code)
    }

    /// Locale used for dates and numbers so they match the chosen app language.
    var locale: Locale {
        language.code.map { Locale(identifier: $0) } ?? .autoupdatingCurrent
    }
}

extension Subject {
    /// The symbol to render, falling back to a folder when the stored name
    /// is not available on this OS.
    var effectiveSymbol: String {
        UIImage(systemName: symbolName) != nil ? symbolName : "folder"
    }

    private static let customPalette: [Color] = [
        Color(red: 0.24, green: 0.42, blue: 0.91),
        Color(red: 0.69, green: 0.35, blue: 0.38),
        Color(red: 0.51, green: 0.37, blue: 0.76),
        Color(red: 0.19, green: 0.52, blue: 0.36),
        Color(red: 0.70, green: 0.40, blue: 0.16),
        Color(red: 0.16, green: 0.47, blue: 0.62),
        Color(red: 0.58, green: 0.24, blue: 0.24),
        Color(red: 0.33, green: 0.33, blue: 0.36)
    ]

    static var paletteColorCount: Int { customPalette.count }

    var color: Color {
        if colorIndex >= 0 { return Self.customPalette[colorIndex % Self.customPalette.count] }
        switch id {
        case "math": return Color(red: 0.24, green: 0.42, blue: 0.91)
        case "literature": return Color(red: 0.69, green: 0.35, blue: 0.38)
        case "english": return Color(red: 0.51, green: 0.37, blue: 0.76)
        case "science": return Color(red: 0.19, green: 0.52, blue: 0.36)
        case "historyGeography": return Color(red: 0.70, green: 0.40, blue: 0.16)
        default: return .secondary
        }
    }
}

struct PageBackground: ViewModifier {
    @Environment(AppSettings.self) private var appSettings
    func body(content: Content) -> some View {
        content.background(appSettings.theme.canvas).foregroundStyle(appSettings.theme.ink)
    }
}

extension View {
    func studyPage() -> some View { modifier(PageBackground()) }
    func studyCard() -> some View {
        padding(20).background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24))
    }
}

struct Eyebrow: View {
    let text: String
    var body: some View { Text(text.uppercased()).font(.system(.caption2, design: .monospaced, weight: .semibold)).tracking(2).foregroundStyle(.secondary) }
}

struct SectionTitle: View {
    let title: String
    var caption: String? = nil
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.title3.weight(.bold))
            Spacer()
            if let caption { Text(caption).font(.caption).foregroundStyle(.secondary) }
        }
    }
}

struct SubjectIcon: View {
    let subject: Subject
    var body: some View {
        Image(systemName: subject.effectiveSymbol).font(.title3.weight(.semibold))
            .foregroundStyle(subject.color).frame(width: 48, height: 48)
            .background(subject.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
            .accessibilityHidden(true)
    }
}

struct LessonRow: View {
    @Environment(AppSettings.self) private var appSettings
    let lesson: Lesson
    var body: some View {
        HStack(spacing: 14) {
            SubjectIcon(subject: lesson.subject)
            VStack(alignment: .leading, spacing: 6) {
                Text(lesson.title).font(.headline).foregroundStyle(appSettings.theme.ink).multilineTextAlignment(.leading)
                Text(lesson.isReady
                     ? String(localized: "\(lesson.subject.title) · \(lesson.flashcards.count) cards")
                     : String(localized: "\(lesson.subject.title) · Awaiting study pack"))
                    .font(.caption).foregroundStyle(.secondary)
                if lesson.isSample { Text(String(localized: "SAMPLE")).font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(.secondary) }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
        }.studyCard()
    }
}

struct PrimaryButton: View {
    @Environment(AppSettings.self) private var appSettings
    let title: String
    var symbol = "arrow.right"
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack { Text(title); Spacer(); Image(systemName: symbol) }
                .font(.headline).padding(.vertical, 10).padding(.horizontal, 8).frame(minHeight: 44)
        }.buttonStyle(.glassProminent).tint(appSettings.theme.accent)
    }
}

struct InfoNote: View {
    let text: String
    var symbol = "info.circle"
    var body: some View {
        Label(text, systemImage: symbol).font(.footnote).foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}
