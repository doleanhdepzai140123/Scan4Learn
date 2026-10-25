import SwiftUI

@main
struct Scan4LearnApp: App {
    @State private var store = StudyStore()
    @State private var appSettings = AppSettings()

    init() {
        Bundle.applyLanguageSwizzle()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(appSettings)
                .tint(appSettings.theme.ink)
        }
    }
}

struct RootView: View {
    @Environment(StudyStore.self) private var store
    @Environment(AppSettings.self) private var appSettings
    @State private var tab = 0
    @State private var addingLesson = false

    var body: some View {
        TabView(selection: $tab) {
            Tab("Today", systemImage: "square.grid.2x2", value: 0) {
                NavigationStack { HomeView(addLesson: { addingLesson = true }, openLibrary: { tab = 1 }) }
            }
            Tab("Library", systemImage: "books.vertical", value: 1) {
                NavigationStack { LibraryView(addLesson: { addingLesson = true }) }
            }
            Tab("Review", systemImage: "rectangle.on.rectangle.angled", value: 2) {
                NavigationStack { ReviewHubView() }
            }
        }
        // Rebuild the whole tree so every localized string re-renders instantly
        // when the user switches the app language.
        .id(appSettings.language)
        .environment(\.locale, appSettings.locale)
        .sheet(isPresented: $addingLesson) { NavigationStack { AddLessonView() } }
        .alert("Couldn't finish", isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) {
            Button("OK") { store.errorMessage = nil }
        } message: { Text(store.errorMessage ?? "") }
        .task {
            ChatGPTAuth.shared.restore()
            guard ChatGPTAuth.shared.isSignedIn, ChatGPTAuth.shared.isChatGPTPlanGranted,
                  WeeklyReport.isDue() else { return }
            // Weekly coaching report; failures surface silently in Settings.
            _ = try? await WeeklyReport.generate(for: store, thinking: appSettings.prefersThinking)
        }
    }
}

#Preview {
    RootView()
        .environment(StudyStore(fileURL: FileManager.default.temporaryDirectory.appending(path: "Scan4Learn-preview.json")))
        .environment(AppSettings(theme: .ocean))
}
