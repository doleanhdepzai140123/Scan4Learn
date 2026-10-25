import Foundation

/// FSRS-5 spaced repetition scheduler, following the open-spaced-repetition
/// reference implementation with its default parameters.
enum FSRS {
    static let parameters: [Double] = [
        0.40255, 1.18385, 3.173, 15.69105, 7.1949, 0.5345, 1.4604, 0.0046,
        1.54575, 0.1192, 1.01925, 1.9395, 0.11, 0.29605, 2.2698, 0.2315,
        2.9898, 0.51655, 0.6621
    ]
    static let decay = -0.5
    static let factor = 19.0 / 81.0
    static let maximumIntervalDays = 365.0
    static let minimumSameDayMinutes = 5.0
    static let maximumLoggedEvents = 500

    /// Probability the card is still remembered after `elapsedDays`.
    static func forgettingCurve(elapsedDays: Double, stability: Double) -> Double {
        guard stability > 0 else { return 0 }
        return pow(1 + factor * max(0, elapsedDays) / stability, decay)
    }

    /// Days until retrievability drops to `retention`.
    static func interval(stability: Double, retention: Double) -> Double {
        guard stability > 0, retention > 0, retention < 1 else { return 0 }
        let days = stability / factor * (pow(retention, 1 / decay) - 1)
        return min(max(days, 0), maximumIntervalDays)
    }

    static func initialDifficulty(rating: Int) -> Double {
        clamp(parameters[4] - exp(parameters[5] * Double(rating - 1)) + 1, 1, 10)
    }

    private static func nextDifficulty(current: Double, rating: Int) -> Double {
        let delta = -parameters[6] * Double(rating - 3)
        let damped = current + delta * (10 - current) / 9
        return clamp(parameters[7] * initialDifficulty(rating: 4) + (1 - parameters[7]) * damped, 1, 10)
    }

    /// Applies one review and returns the updated card.
    static func review(_ card: Flashcard, rating: ReviewRating, now: Date = Date(),
                       calendar: Calendar = .current, retention: Double = 0.9) -> Flashcard {
        var card = card
        let priorState = card.state
        let value = rating.fsrsValue
        let elapsedDays = card.lastReview.map { now.timeIntervalSince($0) / 86_400 } ?? 0
        let sameDay = elapsedDays < 1 && priorState != .new

        if priorState == .new {
            card.stability = parameters[value - 1]
            card.difficulty = initialDifficulty(rating: value)
        } else if sameDay {
            // Short-term stability formula for repeated reviews within one day.
            card.stability = card.stability * exp(parameters[17] * (Double(value) - 3 + parameters[18]))
            card.difficulty = nextDifficulty(current: card.difficulty, rating: value)
        } else {
            card.difficulty = nextDifficulty(current: card.difficulty, rating: value)
            let retrievability = forgettingCurve(elapsedDays: elapsedDays, stability: card.stability)
            if rating == .again {
                let recallDrop = (pow(card.stability + 1, parameters[13]) - 1) * exp(parameters[14] * (1 - retrievability))
                card.stability = parameters[11] * pow(card.difficulty, -parameters[12]) * recallDrop
            } else {
                let hardPenalty = rating == .hard ? parameters[15] : 1
                let easyBonus = rating == .easy ? parameters[16] : 1
                let growth = exp(parameters[8]) * (11 - card.difficulty) * pow(card.stability, -parameters[9]) * (exp(parameters[10] * (1 - retrievability)) - 1) * hardPenalty * easyBonus
                card.stability = card.stability * (1 + growth)
            }
        }

        card.lastReview = now
        card.stability = max(0.01, card.stability)
        let days = interval(stability: card.stability, retention: retention)
        if days >= 1 {
            let whole = max(1, Int(days.rounded()))
            card.dueDate = calendar.date(byAdding: .day, value: whole, to: now)
                ?? now.addingTimeInterval(Double(whole) * 86_400)
            card.state = .review
        } else {
            let minutes = max(minimumSameDayMinutes, (days * 1_440).rounded())
            card.dueDate = now.addingTimeInterval(minutes * 60)
            card.state = (priorState == .new || priorState == .learning) ? .learning : .relearning
        }
        return card
    }

    /// Seconds until the next review for a hypothetical rating; used for button previews.
    static func previewInterval(card: Flashcard, rating: ReviewRating, retention: Double = 0.9, now: Date = Date()) -> TimeInterval {
        review(card, rating: rating, now: now, retention: retention).dueDate.timeIntervalSince(now)
    }

    private static func clamp(_ value: Double, _ lower: Double, _ upper: Double) -> Double {
        min(max(value, lower), upper)
    }
}

extension Subject {
    /// Local keyword suggestion only. The student confirms the folder before saving.
    static func suggest(for text: String) -> Subject {
        // Unicode diacritic folding does not transliterate Vietnamese đ to d.
        let normalized = text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "vi_VN"))
            .replacingOccurrences(of: "đ", with: "d")
        let scores = SubjectKeywords.all.map { entry -> (Subject, Int) in
            let subject = Subject.builtIns.first { $0.id == entry.id } ?? Subject.other
            return (subject, entry.keywords.filter { normalized.contains($0) }.count)
        }
        guard let top = scores.max(by: { $0.1 < $1.1 }), top.1 > 0,
              scores.filter({ $0.1 == top.1 }).count == 1 else { return Subject.other }
        return top.0
    }
}
