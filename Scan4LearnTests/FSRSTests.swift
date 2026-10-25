import XCTest
@testable import Scan4Learn

final class FSRSTests: XCTestCase {
    private func fixedDate() -> Date { Date(timeIntervalSince1970: 1_700_000_000) }
    private func fixedCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    func testIntervalMatchesStabilityAtNinetyPercentRetention() {
        // At 90% retention the interval equals the stability by construction.
        XCTAssertEqual(FSRS.interval(stability: 3.173, retention: 0.9), 3.173, accuracy: 0.001)
        XCTAssertEqual(FSRS.interval(stability: 25, retention: 0.9), 25, accuracy: 0.001)
    }

    func testHigherRetentionMeansLongerIntervals() {
        let at95 = FSRS.interval(stability: 10, retention: 0.95)
        let at90 = FSRS.interval(stability: 10, retention: 0.9)
        let at80 = FSRS.interval(stability: 10, retention: 0.8)
        XCTAssertGreaterThan(at95, 0)
        XCTAssertLessThan(at95, at90)
        XCTAssertLessThan(at90, at80)
        XCTAssertLessThanOrEqual(at80, FSRS.maximumIntervalDays)
    }

    func testNewCardsUseInitialStabilityForEachRating() {
        let now = fixedDate()
        let calendar = fixedCalendar()
        let good = FSRS.review(Flashcard(front: "Q", back: "A"), rating: .good, now: now, calendar: calendar)
        XCTAssertEqual(good.stability, FSRS.parameters[2], accuracy: 0.0001)
        XCTAssertEqual(good.state, .review)
        XCTAssertEqual(good.dueDate.timeIntervalSince(now), 3 * 86_400, accuracy: 60, "Good on a new card is due in ~3 days")

        let easy = FSRS.review(Flashcard(front: "Q", back: "A"), rating: .easy, now: now, calendar: calendar)
        XCTAssertEqual(easy.stability, FSRS.parameters[3], accuracy: 0.0001)
        XCTAssertEqual(easy.dueDate.timeIntervalSince(now), 16 * 86_400, accuracy: 60, "Easy on a new card is due in ~16 days")

        let hard = FSRS.review(Flashcard(front: "Q", back: "A"), rating: .hard, now: now, calendar: calendar)
        XCTAssertEqual(hard.stability, FSRS.parameters[1], accuracy: 0.0001)
        XCTAssertEqual(hard.state, .review)

        let again = FSRS.review(Flashcard(front: "Q", back: "A"), rating: .again, now: now, calendar: calendar)
        XCTAssertEqual(again.stability, FSRS.parameters[0], accuracy: 0.0001)
        XCTAssertEqual(again.state, .learning, "Forgotten new cards stay in learning")
        XCTAssertLessThan(again.dueDate.timeIntervalSince(now), 86_400, "Again on a new card returns the same day")
    }

    func testSuccessfulReviewsGrowStability() {
        let calendar = fixedCalendar()
        let start = fixedDate()
        var card = FSRS.review(Flashcard(front: "Q", back: "A"), rating: .good, now: start, calendar: calendar)
        let firstStability = card.stability
        // Review again exactly when due.
        card = FSRS.review(card, rating: .good, now: card.dueDate, calendar: calendar)
        XCTAssertGreaterThan(card.stability, firstStability * 2, "A good review must grow stability substantially")
        XCTAssertEqual(card.state, .review)
    }

    func testForgettingDropsStabilityAndInterval() {
        let calendar = fixedCalendar()
        let start = fixedDate()
        var card = FSRS.review(Flashcard(front: "Q", back: "A"), rating: .good, now: start, calendar: calendar)
        card = FSRS.review(card, rating: .good, now: card.dueDate, calendar: calendar)
        let strongInterval = card.dueDate.timeIntervalSince(start)
        let strongStability = card.stability

        card = FSRS.review(card, rating: .again, now: card.dueDate, calendar: calendar)
        XCTAssertLessThan(card.stability, strongStability, "Forgetting must shrink stability")
        let forgetInterval = card.dueDate.timeIntervalSince(card.lastReview ?? start)
        XCTAssertLessThan(forgetInterval, strongInterval)
    }

    func testSameDayReviewsUseShortTermStability() {
        let calendar = fixedCalendar()
        let start = fixedDate()
        var card = FSRS.review(Flashcard(front: "Q", back: "A"), rating: .good, now: start, calendar: calendar)
        // Review one hour later, still the same day.
        let before = card.stability
        card = FSRS.review(card, rating: .good, now: start.addingTimeInterval(3_600), calendar: calendar)
        let expected = before * exp(FSRS.parameters[17] * (3 - 3 + FSRS.parameters[18]))
        XCTAssertEqual(card.stability, expected, accuracy: 0.0001)
    }

    func testDifficultyStaysBoundedAndTracksRatings() {
        let calendar = fixedCalendar()
        let start = fixedDate()
        var easy = FSRS.review(Flashcard(front: "Q", back: "A"), rating: .easy, now: start, calendar: calendar)
        for _ in 0..<10 { easy = FSRS.review(easy, rating: .easy, now: easy.dueDate, calendar: calendar) }
        var hard = FSRS.review(Flashcard(front: "Q", back: "A"), rating: .again, now: start, calendar: calendar)
        for _ in 0..<10 { hard = FSRS.review(hard, rating: .again, now: hard.dueDate, calendar: calendar) }
        XCTAssertGreaterThanOrEqual(easy.difficulty, 1)
        XCTAssertLessThanOrEqual(hard.difficulty, 10)
        XCTAssertLessThan(easy.difficulty, hard.difficulty, "Easy ratings must keep difficulty lower than Again ratings")
    }

    func testLegacyIntervalOnlyCardsMigrateToFSRSFields() throws {
        let due = Date(timeIntervalSince1970: 1_700_100_000)
        let legacy = #"{"front":"Q","back":"A","dueDate":\#(due.timeIntervalSince1970),"intervalDays":6}"#
        let card = try JSONDecoder().decode(Flashcard.self, from: Data(legacy.utf8))
        XCTAssertEqual(card.stability, 6, accuracy: 0.0001)
        XCTAssertEqual(card.difficulty, 5, accuracy: 0.0001)
        XCTAssertEqual(card.state, .review)
        XCTAssertNotNil(card.lastReview)
    }

    func testPreviewIntervalMatchesScheduledDueDate() {
        let card = Flashcard(front: "Q", back: "A")
        let preview = FSRS.previewInterval(card: card, rating: .good, retention: 0.9)
        let scheduled = FSRS.review(card, rating: .good, retention: 0.9).dueDate.timeIntervalSinceNow
        XCTAssertEqual(preview, scheduled, accuracy: 5)
        XCTAssertGreaterThan(preview, 0)
    }

    func testRetentionPolicyChangesScheduling() {
        let card = FSRS.review(Flashcard(front: "Q", back: "A"), rating: .good)
        let relaxed = FSRS.previewInterval(card: card, rating: .good, retention: 0.8)
        let strict = FSRS.previewInterval(card: card, rating: .good, retention: 0.95)
        XCTAssertGreaterThan(relaxed, strict, "Lower target retention must space cards further apart")
    }
}
