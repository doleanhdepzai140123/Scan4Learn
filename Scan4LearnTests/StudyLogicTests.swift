import UIKit
import XCTest
@testable import Scan4Learn

final class StudyLogicTests: XCTestCase {
    func testSubjectSuggestionSupportsVietnameseAndAmbiguity() {
        XCTAssertEqual(Subject.suggest(for: "CĂN BẬC HAI và phương trình"), Subject.math)
        XCTAssertEqual(Subject.suggest(for: "Điện trở và định luật Ohm"), Subject.science)
        XCTAssertEqual(Subject.suggest(for: "ĐIỆN TRỞ"), Subject.science)
        XCTAssertEqual(Subject.suggest(for: "ĐỊA LÍ"), Subject.historyGeography)
        XCTAssertEqual(Subject.suggest(for: "phương trình và nhân vật"), Subject.other)
        XCTAssertEqual(Subject.suggest(for: "Nội dung chưa rõ"), Subject.other)
    }

    func testSubjectSuggestionSupportsAllAppLanguages() {
        XCTAssertEqual(Subject.suggest(for: "Gleichung und Dreieck lösen"), Subject.math)
        XCTAssertEqual(Subject.suggest(for: "Résistance et loi d'Ohm"), Subject.science)
        XCTAssertEqual(Subject.suggest(for: "уравнение и треугольник"), Subject.math)
        XCTAssertEqual(Subject.suggest(for: "сопротивление и закон Ома"), Subject.science)
        XCTAssertEqual(Subject.suggest(for: "解一元二次方程与三角形"), Subject.math)
        XCTAssertEqual(Subject.suggest(for: "电阻与欧姆定律"), Subject.science)
        XCTAssertEqual(Subject.suggest(for: "Guerre et révolution"), Subject.historyGeography)
    }

    func testSubjectDecodesLegacyEnumRawValueAndUnknownIDs() throws {
        let legacy = #"{"id":"11111111-1111-1111-1111-111111111111","title":"T","subject":"math","createdAt":700000000,"sourceName":"s","originalText":"x"}"#
        XCTAssertEqual(try JSONDecoder().decode(Lesson.self, from: Data(legacy.utf8)).subject, Subject.math)
        let unknown = #"{"id":"11111111-1111-1111-1111-111111111111","title":"T","subject":"nonsense","createdAt":700000000,"sourceName":"s","originalText":"x"}"#
        XCTAssertEqual(try JSONDecoder().decode(Lesson.self, from: Data(unknown.utf8)).subject, Subject.other)
    }

    func testStudyPackRejectsInvalidAnswersAndEmptyContent() throws {
        let valid = #"{"summary":["Ý chính"],"flashcards":[{"front":"Hỏi","back":"Đáp"}],"questions":[{"prompt":"Câu hỏi","options":["A","B"],"correctIndex":1,"explanation":"Vì B"}]}"#
        XCTAssertEqual(try StudyPack.parse(valid).questions.first?.correctIndex, 1)
        XCTAssertEqual(try StudyPack.parse("```json\n" + valid + "\n```").summary, ["Ý chính"])
        XCTAssertThrowsError(try StudyPack.parse(valid.replacingOccurrences(of: "\"correctIndex\":1", with: "\"correctIndex\":2")))
        XCTAssertThrowsError(try StudyPack.parse(valid.replacingOccurrences(of: "Ý chính", with: "   ")))
        XCTAssertThrowsError(try StudyPack.parse("not json"))
    }

    func testWordParserReadsParagraphsTablesAndSkipsDeletedText() throws {
        let xml = """
        <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body>
        <w:p><w:r><w:t>Bài học</w:t></w:r><w:r><w:tab/><w:t>về tam giác</w:t></w:r></w:p>
        <w:p><w:del><w:r><w:t>đã xóa</w:t></w:r></w:del><w:r><w:t>Nội dung &amp; ví dụ</w:t></w:r></w:p>
        <w:tbl><w:tr><w:tc><w:p><w:r><w:t>Ô bảng</w:t></w:r></w:p></w:tc></w:tr></w:tbl>
        </w:body></w:document>
        """
        let text = try WordTextParser.read(Data(xml.utf8))
        XCTAssertTrue(text.contains("Bài học\tvề tam giác"))
        XCTAssertTrue(text.contains("Nội dung & ví dụ"))
        XCTAssertTrue(text.contains("Ô bảng"))
        XCTAssertFalse(text.contains("đã xóa"))
        XCTAssertThrowsError(try WordTextParser.read(Data("<broken>".utf8)))
    }

    func testSampleLibraryShipsCompleteLessonsInEveryLanguage() {
        for language in ["vi", "en", "zh-Hans", "ru", "fr", "de"] {
            let lessons = SampleLibrary.lessons(for: language)
            XCTAssertEqual(lessons.count, 3, "Sample count mismatch for \(language)")
            XCTAssertTrue(lessons.allSatisfy { $0.isSample && $0.isReady && !$0.flashcards.isEmpty && !$0.questions.isEmpty },
                          "Incomplete sample lesson for \(language)")
            XCTAssertEqual(Set(lessons.map(\.subject.id)).count, 3, "Samples should cover different subjects for \(language)")
        }
    }

