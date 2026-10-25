import SwiftUI

struct LessonDetailView: View {
    @Environment(StudyStore.self) private var store
    @Environment(AppSettings.self) private var appSettings
    @Environment(\.dismiss) private var dismiss
    let lessonID: UUID
    @State private var section = 0
    @State private var importResult = false
    @State private var deleting = false
    @State private var thinking = true
    @State private var generating = false
    @State private var generationError: String?

    var body: some View {
        Group {
            if let lesson = store.lesson(lessonID) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        HStack { SubjectIcon(subject: lesson.subject); VStack(alignment: .leading, spacing: 5) { Eyebrow(text: lesson.subject.title); Text(lesson.isSample ? String(localized: "Sample lesson") : lesson.createdAt.formatted(date: .abbreviated, time: .omitted)).font(.caption).foregroundStyle(.secondary) } }
                        Text(lesson.title).font(.system(.largeTitle, design: .rounded, weight: .bold))
                        Picker("Content", selection: $section) { Text("Condensed").tag(0); Text("Original").tag(1) }.pickerStyle(.segmented)
                        if section == 1 {
                            VStack(alignment: .leading, spacing: 14) {
                                Label(lesson.sourceName, systemImage: "doc.text").font(.caption).foregroundStyle(.secondary)
                                Text(lesson.originalText).font(.body).lineSpacing(7).textSelection(.enabled)
                            }.frame(maxWidth: .infinity, alignment: .leading).studyCard()
                        } else if lesson.isReady {
                            VStack(alignment: .leading, spacing: 20) {
                                Label("What to remember", systemImage: "sparkles").font(.headline)
                                ForEach(Array(lesson.summary.enumerated()), id: \.offset) { index, point in
                                    HStack(alignment: .top, spacing: 12) {
                                        Text(String(format: "%02d", index + 1)).font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary).padding(.top, 3)
                                        Text(point).font(.body).lineSpacing(5)
                                    }
                                }
                            }.frame(maxWidth: .infinity, alignment: .leading).studyCard()
                            SectionTitle(title: String(localized: "Turn knowledge into memory"))
                            NavigationLink { FlashcardSessionView(lessonID: lesson.id) } label: {
                                studyAction(String(localized: "Flip flashcards"), detail: String(localized: "\(lesson.dueCards.count) cards due · \(lesson.flashcards.count) total"), symbol: "rectangle.on.rectangle.angled", color: appSettings.theme.glow)
                            }.buttonStyle(.plain).disabled(lesson.flashcards.isEmpty)
                            NavigationLink { QuizView(lessonID: lesson.id, questions: lesson.questions) } label: {
                                studyAction(String(localized: "Give it a try"), detail: String(localized: "\(lesson.questions.count) questions · With explanations"), symbol: "pencil.and.list.clipboard", color: Color.blue.opacity(0.15))
                            }.buttonStyle(.plain).disabled(lesson.questions.isEmpty)
                            InfoNote(text: lesson.isSample
                                     ? String(localized: "This sample study pack was pre-made to try the app.")
                                     : String(localized: "This study pack was imported from content you provided. Cross-check answers with your documents and lessons."))
                        } else {
                            VStack(alignment: .leading, spacing: 16) {
                                Image(systemName: "sparkles").font(.largeTitle).foregroundStyle(lesson.subject.color)
                                Text("The lesson has a home.\nNow it's time to understand it.").font(.title2.bold())
                                Text("The lesson is stored in the \(lesson.subject.title) folder. Automatic ChatGPT connection isn't in this version; you can take the prompt to ChatGPT and import the result back.").font(.subheadline).foregroundStyle(.secondary)
                            }.studyCard()
                        }
                        if !lesson.isSample {
                            VStack(alignment: .leading, spacing: 14) {
                                SectionTitle(title: String(localized: "Build a study pack with ChatGPT"))
                                if ChatGPTAuth.shared.isSignedIn {
                                    Picker(String(localized: "Thinking mode"), selection: $thinking) {
                                        Text("Thinking").tag(true)
                                        Text("Standard").tag(false)
                                    }.pickerStyle(.segmented)
                                    if generating {
                                        HStack(spacing: 12) { ProgressView(); Text("Building the study pack…").font(.subheadline) }.studyCard()
                                    } else {
                                        PrimaryButton(title: String(localized: "Build now with ChatGPT"), symbol: "wand.and.stars") {
                                            Task { await generatePack(for: lesson) }
                                        }
                                    }
                                    if let generationError { Text(generationError).font(.footnote).foregroundStyle(.red) }
                                    Text("1. Share or copy the prompt.\n2. Open ChatGPT, choose Thinking if your account supports it, then send.\n3. Copy the returned JSON and import it into the app.").font(.subheadline).lineSpacing(5).foregroundStyle(.secondary)
                                    ShareLink(item: StudyPrompt.make(for: lesson)) {
                                        Label("Share the study-pack prompt", systemImage: "square.and.arrow.up").font(.headline).frame(maxWidth: .infinity, minHeight: 44)
                                    }.buttonStyle(.glass)
                                } else {
                                    Text("Sign in to ChatGPT in Settings for automatic packs, or carry the prompt to ChatGPT manually.").font(.subheadline).foregroundStyle(.secondary)
                                    ShareLink(item: StudyPrompt.make(for: lesson)) {
                                        Label("Share the study-pack prompt", systemImage: "square.and.arrow.up").font(.headline).frame(maxWidth: .infinity, minHeight: 44)
                                    }.buttonStyle(.glass)
                                }
                                PrimaryButton(title: lesson.isReady ? String(localized: "Import a new pack") : String(localized: "Import ChatGPT result"), symbol: "square.and.arrow.down") { importResult = true }
                            }.padding(.top, 4)
                        }
                    }.padding(20)
                }
            } else { ContentUnavailableView("Lesson not found", systemImage: "doc.questionmark") }
        }.studyPage().navigationTitle("Lesson").navigationBarTitleDisplayMode(.inline)
            .onAppear { thinking = appSettings.prefersThinking }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu("Options", systemImage: "ellipsis") { Button("Delete lesson", systemImage: "trash", role: .destructive) { deleting = true } }
                }
            }
            .confirmationDialog("Delete this lesson and its review progress?", isPresented: $deleting, titleVisibility: .visible) {
                Button("Delete lesson", role: .destructive) {
                    do { try store.remove(lessonID); dismiss() } catch { store.errorMessage = error.localizedDescription }
                }
            }
            .sheet(isPresented: $importResult) { NavigationStack { ImportStudyPackView(lessonID: lessonID) } }
    }

    /// Builds the study pack in place through the signed-in ChatGPT plan.
    private func generatePack(for lesson: Lesson) async {
        generating = true
        generationError = nil
        defer { generating = false }
        do {
            appSettings.prefersThinking = thinking
            let answer = try await ChatGPTClient.shared.complete(prompt: StudyPrompt.make(for: lesson), thinking: thinking)
            let pack = try StudyPack.parse(answer)
            try store.importPack(pack, into: lesson.id)
        } catch {
            generationError = error.localizedDescription
        }
    }

    private func studyAction(_ title: String, detail: String, symbol: String, color: Color) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol).font(.title2).frame(width: 50, height: 56).background(color, in: RoundedRectangle(cornerRadius: 16)).foregroundStyle(appSettings.theme.accent)
            VStack(alignment: .leading, spacing: 7) { Text(title).font(.headline); Text(detail).font(.caption).foregroundStyle(.secondary) }
            Spacer(minLength: 0)
            Image(systemName: "arrow.up.right")
        }.studyCard()
    }
}

