import Foundation

/// Sends the trailing week of study progress to ChatGPT and keeps the coaching
/// answer for the Settings screen. Runs automatically about once a week.
enum WeeklyReport {
    static let textKey = "weeklyReportText"
    static let dateKey = "weeklyReportDate"

    struct Progress {
        var reviewsCompleted: Int
        var cardsTotal: Int
        var cardsDue: Int
        var lessonsAdded: Int
        var quizAttempts: Int
        var quizCorrect: Int
        var accuracyBySubject: [(subject: String, accuracy: Double, attempts: Int)]
    }

    /// Study statistics for the trailing seven days.
    @MainActor
    static func gather(from store: StudyStore, now: Date = Date()) -> Progress {
        let week = now.addingTimeInterval(-7 * 86_400)
        let reviews = store.reviewEvents.filter { $0.date >= week }.count
        let newLessons = store.lessons.filter { $0.createdAt >= week }.count
        let attempts = store.attempts.filter { $0.date >= week }
        var bySubject: [String: (correct: Int, total: Int)] = [:]
        for attempt in attempts {
            let title = store.lesson(attempt.lessonID)?.subject.title ?? String(localized: "Other")
            var current = bySubject[title] ?? (correct: 0, total: 0)
            current.correct += attempt.correct
            current.total += attempt.total
            bySubject[title] = current
        }
        var accuracy: [(subject: String, accuracy: Double, attempts: Int)] = []
        for (title, tally) in bySubject {
            let ratio: Double = tally.total > 0 ? Double(tally.correct) / Double(tally.total) : 0
            accuracy.append((subject: title, accuracy: ratio, attempts: tally.total))
        }
        accuracy.sort { lhs, rhs in
            if lhs.accuracy == rhs.accuracy { return lhs.attempts > rhs.attempts }
            return lhs.accuracy < rhs.accuracy
        }
        return Progress(
            reviewsCompleted: reviews,
            cardsTotal: store.allCards,
            cardsDue: store.dueCount,
            lessonsAdded: newLessons,
            quizAttempts: attempts.count,
            quizCorrect: attempts.reduce(0) { $0 + $1.correct },
            accuracyBySubject: accuracy
        )
    }

    static func makePrompt(progress: Progress) -> String {
        let weakest = progress.accuracyBySubject.prefix(2)
            .map { String(localized: "\(Int($0.accuracy * 100))%% \(String($0.subject))") }
            .joined(separator: ", ")
        var lines: [String] = [
            String(localized: "This is a student's study progress for the past 7 days. Point out weak areas and give 3–5 short, concrete tips, including what to do next week. Write in the same language as the progress description below and return plain text only."),
            String(localized: "Figures: \(progress.reviewsCompleted) card reviews, \(progress.quizAttempts) quizzes with \(progress.quizCorrect) correct answers, \(progress.lessonsAdded) new lessons, \(progress.cardsDue) cards due out of \(progress.cardsTotal) total.")
        ]
        if !weakest.isEmpty {
            lines.append(String(localized: "Weakest results by subject: \(weakest)."))
        }
        return lines.joined(separator: "\n")
    }

    @MainActor
    static func generate(for store: StudyStore, thinking: Bool) async throws -> String {
        let prompt = makePrompt(progress: gather(from: store))
        let answer = try await ChatGPTClient.shared.complete(prompt: prompt, thinking: thinking)
        UserDefaults.standard.set(answer, forKey: textKey)
        UserDefaults.standard.set(Date(), forKey: dateKey)
        return answer
    }

    static func isDue(now: Date = Date()) -> Bool {
        guard let last = UserDefaults.standard.object(forKey: dateKey) as? Date else { return true }
        return now.timeIntervalSince(last) > 6.5 * 86_400
    }

    static var lastReport: (date: Date, text: String)? {
        guard let date = UserDefaults.standard.object(forKey: dateKey) as? Date,
              let text = UserDefaults.standard.string(forKey: textKey) else { return nil }
        return (date, text)
    }
}
