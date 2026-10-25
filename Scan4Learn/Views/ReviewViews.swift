import SwiftUI

struct ReviewHubView: View {
    @Environment(StudyStore.self) private var store
    @Environment(AppSettings.self) private var appSettings
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Eyebrow(text: String(localized: "Remember longer, bit by bit"))
                Text("You've studied.\nNow try to recall.").font(.system(.largeTitle, design: .rounded, weight: .bold))
                NavigationLink { FlashcardSessionView(lessonID: nil) } label: {
                    VStack(alignment: .leading, spacing: 18) {
                        Image(systemName: "rectangle.on.rectangle.angled").font(.largeTitle)
                        Text("\(store.dueCount) cards due").font(.title.bold())
                        HStack { Text("Start reviewing").font(.headline); Spacer(); Image(systemName: "arrow.right") }
                    }.foregroundStyle(appSettings.theme.accent).padding(24).frame(maxWidth: .infinity, alignment: .leading)
                        .background(appSettings.theme.glow, in: RoundedRectangle(cornerRadius: 28))
                }.buttonStyle(.plain)
                SectionTitle(title: String(localized: "Practice by lesson"))
                let ready = store.lessons.filter { !$0.questions.isEmpty }
                if ready.isEmpty { ContentUnavailableView("No quizzes yet", systemImage: "pencil.and.list.clipboard", description: Text("Add a study pack to a lesson to begin.")) }
                ForEach(ready) { lesson in
                    NavigationLink { QuizView(lessonID: lesson.id, questions: lesson.questions) } label: { LessonRow(lesson: lesson) }.buttonStyle(.plain)
                }
                if !store.attempts.isEmpty {
                    SectionTitle(title: String(localized: "Recent attempts"))
                    ForEach(store.attempts.prefix(5)) { attempt in
                        HStack {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(store.lesson(attempt.lessonID)?.title ?? String(localized: "Lesson")).font(.subheadline.weight(.semibold))
                                Text(attempt.date.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(attempt.correct)/\(attempt.total)").font(.title3.monospacedDigit().bold())
                        }.studyCard()
                    }
                }
            }.padding(20)
        }.studyPage().navigationTitle("Review")
    }
}

private struct ReviewItem: Identifiable {
    let lessonID: UUID
    let subject: Subject
    let card: Flashcard
    var id: UUID { card.id }
}

struct FlashcardSessionView: View {
    @Environment(StudyStore.self) private var store
    @Environment(AppSettings.self) private var appSettings
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let lessonID: UUID?
    @State private var queue: [ReviewItem] = []
    @State private var index = 0
    @State private var revealed = false
    @State private var loaded = false
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if index < queue.count {
                    let item = queue[index]
                    HStack { Eyebrow(text: item.subject.title); Spacer(); Text("\(index + 1) / \(queue.count)").font(.subheadline.monospacedDigit()).foregroundStyle(.secondary) }
                    ProgressView(value: Double(index), total: Double(max(queue.count, 1))).tint(item.subject.color)
                    Button {
                        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { revealed.toggle() }
                    } label: {
                        VStack(spacing: 28) {
                            Eyebrow(text: revealed ? String(localized: "Answer") : String(localized: "Try to recall"))
                            Spacer(minLength: 24)
                            Text(revealed ? item.card.back : item.card.front).font(.system(.title2, design: .rounded, weight: .semibold)).multilineTextAlignment(.center).lineSpacing(6)
                            Spacer(minLength: 24)
                            Label(revealed ? String(localized: "Tap to see the question") : String(localized: "Tap to flip the card"), systemImage: "arrow.triangle.2.circlepath").font(.caption).foregroundStyle(.secondary)
                        }.padding(28).frame(maxWidth: .infinity, minHeight: 320)
                            .background(revealed ? item.subject.color.opacity(0.12) : Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 30))
                    }.buttonStyle(.plain).accessibilityHint("Shows or hides the answer")
                    if revealed {
                        Text("How well do you remember?").font(.subheadline).foregroundStyle(.secondary)
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 8) { ratingButtons }
                            VStack(spacing: 8) { ratingButtons }
                        }
                    } else {
                        PrimaryButton(title: String(localized: "Show answer"), symbol: "arrow.triangle.2.circlepath") { revealed = true }
                    }
                    if let error { Text(error).font(.footnote).foregroundStyle(.red) }
                } else if loaded {
                    Image(systemName: "checkmark.seal").font(.system(size: 70, weight: .ultraLight)).foregroundStyle(.green).padding(.top, 50)
                    Text(queue.isEmpty ? String(localized: "No cards due") : String(localized: "A little every day.\nYou just did it.")).font(.system(.title, design: .rounded, weight: .bold)).multilineTextAlignment(.center)
                    Text(queue.isEmpty ? String(localized: "Cards will appear when their review is due.") : String(localized: "Progress saved for \(queue.count) cards. Forgotten ones return later today.")).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    PrimaryButton(title: String(localized: "Finish"), symbol: "checkmark") { dismiss() }
                }
            }.padding(24)
        }.studyPage().navigationTitle("Flashcards").navigationBarTitleDisplayMode(.inline)
            .onAppear {
                guard !loaded else { return }
                queue = store.lessons.filter { lessonID == nil || $0.id == lessonID }.flatMap { lesson in
                    lesson.dueCards.map { ReviewItem(lessonID: lesson.id, subject: lesson.subject, card: $0) }
                }.sorted { $0.card.dueDate < $1.card.dueDate }
                loaded = true
            }
    }

    @ViewBuilder private var ratingButtons: some View {
        ratingButton(.again, title: String(localized: "Forgot"), color: .red)
        ratingButton(.hard, title: String(localized: "Hard"), color: .orange)
        ratingButton(.good, title: String(localized: "Remembered"), color: .blue)
        ratingButton(.easy, title: String(localized: "Too easy"), color: .green)
    }

    /// FSRS preview of how long the next wait would be for this rating.
    private func intervalLabel(_ rating: ReviewRating) -> String {
        guard index < queue.count else { return "" }
        let seconds = FSRS.previewInterval(card: queue[index].card, rating: rating, retention: appSettings.targetRetention)
        if seconds < 3_600 { return String(localized: "\(Int(seconds / 60)) min") }
        if seconds < 86_400 { return String(localized: "\(Int(seconds / 3_600)) h") }
        return String(localized: "\(Int(seconds / 86_400)) days")
    }

    private func ratingButton(_ rating: ReviewRating, title: String, color: Color) -> some View {
        Button {
            guard index < queue.count else { return }
            let item = queue[index]
            do {
                try store.review(cardID: item.card.id, lessonID: item.lessonID, rating: rating, retention: appSettings.targetRetention)
                error = nil; revealed = false; index += 1
            } catch { self.error = error.localizedDescription }
        } label: {
            VStack(spacing: 5) { Text(title).font(.subheadline.bold()); Text(intervalLabel(rating)).font(.caption) }
                .frame(maxWidth: .infinity, minHeight: 60).foregroundStyle(color)
                .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 18))
        }.buttonStyle(.plain)
    }
}

