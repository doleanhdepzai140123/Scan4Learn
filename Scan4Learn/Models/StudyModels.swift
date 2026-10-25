import Foundation

/// A school subject folder. The six built-ins localize through the string catalog;
/// user-defined subjects carry their own name, SF Symbol and palette colour.
struct Subject: Codable, Hashable, Identifiable {
    var id: String
    /// Empty for built-in subjects; their titles come from the string catalog.
    var name: String
    var symbolName: String
    /// Index into the custom colour palette; negative for built-ins.
    var colorIndex: Int

    var title: String {
        if !name.isEmpty { return name }
        switch id {
        case "math": return String(localized: "Mathematics")
        case "literature": return String(localized: "Literature")
        case "english": return String(localized: "English")
        case "science": return String(localized: "Natural sciences")
        case "historyGeography": return String(localized: "History & Geography")
        default: return String(localized: "Other")
        }
    }

    var symbol: String { symbolName }

    static let math = Subject(id: "math", name: "", symbolName: "function", colorIndex: -1)
    static let literature = Subject(id: "literature", name: "", symbolName: "text.book.closed", colorIndex: -1)
    static let english = Subject(id: "english", name: "", symbolName: "character.bubble", colorIndex: -1)
    static let science = Subject(id: "science", name: "", symbolName: "atom", colorIndex: -1)
    static let historyGeography = Subject(id: "historyGeography", name: "", symbolName: "globe.asia.australia", colorIndex: -1)
    static let other = Subject(id: "other", name: "", symbolName: "folder", colorIndex: -1)
    static var builtIns: [Subject] { [math, literature, english, science, historyGeography, other] }

    enum CodingKeys: String, CodingKey { case id, name, symbolName, colorIndex }

    init(id: String, name: String, symbolName: String, colorIndex: Int) {
        self.id = id
        self.name = name
        self.symbolName = symbolName
        self.colorIndex = colorIndex
    }

    init(from decoder: Decoder) throws {
        // Library v1 stored the subject as the built-in enum's raw value.
        if let single = try? decoder.singleValueContainer(), let legacy = try? single.decode(String.self) {
            self = Subject.builtIns.first { $0.id == legacy } ?? Subject.other
            return
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        symbolName = try container.decodeIfPresent(String.self, forKey: .symbolName) ?? "folder"
        colorIndex = try container.decodeIfPresent(Int.self, forKey: .colorIndex) ?? -1
    }
}

/// FSRS-5 card state machine.
enum CardState: String, Codable { case new, learning, review, relearning }

struct Flashcard: Codable, Identifiable, Equatable {
    var id = UUID()
    var front: String
    var back: String
    var dueDate = Date()
    var lastReview: Date?
    var stability: Double = 0
    var difficulty: Double = 0
    var state: CardState = .new

    enum CodingKeys: String, CodingKey {
        case id, front, back, dueDate, lastReview, stability, difficulty, state
        case legacyInterval = "intervalDays"
    }

    init(front: String, back: String) {
        self.front = front
        self.back = back
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        front = try container.decode(String.self, forKey: .front)
        back = try container.decode(String.self, forKey: .back)
        dueDate = try container.decodeIfPresent(Date.self, forKey: .dueDate) ?? Date()
        lastReview = try container.decodeIfPresent(Date.self, forKey: .lastReview)
        stability = try container.decodeIfPresent(Double.self, forKey: .stability) ?? 0
        difficulty = try container.decodeIfPresent(Double.self, forKey: .difficulty) ?? 0
        state = try container.decodeIfPresent(CardState.self, forKey: .state) ?? .new
        // Pre-FSRS cards only stored a plain interval in days. Stability is
        // roughly the interval that keeps retention at 90%, so seed from it.
        if stability == 0, difficulty == 0, state == .new,
           let legacy = try container.decodeIfPresent(Int.self, forKey: .legacyInterval), legacy > 0 {
            stability = max(1, Double(legacy))
            difficulty = 5
            state = .review
            lastReview = dueDate.addingTimeInterval(-Double(legacy) * 86_400)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(front, forKey: .front)
        try container.encode(back, forKey: .back)
        try container.encode(dueDate, forKey: .dueDate)
        try container.encodeIfPresent(lastReview, forKey: .lastReview)
        try container.encode(stability, forKey: .stability)
        try container.encode(difficulty, forKey: .difficulty)
        try container.encode(state, forKey: .state)
    }
}

/// FSRS ratings; `fsrsValue` matches the scheduler's 1–4 scale.
enum ReviewRating: CaseIterable {
    case again, hard, good, easy
    var fsrsValue: Int {
        switch self {
        case .again: 1
        case .hard: 2
        case .good: 3
        case .easy: 4
        }
    }
}

struct PracticeQuestion: Codable, Identifiable {
    var id = UUID()
    var prompt: String
    var options: [String]
    var correctIndex: Int
    var explanation: String

    enum CodingKeys: String, CodingKey { case id, prompt, options, correctIndex, explanation }
}

extension PracticeQuestion {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        prompt = try container.decode(String.self, forKey: .prompt)
        options = try container.decode([String].self, forKey: .options)
        correctIndex = try container.decode(Int.self, forKey: .correctIndex)
        explanation = try container.decode(String.self, forKey: .explanation)
    }
}

struct Lesson: Codable, Identifiable {
    var id = UUID()
    var title: String
    var subject: Subject
    var createdAt = Date()
    var sourceName: String
    var originalText: String
    var summary: [String] = []
    var flashcards: [Flashcard] = []
    var questions: [PracticeQuestion] = []
    var isSample = false
    var isReady: Bool { !summary.isEmpty }
    var dueCards: [Flashcard] { flashcards.filter { $0.dueDate <= Date() } }

