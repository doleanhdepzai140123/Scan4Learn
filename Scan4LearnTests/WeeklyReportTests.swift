import XCTest
@testable import Scan4Learn

final class WeeklyReportTests: XCTestCase {
    @MainActor func testWeeklyProgressGatherCountsActivityAndFindsWeakSubjects() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let url = directory.appending(path: "library.json")
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = StudyStore(fileURL: url)
        let lesson = try XCTUnwrap(store.lessons.first)
        let card = try XCTUnwrap(lesson.flashcards.first)

        try store.review(cardID: card.id, lessonID: lesson.id, rating: .good, retention: 0.9)
        try store.saveQuiz(lessonID: lesson.id, correct: 1, total: 4)

        let progress = WeeklyReport.gather(from: store)
        XCTAssertEqual(progress.reviewsCompleted, 1)
        XCTAssertEqual(progress.quizAttempts, 1)
        XCTAssertEqual(progress.quizCorrect, 1)
        XCTAssertFalse(progress.accuracyBySubject.isEmpty)
        XCTAssertEqual(progress.accuracyBySubject.first?.accuracy ?? 0, 0.25, accuracy: 0.0001,
                       "Weak subjects must be sorted first")

        let prompt = WeeklyReport.makePrompt(progress: progress)
        XCTAssertTrue(prompt.contains(lesson.subject.title), "The prompt should mention the studied subject")
        XCTAssertTrue(prompt.contains("25"), "The prompt should include the 25% accuracy figure")
    }

    @MainActor func testWeeklyReportDueLogic() {
        UserDefaults.standard.removeObject(forKey: WeeklyReport.dateKey)
        XCTAssertTrue(WeeklyReport.isDue(), "No report yet means due")
        UserDefaults.standard.set(Date(), forKey: WeeklyReport.dateKey)
        XCTAssertFalse(WeeklyReport.isDue(), "Just generated means not due")
        UserDefaults.standard.set(Date().addingTimeInterval(-7 * 86_400), forKey: WeeklyReport.dateKey)
        XCTAssertTrue(WeeklyReport.isDue(), "A week old means due again")
        UserDefaults.standard.removeObject(forKey: WeeklyReport.dateKey)
        XCTAssertNil(WeeklyReport.lastReport)
    }
}