struct QuizView: View {
    @Environment(StudyStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let lessonID: UUID
    let questions: [PracticeQuestion]
    @State private var index = 0
    @State private var selected: Int?
    @State private var checked = false
    @State private var score = 0
    @State private var finished = false
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if finished {
                    VStack(spacing: 24) {
                        Image(systemName: "flag.checkered").font(.system(size: 60, weight: .light)).padding(.top, 32)
                        Text("You finished!").font(.system(.title, design: .rounded, weight: .bold))
                        Text("\(score)/\(questions.count)").font(.system(size: 72, weight: .medium, design: .rounded))
                        Text("correct answers").foregroundStyle(.secondary)
                        Text(score == questions.count ? String(localized: "Today's knowledge just got a bit more solid.") : String(localized: "Missed questions point to what to review next.")).multilineTextAlignment(.center).foregroundStyle(.secondary)
                        PrimaryButton(title: String(localized: "Back to lesson"), symbol: "checkmark") { dismiss() }
                    }.frame(maxWidth: .infinity)
                } else if questions.indices.contains(index) {
                    let question = questions[index]
                    HStack { Eyebrow(text: String(localized: "One question at a time")); Spacer(); Text("\(index + 1)/\(questions.count)").font(.subheadline.monospacedDigit()) }
                    ProgressView(value: Double(index), total: Double(questions.count))
                    Text(question.prompt).font(.system(.title2, design: .rounded, weight: .bold)).padding(.vertical, 12)
                    ForEach(question.options.indices, id: \.self) { option in
                        Button { selected = option } label: {
                            HStack(alignment: .top, spacing: 14) {
                                Text(String(UnicodeScalar(65 + option)!)).font(.system(.subheadline, design: .monospaced, weight: .semibold)).frame(width: 30, height: 30)
                                    .background(Color(uiColor: .systemGroupedBackground), in: Circle())
                                Text(question.options[option]).frame(maxWidth: .infinity, alignment: .leading).padding(.top, 4)
                                if checked && option == question.correctIndex { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green) }
                                else if selected == option { Image(systemName: checked ? "xmark.circle.fill" : "circle.inset.filled").foregroundStyle(checked ? .red : .primary) }
                            }.padding(18).background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
                                .overlay(RoundedRectangle(cornerRadius: 20).stroke(borderColor(option, question: question), lineWidth: 2))
                        }.buttonStyle(.plain).disabled(checked)
                            .accessibilityAddTraits(selected == option ? .isSelected : [])
                    }
                    if checked {
                        VStack(alignment: .leading, spacing: 10) {
                            Label(selected == question.correctIndex ? String(localized: "Correct!") : String(localized: "Let's review it"), systemImage: selected == question.correctIndex ? "checkmark.circle" : "lightbulb").font(.headline)
                            Text(question.explanation).lineSpacing(5)
                        }.frame(maxWidth: .infinity, alignment: .leading).studyCard()
                    }
                    PrimaryButton(title: checked
                                  ? (index == questions.count - 1 ? String(localized: "See results") : String(localized: "Next question"))
                                  : String(localized: "Check answer")) {
                        if !checked {
                            guard let selected else { return }
                            if selected == question.correctIndex { score += 1 }
                            checked = true
                        } else if index == questions.count - 1 {
                            do { try store.saveQuiz(lessonID: lessonID, correct: score, total: questions.count); finished = true }
                            catch { self.error = error.localizedDescription }
                        } else { index += 1; selected = nil; checked = false }
                    }.disabled(selected == nil)
                    if let error { Text(error).font(.footnote).foregroundStyle(.red) }
                } else { ContentUnavailableView("No questions", systemImage: "pencil") }
            }.padding(24)
        }.studyPage().navigationTitle("Practice").navigationBarTitleDisplayMode(.inline)
    }

    private func borderColor(_ option: Int, question: PracticeQuestion) -> Color {
        if checked && option == question.correctIndex { return .green }
        if selected == option { return checked ? .red : .primary }
        return .clear
    }
}
