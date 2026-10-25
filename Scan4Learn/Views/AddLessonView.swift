import SwiftUI
import PhotosUI
import VisionKit
import UniformTypeIdentifiers

struct AddLessonView: View {
    @Environment(StudyStore.self) private var store
    @Environment(AppSettings.self) private var appSettings
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var subject: Subject = .other
    @State private var content = ""
    @State private var sourceParts: [String] = []
    @State private var photos: [PhotosPickerItem] = []
    @State private var showScanner = false
    @State private var showFiles = false
    @State private var busy = false
    @State private var error: String?
    @State private var suggestion: Subject?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Eyebrow(text: String(localized: "01 / Collect knowledge"))
                    Text("A new lesson,\none more thing understood.").font(.system(.title, design: .rounded, weight: .bold))
                    Text("Scan a notebook page or bring your document here.").font(.subheadline).foregroundStyle(.secondary)
                }
                HStack(spacing: 12) {
                    Button {
                        if VNDocumentCameraViewController.isSupported { showScanner = true }
                        else { error = String(localized: "This device doesn't support document scanning. Choose photos or import a file.") }
                    } label: { importTile(String(localized: "Scan notes"), symbol: "viewfinder", highlighted: true) }.buttonStyle(.plain)
                    Button { showFiles = true } label: { importTile(String(localized: "Word / PDF"), symbol: "doc.badge.plus") }.buttonStyle(.plain)
                }
                PhotosPicker(selection: $photos, maxSelectionCount: 12, matching: .images) {
                    Label("Choose photos from the library", systemImage: "photo.on.rectangle").font(.subheadline.weight(.medium)).frame(maxWidth: .infinity, minHeight: 44)
                }.buttonStyle(.glass)

                if busy { HStack(spacing: 12) { ProgressView(); Text("Reading the document on iPhone…").font(.subheadline) }.studyCard() }

                VStack(alignment: .leading, spacing: 16) {
                    Eyebrow(text: String(localized: "02 / Check & organize"))
                    TextField("Lesson title", text: $title).font(.title3.weight(.semibold)).padding(16).background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
                    Picker("Subject folder", selection: $subject) {
                        ForEach(store.subjects) { Text($0.title).tag($0) }
                    }.pickerStyle(.menu).frame(maxWidth: .infinity, alignment: .leading)
                    if let suggestion {
                        InfoNote(text: suggestion == .other
                                 ? String(localized: "Couldn't detect the subject. Pick the right folder yourself.")
                                 : String(localized: "Suggested from the content: \(suggestion.title). You can change the subject above."), symbol: "folder.badge.questionmark")
                    }
                    HStack { Text("Lesson content").font(.headline); Spacer(); Text("\(content.count) characters").font(.caption).foregroundStyle(.secondary) }
                    TextEditor(text: $content).frame(minHeight: 220).padding(10).scrollContentBackground(.hidden)
                        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18)).accessibilityLabel("Recognized content, editable")
                    InfoNote(text: String(localized: "Double-check handwriting and formulas. This version saves the extracted text; keep your original photos and files."))
                    if let error { Text(error).font(.footnote).foregroundStyle(.red).accessibilityAddTraits(.updatesFrequently) }
                }
                PrimaryButton(title: String(localized: "Save to library"), symbol: "folder.badge.plus") { save() }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || busy)
                InfoNote(text: String(localized: "The lesson is saved on this device. You can build a study pack with ChatGPT from the lesson page."), symbol: "iphone")
            }.padding(20)
        }.studyPage().navigationTitle("Add lesson").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() }.disabled(busy) } }
            .interactiveDismissDisabled(busy)
            .disabled(busy)
            .sheet(isPresented: $showScanner) {
                DocumentScanner { result in
                    switch result {
                    case .success(let data): Task { await readImages(data, sourceName: String(localized: "Scanned notes")) }
                    case .failure(let failure): error = failure.localizedDescription
                    }
                }.ignoresSafeArea()
            }
            .fileImporter(isPresented: $showFiles, allowedContentTypes: [.pdf, UTType(filenameExtension: "docx") ?? .data]) { result in
                switch result {
                case .success(let url):
                    Task {
                        busy = true; error = nil
                        defer { busy = false }
                        do {
                            let text = try await DocumentReader.readFile(url)
                            apply(text, sourceName: url.lastPathComponent)
                            if title.isEmpty { title = url.deletingPathExtension().lastPathComponent }
                        } catch { self.error = error.localizedDescription }
                    }
                case .failure(let failure): error = failure.localizedDescription
                }
            }
            .onChange(of: photos) { _, items in
                guard !items.isEmpty else { return }
                Task {
                    busy = true; error = nil
                    defer { busy = false; photos = [] }
                    do {
                        var data: [Data] = []
                        for item in items {
                            guard let image = try await item.loadTransferable(type: Data.self) else { throw StudyError.invalid(String(localized: "Couldn't load one of the selected photos.")) }
                            guard image.count <= DocumentReader.maximumBytes else { throw StudyError.invalid(String(localized: "An image exceeds 25 MB.")) }
                            data.append(image)
                        }
                        let text = try await DocumentReader.readImages(data)
                        apply(text, sourceName: String(localized: "Photo library · \(data.count) pages"))
                    } catch { self.error = error.localizedDescription }
                }
            }
    }

    private func importTile(_ title: String, symbol: String, highlighted: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            Image(systemName: symbol).font(.system(size: 30, weight: .light))
            HStack { Text(title).font(.headline); Spacer(); Image(systemName: "arrow.up.right").font(.caption) }
        }.foregroundStyle(highlighted ? appSettings.theme.accent : appSettings.theme.ink).padding(20).frame(maxWidth: .infinity, alignment: .leading)
            .background(highlighted ? appSettings.theme.glow : Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24))
    }

    private func apply(_ text: String, sourceName: String) {
        content = content.isEmpty ? text : content + "\n\n" + text
        if !sourceParts.contains(sourceName) { sourceParts.append(sourceName) }
        suggestion = Subject.suggest(for: content)
        if subject == .other { subject = suggestion ?? .other }
    }

    private func readImages(_ data: [Data], sourceName: String) async {
        busy = true; error = nil
        defer { busy = false }
        do { let text = try await DocumentReader.readImages(data); apply(text, sourceName: sourceName) }
        catch { self.error = error.localizedDescription }
    }

    private func save() {
        let source = sourceParts.isEmpty ? String(localized: "Typed text") : sourceParts.joined(separator: ", ")
        do { try store.add(title: title, subject: subject, text: content, source: source); dismiss() }
        catch { self.error = error.localizedDescription }
    }
}