struct ImportStudyPackView: View {
    @Environment(StudyStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let lessonID: UUID
    @State private var json = ""
    @State private var error: String?
    @State private var confirmReplacement = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Bring the knowledge\nback to your library.").font(.system(.title, design: .rounded, weight: .bold))
                Text("Paste the entire JSON returned by ChatGPT. The app validates the data before creating the summary, flashcards and quiz.").font(.subheadline).foregroundStyle(.secondary)
                TextEditor(text: $json).font(.system(.footnote, design: .monospaced)).frame(minHeight: 300).padding(12)
                    .scrollContentBackground(.hidden).background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20)).accessibilityLabel("JSON result from ChatGPT")
                if let error { Text(error).foregroundStyle(.red).font(.footnote) }
                PrimaryButton(title: String(localized: "Save study pack"), symbol: "checkmark") {
                    if store.lesson(lessonID)?.isReady == true { confirmReplacement = true } else { save() }
                }.disabled(json.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }.padding(20)
        }.studyPage().navigationTitle("Import study pack").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
            .confirmationDialog("Replace the current study pack? The flashcard review schedule will restart.", isPresented: $confirmReplacement, titleVisibility: .visible) {
                Button("Replace pack", role: .destructive) { save() }
            }
    }
    private func save() {
        do { try store.importPack(StudyPack.parse(json), into: lessonID); dismiss() }
        catch { self.error = error.localizedDescription }
    }
}