    func testAppSettingsPersistChoices() {
        let defaults = UserDefaults.standard
        let original = (defaults.string(forKey: AppSettings.themeKey),
                        defaults.object(forKey: AppSettings.retentionKey),
                        defaults.object(forKey: AppSettings.thinkingKey),
                        defaults.string(forKey: AppSettings.languageKey))
        defer {
            defaults.set(original.0, forKey: AppSettings.themeKey)
            defaults.set(original.1, forKey: AppSettings.retentionKey)
            defaults.set(original.2, forKey: AppSettings.thinkingKey)
            defaults.set(original.3, forKey: AppSettings.languageKey)
            Bundle.activateLanguageOverride(AppLanguage(rawValue: original.3 ?? "")?.code)
        }
        let settings = AppSettings()
        settings.theme = .ocean
        settings.targetRetention = 0.85
        settings.prefersThinking = true
        settings.language = .de
        let reloaded = AppSettings()
        XCTAssertEqual(reloaded.theme, .ocean, "Theme choice must survive relaunch")
        XCTAssertEqual(reloaded.targetRetention, 0.85, accuracy: 0.0001, "Retention choice must survive relaunch")
        XCTAssertTrue(reloaded.prefersThinking, "Thinking choice must survive relaunch")
        XCTAssertEqual(reloaded.language, .de, "Language choice must survive relaunch")
        XCTAssertEqual(reloaded.locale.identifier, "de")
    }

    func testLanguageOverrideSwitchesLocalizedStringLookup() {
        // The swizzle is applied when the app host launches. Without an override
        // the lookup follows the system language, whatever it is.
        let baseline = Bundle.main.localizedString(forKey: "Today", value: nil, table: nil)
        let original = UserDefaults.standard.string(forKey: AppSettings.languageKey)
        defer {
            Bundle.activateLanguageOverride(AppLanguage(rawValue: original ?? "")?.code)
        }
        Bundle.activateLanguageOverride("en")
        XCTAssertEqual(Bundle.main.localizedString(forKey: "Today", value: nil, table: nil), "Today")
        Bundle.activateLanguageOverride("de")
        XCTAssertEqual(Bundle.main.localizedString(forKey: "Today", value: nil, table: nil), "Heute")
        Bundle.activateLanguageOverride(nil)
        XCTAssertEqual(Bundle.main.localizedString(forKey: "Today", value: nil, table: nil), baseline,
                       "Removing the override must restore the system-language lookup")
    }

    func testBundleShipsAllSixLanguages() throws {
        guard Bundle.main.bundleURL.pathExtension == "app" else {
            throw XCTSkip("Localization bundle is only meaningful inside the app host")
        }
        let available = Set(Bundle.main.localizations)
        for language in ["vi", "en", "zh-Hans", "ru", "fr", "de"] {
            let base = String(language.prefix(2))
            XCTAssertTrue(available.contains(language) || available.contains(base),
                          "Missing localization \(language); bundle has \(available.sorted())")
        }
    }