    enum CodingKeys: String, CodingKey {
        case id, title, subject, createdAt, sourceName, originalText, summary, flashcards, questions, isSample
    }
}

extension Lesson {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try container.decode(String.self, forKey: .title)
        subject = try container.decode(Subject.self, forKey: .subject)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        sourceName = try container.decode(String.self, forKey: .sourceName)
        originalText = try container.decode(String.self, forKey: .originalText)
        summary = try container.decodeIfPresent([String].self, forKey: .summary) ?? []
        flashcards = try container.decodeIfPresent([Flashcard].self, forKey: .flashcards) ?? []
        questions = try container.decodeIfPresent([PracticeQuestion].self, forKey: .questions) ?? []
        isSample = try container.decodeIfPresent(Bool.self, forKey: .isSample) ?? false
    }
}

struct QuizAttempt: Codable, Identifiable {
    var id = UUID()
    var lessonID: UUID
    var date = Date()
    var correct: Int
    var total: Int

    enum CodingKeys: String, CodingKey { case id, lessonID, date, correct, total }
}

extension QuizAttempt {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        lessonID = try container.decode(UUID.self, forKey: .lessonID)
        date = try container.decodeIfPresent(Date.self, forKey: .date) ?? Date()
        correct = try container.decode(Int.self, forKey: .correct)
        total = try container.decode(Int.self, forKey: .total)
    }
}

/// One flashcard flip, logged so the weekly ChatGPT report can measure activity.
struct ReviewEvent: Codable, Identifiable, Equatable {
    var id = UUID()
    var lessonID: UUID
    var date = Date()
    var ratingValue: Int

    enum CodingKeys: String, CodingKey { case id, lessonID, date, ratingValue }
}

extension ReviewEvent {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        lessonID = try container.decode(UUID.self, forKey: .lessonID)
        date = try container.decodeIfPresent(Date.self, forKey: .date) ?? Date()
        ratingValue = try container.decode(Int.self, forKey: .ratingValue)
    }
}

struct LibrarySnapshot: Codable {
    var version = 2
    var lessons: [Lesson]
    var attempts: [QuizAttempt] = []
    var customSubjects: [Subject] = []
    /// User edits of built-in subjects (same id, custom name/symbol/colour).
    var subjectOverrides: [Subject] = []
    var reviewEvents: [ReviewEvent] = []

    enum CodingKeys: String, CodingKey { case version, lessons, attempts, customSubjects, subjectOverrides, reviewEvents }

    init(lessons: [Lesson], attempts: [QuizAttempt], customSubjects: [Subject],
         subjectOverrides: [Subject], reviewEvents: [ReviewEvent]) {
        self.version = 2
        self.lessons = lessons
        self.attempts = attempts
        self.customSubjects = customSubjects
        self.subjectOverrides = subjectOverrides
        self.reviewEvents = reviewEvents
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        lessons = try container.decode([Lesson].self, forKey: .lessons)
        attempts = try container.decodeIfPresent([QuizAttempt].self, forKey: .attempts) ?? []
        customSubjects = try container.decodeIfPresent([Subject].self, forKey: .customSubjects) ?? []
        subjectOverrides = try container.decodeIfPresent([Subject].self, forKey: .subjectOverrides) ?? []
        reviewEvents = try container.decodeIfPresent([ReviewEvent].self, forKey: .reviewEvents) ?? []
    }
}

enum StudyError: LocalizedError {
    case invalid(String)
    var errorDescription: String? {
        switch self { case .invalid(let message): message }
    }
}

/// The import format contains content only; identity and review dates are owned by the app.
struct StudyPack: Decodable {
    struct Card: Decodable { var front: String; var back: String }
    struct Question: Decodable {
        var prompt: String
        var options: [String]
        var correctIndex: Int
        var explanation: String
    }
    var summary: [String]
    var flashcards: [Card]
    var questions: [Question]

    static func parse(_ text: String) throws -> StudyPack {
        guard text.utf8.count <= 1_000_000 else { throw StudyError.invalid(String(localized: "Content is too large. Import a study pack under 1 MB.")) }
        var json = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if json.hasPrefix("```") {
            var lines = json.components(separatedBy: .newlines)
            guard lines.count >= 3, lines.last?.trimmingCharacters(in: .whitespaces) == "```" else {
                throw StudyError.invalid(String(localized: "The JSON block is incomplete."))
            }
            lines.removeFirst(); lines.removeLast()
            json = lines.joined(separator: "\n")
        }
        let pack: StudyPack
        do { pack = try JSONDecoder().decode(StudyPack.self, from: Data(json.utf8)) }
        catch { throw StudyError.invalid(String(localized: "Couldn't read the JSON. Copy the whole result exactly as requested.")) }
        let nonempty: (String) -> Bool = { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard (1...20).contains(pack.summary.count), pack.summary.allSatisfy(nonempty),
              (1...100).contains(pack.flashcards.count), pack.flashcards.allSatisfy({ nonempty($0.front) && nonempty($0.back) }),
              (1...50).contains(pack.questions.count), pack.questions.allSatisfy({
                  nonempty($0.prompt) && nonempty($0.explanation) && (2...6).contains($0.options.count)
                  && $0.options.allSatisfy(nonempty) && $0.options.indices.contains($0.correctIndex)
              }) else { throw StudyError.invalid(String(localized: "A study pack needs a summary, flashcards and questions with valid answers (answer positions start at 0).")) }
        return pack
    }
}
