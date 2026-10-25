import SwiftUI

struct LibraryView: View {
    @Environment(StudyStore.self) private var store
    @Environment(AppSettings.self) private var appSettings
    let addLesson: () -> Void
    @State private var search = ""
    @State private var subject: Subject?
    @State private var managingSubjects = false

    private var filtered: [Lesson] {
        store.lessons.filter {
            (subject == nil || $0.subject.id == subject?.id) && (search.isEmpty || $0.title.localizedStandardContains(search) || $0.originalText.localizedStandardContains(search))
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Eyebrow(text: String(localized: "Knowledge that's yours"))
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                    ForEach(store.subjects) { item in
                        Button { withAnimation { subject = subject?.id == item.id ? nil : item } } label: {
                            VStack(alignment: .leading, spacing: 14) {
                                HStack { SubjectIcon(subject: item); Spacer(); if subject?.id == item.id { Image(systemName: "checkmark.circle.fill").foregroundStyle(item.color) } }
                                Text(item.title).font(.subheadline.weight(.semibold)).foregroundStyle(appSettings.theme.ink)
                                Text(String(localized: "\(store.lessons.filter { $0.subject.id == item.id }.count) lessons")).font(.caption).foregroundStyle(.secondary)
                            }.frame(maxWidth: .infinity, alignment: .leading).studyCard()
                                .overlay(RoundedRectangle(cornerRadius: 24).stroke(subject?.id == item.id ? item.color : .clear, lineWidth: 2))
                        }.buttonStyle(.plain).accessibilityAddTraits(subject?.id == item.id ? .isSelected : [])
                    }
                }
                HStack {
                    SectionTitle(title: subject?.title ?? String(localized: "All lessons"), caption: String(localized: "\(filtered.count) found"))
                    if subject != nil { Button("Clear filter") { subject = nil }.font(.caption) }
                }
                if filtered.isEmpty {
                    ContentUnavailableView("No lessons yet", systemImage: "folder", description: Text("Try another search term or add a lesson to this subject."))
                }
                LazyVStack(spacing: 12) {
                    ForEach(filtered) { lesson in
                        NavigationLink { LessonDetailView(lessonID: lesson.id) } label: { LessonRow(lesson: lesson) }.buttonStyle(.plain)
                    }
                }
            }.padding(20)
        }.studyPage().navigationTitle("Library")
            .searchable(text: $search, prompt: "Search titles, content…")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Add lesson", systemImage: "plus", action: addLesson) }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Manage subjects", systemImage: "folder.badge.gearshape") { managingSubjects = true }
                }
            }
            .sheet(isPresented: $managingSubjects) { NavigationStack { SubjectManagerView() } }
    }
}