    @MainActor func testLibraryRoundTripAndSampleDeletion() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let url = directory.appending(path: "library.json")
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = StudyStore(fileURL: url)
        XCTAssertNil(store.errorMessage)
        try store.add(title: "Bài cá nhân", subject: .math, text: "Nội dung riêng", source: "Vở")
        let personalID = try XCTUnwrap(store.lessons.first { !$0.isSample }?.id)
        try store.removeSamples()
        let reloaded = StudyStore(fileURL: url)
        XCTAssertEqual(reloaded.lessons.count, 1)
        XCTAssertEqual(reloaded.lesson(personalID)?.originalText, "Nội dung riêng")
        try reloaded.remove(personalID)
        XCTAssertTrue(StudyStore(fileURL: url).lessons.isEmpty, "Empty libraries must not be reseeded")
    }

    @MainActor func testCorruptLibraryIsNeverOverwritten() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "library.json")
        let original = Data("broken json".utf8)
        try original.write(to: url)
        let store = StudyStore(fileURL: url)
        XCTAssertNotNil(store.errorMessage)
        XCTAssertThrowsError(try store.add(title: "New", subject: .other, text: "Text", source: "Test"))
        XCTAssertEqual(try Data(contentsOf: url), original)
    }

    @MainActor func testReviewAndQuizSurviveRelaunch() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "library.json")
        let store = StudyStore(fileURL: url)
        let lesson = try XCTUnwrap(store.lessons.first)
        let card = try XCTUnwrap(lesson.flashcards.first)
        try store.review(cardID: card.id, lessonID: lesson.id, rating: .easy, retention: 0.9)
        try store.saveQuiz(lessonID: lesson.id, correct: 2, total: 3)
        let reloaded = StudyStore(fileURL: url)
        XCTAssertEqual(reloaded.lesson(lesson.id)?.flashcards.first?.stability ?? 0, FSRS.parameters[3], accuracy: 0.0001)
        XCTAssertEqual(reloaded.attempts.first?.correct, 2)
        XCTAssertEqual(reloaded.reviewEvents.count, 1, "Each flip must be logged for the weekly report")
        XCTAssertThrowsError(try store.saveQuiz(lessonID: lesson.id, correct: 5, total: 3))
    }

    @MainActor func testCustomSubjectsLifecycleAndMigration() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let url = directory.appending(path: "library.json")
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = StudyStore(fileURL: url)
        XCTAssertEqual(store.subjects.count, Subject.builtIns.count, "Fresh libraries contain only built-ins")
        XCTAssertThrowsError(try store.removeSubject(id: Subject.math.id), "Built-ins must not be deletable")

        try store.addSubject(name: "Tin học", symbolName: "cpu", colorIndex: 2)
        let custom = try XCTUnwrap(store.subjects.first { $0.name == "Tin học" })
        try store.add(title: "Bài Tin", subject: custom, text: "Content", source: "Vở")
        XCTAssertEqual(store.lessons.first?.subject.name, "Tin học")

        var renamed = custom
        renamed.name = "Tin học 2"
        renamed.symbolName = "keyboard"
        try store.updateSubject(renamed)
        XCTAssertEqual(store.lessons.first?.subject.name, "Tin học 2", "Renaming must migrate existing lessons")

        let reloaded = StudyStore(fileURL: url)
        XCTAssertEqual(reloaded.customSubjects.count, 1)
        XCTAssertEqual(reloaded.customSubjects.first?.symbolName, "keyboard", "Custom subjects must persist")
        XCTAssertEqual(reloaded.lessons.first?.subject.name, "Tin học 2")

        try reloaded.removeSubject(id: renamed.id)
        XCTAssertEqual(reloaded.lessons.first?.subject, Subject.other, "Deleting a subject moves lessons to Other")
        XCTAssertEqual(StudyStore(fileURL: url).subjects.count, Subject.builtIns.count)
    }

    @MainActor func testBuiltInSubjectsCanBeOverriddenAndReset() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let url = directory.appending(path: "library.json")
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = StudyStore(fileURL: url)
        try store.add(title: "Bài Toán", subject: .math, text: "Content", source: "Vở")

        var mathOverride = Subject.math
        mathOverride.name = "Toán nâng cao"
        mathOverride.symbolName = "x.squareroot"
        mathOverride.colorIndex = 3
        try store.updateSubject(mathOverride)

        let shown = store.subjects.first { $0.id == Subject.math.id }
        XCTAssertEqual(shown?.title, "Toán nâng cao", "Built-in overrides must surface in the folder list")
        XCTAssertEqual(shown?.symbolName, "x.squareroot")
        XCTAssertEqual(store.lessons.first?.subject.title, "Toán nâng cao", "Existing lessons must pick up the override")
        XCTAssertEqual(Subject.suggest(for: "phương trình bậc hai").id, Subject.math.id,
                       "Keyword suggestions still return the built-in folder id")

        let reloaded = StudyStore(fileURL: url)
        XCTAssertEqual(reloaded.subjectOverrides.count, 1, "Overrides must persist")
        XCTAssertEqual(reloaded.subjects.first?.title, "Toán nâng cao")

        try reloaded.resetSubject(id: Subject.math.id)
        let restored = reloaded.subjects.first { $0.id == Subject.math.id }
        XCTAssertEqual(restored, Subject.math, "Resetting must return the pristine built-in")
        XCTAssertEqual(reloaded.lessons.first?.subject, Subject.math, "Lessons must migrate back on reset")
        XCTAssertTrue(StudyStore(fileURL: url).subjectOverrides.isEmpty)
        XCTAssertThrowsError(try reloaded.updateSubject(Subject(id: "ghost", name: "X", symbolName: "book", colorIndex: 0)),
                             "Unknown ids must be rejected")
    }

    func testSymbolCatalogOnlyListsRenderableIcons() {
        let available = SubjectIconCatalog.available
        XCTAssertFalse(available.isEmpty)
        XCTAssertTrue(available.allSatisfy { UIImage(systemName: $0) != nil },
                      "The picker must never list a symbol the OS cannot draw")
        XCTAssertTrue(available.contains("function"))
        XCTAssertTrue(available.contains("atom"))
        XCTAssertEqual(Subject(id: "x", name: "", symbolName: "definitely-not-a-real-symbol", colorIndex: -1).effectiveSymbol,
                       "folder", "Unrenderable symbols must fall back to a folder")
        XCTAssertNotNil(UIImage(systemName: Subject.math.effectiveSymbol))
    }
}
