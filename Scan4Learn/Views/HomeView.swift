import SwiftUI

struct HomeView: View {
    @Environment(StudyStore.self) private var store
    @Environment(AppSettings.self) private var appSettings
    let addLesson: () -> Void
    let openLibrary: () -> Void
    @State private var settings = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 9) {
                        Eyebrow(text: String(localized: "Study corner"))
                        Text("One day at a time,\nunderstand a little more.").font(.system(.largeTitle, design: .rounded, weight: .bold)).tracking(-1)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "sparkle").font(.system(size: 29, weight: .light)).foregroundStyle(.secondary).padding(.top, 24)
                }

                focusCard

                HStack(spacing: 12) {
                    statistic(value: store.lessons.count, label: String(localized: "lessons in library"), symbol: "books.vertical")
                    statistic(value: store.allCards, label: String(localized: "flashcards"), symbol: "rectangle.on.rectangle")
                }

                VStack(alignment: .leading, spacing: 14) {
                    SectionTitle(title: String(localized: "From notebook pages to memory"))
                    Button(action: addLesson) {
                        HStack(spacing: 16) {
                            Image(systemName: "viewfinder").font(.system(size: 30, weight: .light)).foregroundStyle(appSettings.theme.accent)
                                .frame(width: 64, height: 64).background(appSettings.theme.glow, in: RoundedRectangle(cornerRadius: 20))
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Add today's lesson").font(.headline)
                                Text("Scan notes, Word or PDF").font(.subheadline).foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "plus").font(.title3)
                        }.studyCard()
                    }.buttonStyle(.plain)
                }

                VStack(spacing: 14) {
                    HStack {
                        SectionTitle(title: String(localized: "Recent lessons"))
                        Button("All", action: openLibrary).font(.caption.weight(.semibold))
                    }
                    if store.lessons.isEmpty {
                        ContentUnavailableView("Your first page", systemImage: "book.closed", description: Text("Add a lesson to start building your library."))
                    } else {
                        ForEach(store.lessons.prefix(3)) { lesson in
                            NavigationLink { LessonDetailView(lessonID: lesson.id) } label: { LessonRow(lesson: lesson) }.buttonStyle(.plain)
                        }
                    }
                }
                Text("LEARN TO UNDERSTAND, REMEMBER TO APPLY.").font(.system(size: 10, weight: .medium, design: .monospaced))
                    .tracking(2).foregroundStyle(.tertiary).frame(maxWidth: .infinity).padding(.vertical, 8)
            }.padding(20)
        }
        .studyPage().navigationTitle("Scan4Learn").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Settings", systemImage: "slider.horizontal.3") { settings = true }
            }
        }
        .sheet(isPresented: $settings) { NavigationStack { SettingsView() } }
    }

    private var focusCard: some View {
        VStack(alignment: .leading, spacing: 22) {
            Label("A LITTLE REVIEW", systemImage: "sun.max")
                .font(.system(.caption2, design: .monospaced, weight: .semibold)).tracking(1)
                .foregroundStyle(appSettings.theme.glow)
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("\(store.dueCount)").font(.system(size: 66, weight: .medium, design: .rounded)).contentTransition(.numericText())
                Text("\(store.dueCount) cards waiting\nfor your review").font(.subheadline).foregroundStyle(.white.opacity(0.75))
                Spacer()
                Image(systemName: "rectangle.on.rectangle.angled").font(.system(size: 40, weight: .ultraLight)).rotationEffect(.degrees(-10)).foregroundStyle(appSettings.theme.glow)
                    .accessibilityHidden(true)
            }
            if store.dueCount > 0 {
                NavigationLink { FlashcardSessionView(lessonID: nil) } label: {
                    HStack { Text("Review now"); Spacer(); Image(systemName: "arrow.up.right") }
                        .font(.headline).padding(16).foregroundStyle(appSettings.theme.accent)
                        .background(appSettings.theme.glow, in: Capsule())
                }.buttonStyle(.plain)
            } else {
                Label("All due cards reviewed", systemImage: "checkmark.circle").font(.headline).foregroundStyle(appSettings.theme.glow)
            }
        }.padding(24).background(appSettings.theme.accent, in: RoundedRectangle(cornerRadius: 30)).foregroundStyle(.white)
    }

    private func statistic(value: Int, label: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack { Image(systemName: symbol).foregroundStyle(.secondary); Spacer(); Text(String(format: "%02d", value)).font(.title2.weight(.semibold)) }
            Text(label).font(.caption).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity).studyCard()
    }
}
