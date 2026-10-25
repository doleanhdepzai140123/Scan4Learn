import Foundation
import Observation

@MainActor @Observable
final class StudyStore {
    private(set) var lessons: [Lesson] = []
    private(set) var attempts: [QuizAttempt] = []
    private(set) var customSubjects: [Subject] = []
    private(set) var subjectOverrides: [Subject] = []
    private(set) var reviewEvents: [ReviewEvent] = []
    var errorMessage: String?
    private let fileURL: URL
    private var loadFailed = false

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? URL.documentsDirectory.appending(path: "Scan4Learn/library.json")
        do {
            if FileManager.default.fileExists(atPath: self.fileURL.path) {
                let snapshot = try JSONDecoder().decode(LibrarySnapshot.self, from: Data(contentsOf: self.fileURL))
                guard (1...2).contains(snapshot.version) else { throw StudyError.invalid(String(localized: "This library version isn't supported yet.")) }
                lessons = snapshot.lessons
                attempts = snapshot.attempts
                customSubjects = snapshot.customSubjects
                subjectOverrides = snapshot.subjectOverrides
                reviewEvents = snapshot.reviewEvents
            } else {
                lessons = SampleLibrary.lessons
                try persist()
            }
        } catch {
            loadFailed = true
            errorMessage = String(localized: "Couldn't open the library. The original data is kept. \(error.localizedDescription)")
        }
    }

    /// Built-ins with user overrides applied, followed by custom subjects.
    var subjects: [Subject] {
        Subject.builtIns.map { builtIn in subjectOverrides.first { $0.id == builtIn.id } ?? builtIn } + customSubjects
    }

    var dueCount: Int { lessons.reduce(0) { $0 + $1.dueCards.count } }
    var allCards: Int { lessons.reduce(0) { $0 + $1.flashcards.count } }
    func lesson(_ id: UUID) -> Lesson? { lessons.first { $0.id == id } }

    private func persist() throws {
        guard !loadFailed else { throw StudyError.invalid(String(localized: "The library is protected after a read error. Restore your data before saving new lessons.")) }
        let snapshot = LibrarySnapshot(lessons: lessons, attempts: attempts, customSubjects: customSubjects,
                                       subjectOverrides: subjectOverrides, reviewEvents: reviewEvents)
        let data = try JSONEncoder().encode(snapshot)
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
    }

    func add(title: String, subject: Subject, text: String, source: String) throws {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, !text.isEmpty else { throw StudyError.invalid(String(localized: "Add a lesson title and content before saving.")) }
        guard text.count <= 100_000 else { throw StudyError.invalid(String(localized: "The lesson is too long. Split it into parts under 100,000 characters.")) }
        lessons.insert(Lesson(title: title, subject: subject, sourceName: source, originalText: text), at: 0)
        try persist()
    }

    func remove(_ id: UUID) throws {
        lessons.removeAll { $0.id == id }
        attempts.removeAll { $0.lessonID == id }
        reviewEvents.removeAll { $0.lessonID == id }
        try persist()
    }

    func importPack(_ pack: StudyPack, into id: UUID) throws {
        guard let index = lessons.firstIndex(where: { $0.id == id }) else { throw StudyError.invalid(String(localized: "This lesson is no longer in the library.")) }
        lessons[index].summary = pack.summary
        lessons[index].flashcards = pack.flashcards.map { Flashcard(front: $0.front, back: $0.back) }
        lessons[index].questions = pack.questions.map { PracticeQuestion(prompt: $0.prompt, options: $0.options, correctIndex: $0.correctIndex, explanation: $0.explanation) }
        try persist()
    }

    func review(cardID: UUID, lessonID: UUID, rating: ReviewRating, retention: Double) throws {
        guard let lessonIndex = lessons.firstIndex(where: { $0.id == lessonID }),
              let cardIndex = lessons[lessonIndex].flashcards.firstIndex(where: { $0.id == cardID }) else {
            throw StudyError.invalid(String(localized: "Couldn't find the card to save progress."))
        }
        lessons[lessonIndex].flashcards[cardIndex] = FSRS.review(lessons[lessonIndex].flashcards[cardIndex], rating: rating, retention: retention)
        reviewEvents.append(ReviewEvent(lessonID: lessonID, ratingValue: rating.fsrsValue))
        if reviewEvents.count > FSRS.maximumLoggedEvents { reviewEvents.removeFirst(reviewEvents.count - FSRS.maximumLoggedEvents) }
        try persist()
    }

    func saveQuiz(lessonID: UUID, correct: Int, total: Int) throws {
        guard total > 0, (0...total).contains(correct), lesson(lessonID) != nil else {
            throw StudyError.invalid(String(localized: "The quiz result isn't valid."))
        }
        attempts.insert(QuizAttempt(lessonID: lessonID, correct: correct, total: total), at: 0)
        try persist()
    }

    func removeSamples() throws {
        let ids = Set(lessons.filter(\.isSample).map(\.id))
        lessons.removeAll { $0.isSample }
        attempts.removeAll { ids.contains($0.lessonID) }
        try persist()
    }

    // MARK: - Subjects

    func addSubject(name: String, symbolName: String, colorIndex: Int) throws {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw StudyError.invalid(String(localized: "Give the subject a name.")) }
        customSubjects.append(Subject(id: UUID().uuidString, name: name, symbolName: symbolName, colorIndex: colorIndex))
        try persist()
    }

    /// Edits a custom subject or a built-in override and migrates every lesson
    /// that references it, so renamed folders never go stale.
    func updateSubject(_ subject: Subject) throws {
        let isCustom = customSubjects.contains { $0.id == subject.id }
        let isBuiltIn = Subject.builtIns.contains { $0.id == subject.id }
        guard isCustom || isBuiltIn else { throw StudyError.invalid(String(localized: "This subject doesn't exist.")) }
        if isCustom {
            customSubjects = customSubjects.map { $0.id == subject.id ? subject : $0 }
        } else if let index = subjectOverrides.firstIndex(where: { $0.id == subject.id }) {
            subjectOverrides[index] = subject
        } else {
            subjectOverrides.append(subject)
        }
        migrateLessons(to: subject)
        try persist()
    }

    /// Removes a built-in override; custom subjects cannot be reset this way.
    func resetSubject(id: String) throws {
        guard subjectOverrides.contains(where: { $0.id == id }) else { return }
        guard let builtIn = Subject.builtIns.first(where: { $0.id == id }) else { return }
        subjectOverrides.removeAll { $0.id == id }
        migrateLessons(to: builtIn)
        try persist()
    }

    /// Deletes a custom subject; its lessons move to the generic folder.
    func removeSubject(id: String) throws {
        guard customSubjects.contains(where: { $0.id == id }) else {
            throw StudyError.invalid(String(localized: "Built-in subjects can't be deleted."))
        }
        customSubjects.removeAll { $0.id == id }
        for index in lessons.indices where lessons[index].subject.id == id {
            lessons[index].subject = Subject.other
        }
        try persist()
    }

    private func migrateLessons(to subject: Subject) {
        for index in lessons.indices where lessons[index].subject.id == subject.id {
            lessons[index].subject = subject
        }
    }
}
