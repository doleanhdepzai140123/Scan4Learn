import SwiftUI

/// Manage subject folders: every folder is editable (name, SF Symbol, colour).
/// Built-ins can be reset to their defaults; custom folders can be deleted.
struct SubjectManagerView: View {
    @Environment(StudyStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var editingSubject: Subject?
    @State private var creatingSubject = false

    var body: some View {
        List {
            Section {
                ForEach(store.subjects) { subject in
                    Button {
                        editingSubject = subject
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: subject.effectiveSymbol).foregroundStyle(subject.color).frame(width: 28)
                            Text(subject.title)
                            Spacer()
                            if isDefaultBuiltIn(subject) {
                                Text(String(localized: "Built-in")).font(.caption2).foregroundStyle(.tertiary)
                            } else {
                                Image(systemName: "pencil").font(.caption).foregroundStyle(.tertiary)
                            }
                        }
                    }.foregroundStyle(.primary)
                }
            } header: { Text("Subjects") }
            Section {
                Button { creatingSubject = true } label: {
                    Label("Add subject", systemImage: "plus.circle")
                }
            } footer: {
                Text("Custom subjects get their own name, icon and colour; deleting one moves its lessons to \"Other\".")
            }
        }.navigationTitle("Manage subjects").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .sheet(isPresented: $creatingSubject) { NavigationStack { SubjectFormView(subject: nil) } }
            .sheet(item: $editingSubject) { subject in NavigationStack { SubjectFormView(subject: subject) } }
    }

    /// A built-in that still carries its original name and folder icon.
    private func isDefaultBuiltIn(_ subject: Subject) -> Bool {
        guard Subject.builtIns.contains(where: { $0.id == subject.id }) else { return false }
        return subject.name.isEmpty && subject.symbolName == (Subject.builtIns.first { $0.id == subject.id }?.symbolName ?? subject.symbolName)
    }
}

/// Edit or create a subject: name, SF Symbol, colour. Built-ins gain a
/// reset-to-default action; custom subjects gain delete.
struct SubjectFormView: View {
    @Environment(StudyStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let subject: Subject?
    @State private var name = ""
    @State private var symbolName = "book"
    @State private var colorIndex = 0
    @State private var pickingSymbol = false
    @State private var deleteConfirm = false

    private var isBuiltIn: Bool {
        Subject.builtIns.contains { $0.id == subject?.id }
    }

    private var hasOverride: Bool {
        store.subjectOverrides.contains { $0.id == subject?.id }
    }

    var body: some View {
        Form {
            Section {
                TextField(String(localized: "Subject name"), text: $name)
            } header: { Text("Details") }
            Section {
                Button { pickingSymbol = true } label: {
                    HStack {
                        Label(String(localized: "Choose an icon"), systemImage: effectiveIcon)
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                    }
                }
                HStack {
                    Text(String(localized: "Accent colour"))
                    Spacer()
                    ForEach(0..<Subject.paletteColorCount, id: \.self) { index in
                        Circle().fill(paletteColor(index)).frame(width: 22, height: 22)
                            .overlay(Circle().stroke(colorIndex == index ? Color.primary : .clear, lineWidth: 2))
                            .onTapGesture { colorIndex = index }
                    }
                }
            } header: { Text("Appearance") }
            if isBuiltIn {
                Section {
                    if hasOverride {
                        Button(String(localized: "Reset to default"), role: .destructive) { reset() }
                    }
                } footer: {
                    Text("Built-in folders keep their fixed place in the app; you can change their name, icon and colour.")
                }
            } else if subject != nil {
                Section {
                    Button(String(localized: "Delete subject"), role: .destructive) { deleteConfirm = true }
                }
            }
        }.navigationTitle(subject == nil ? String(localized: "Add subject") : String(localized: "Edit subject"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Save subject")) { save() }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .sheet(isPresented: $pickingSymbol) { NavigationStack { SymbolPickerView(selection: $symbolName) } }
            .confirmationDialog(String(localized: "Delete the subject and move its lessons to \"Other\"?"), isPresented: $deleteConfirm, titleVisibility: .visible) {
                Button(String(localized: "Delete subject"), role: .destructive) { remove() }
            }
            .onAppear {
                if let subject {
                    name = subject.name
                    symbolName = subject.effectiveSymbol
                    colorIndex = max(0, subject.colorIndex)
                }
            }
    }

    private var effectiveIcon: String {
        UIImage(systemName: symbolName) != nil ? symbolName : "book"
    }

    private func paletteColor(_ index: Int) -> Color {
        Subject(id: "preview", name: "x", symbolName: "book", colorIndex: index).color
    }

    private func save() {
        do {
            if let subject {
                try store.updateSubject(Subject(id: subject.id, name: name, symbolName: symbolName, colorIndex: colorIndex))
            } else {
                try store.addSubject(name: name, symbolName: symbolName, colorIndex: colorIndex)
            }
            dismiss()
        } catch {
            store.errorMessage = error.localizedDescription
        }
    }

    private func reset() {
        if let subject {
            do { try store.resetSubject(id: subject.id) } catch { store.errorMessage = error.localizedDescription }
        }
        dismiss()
    }

    private func remove() {
        if let subject {
            do { try store.removeSubject(id: subject.id) } catch { store.errorMessage = error.localizedDescription }
        }
        dismiss()
    }
}

/// Searchable grid of curated SF Symbols for subject folders; only symbols
/// the running OS can render are listed.
struct SymbolPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selection: String
    @State private var search = ""

    private var filtered: [String] {
        let symbols = SubjectIconCatalog.available
        guard !search.isEmpty else { return symbols }
        return symbols.filter { $0.localizedStandardContains(search) }
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 74), spacing: 12)], spacing: 12) {
                ForEach(filtered, id: \.self) { symbol in
                    Button {
                        selection = symbol
                        dismiss()
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: symbol).font(.title2)
                                .foregroundStyle(selection == symbol ? Color.accentColor : Color.primary)
                                .frame(width: 52, height: 52)
                                .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
                            Text(symbol).font(.system(size: 9, design: .monospaced)).lineLimit(1).minimumScaleFactor(0.7)
                                .foregroundStyle(.secondary)
                        }
                    }.buttonStyle(.plain)
                }
            }.padding(16)
        }.background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Choose an icon")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $search, prompt: "Search icons…")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
    }
}
