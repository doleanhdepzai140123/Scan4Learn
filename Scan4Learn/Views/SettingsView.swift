import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(StudyStore.self) private var store
    @Environment(AppSettings.self) private var appSettings
    @Environment(\.dismiss) private var dismiss
    @State private var removeSamples = false
    @State private var signingIn = false
    @State private var signingOut = false
    @State private var authError: String?
    @State private var thinkingModels: (thinking: String?, standard: String?) = (nil, nil)
    @State private var reportText: String?
    @State private var reportDate: Date?
    @State private var generatingReport = false
    @State private var reportError: String?

    var body: some View {
        Form {
            Section {
                Picker(String(localized: "Language"), selection: languageBinding) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.displayName).tag(language)
                    }
                }
                LabeledContent(String(localized: "Device"), value: deviceDescription)
                LabeledContent(String(localized: "Version"), value: String(localized: "0.3 · FSRS · ChatGPT"))
            } header: { Text("Scan4Learn") }
            Section {
                ForEach(AppTheme.allCases) { theme in
                    Button {
                        appSettings.theme = theme
                    } label: {
                        HStack(spacing: 12) {
                            Circle().fill(theme.accent).frame(width: 22, height: 22)
                            Circle().fill(theme.glow).frame(width: 22, height: 22).overlay(Circle().stroke(.quaternary, lineWidth: 1))
                            Text(theme.name)
                            Spacer()
                            if appSettings.theme == theme { Image(systemName: "checkmark").foregroundStyle(.tint) }
                        }
                    }.buttonStyle(.plain).accessibilityAddTraits(appSettings.theme == theme ? .isSelected : [])
                }
            } header: { Text("Color theme") }
            Section {
                Picker(String(localized: "Target retention"), selection: retentionBinding) {
                    Text("80%").tag(0.80)
                    Text("85%").tag(0.85)
                    Text("90%").tag(0.90)
                    Text("95%").tag(0.95)
                }
                Text("Scheduling follows FSRS-5: the higher the retention, the more often cards return. Forgotten cards come back later the same day.").font(.footnote).foregroundStyle(.secondary)
            } header: { Text("Spaced repetition") }
            Section {
                if let session = ChatGPTAuth.shared.session {
                    LabeledContent(String(localized: "Account"), value: session.accountEmail.isEmpty ? "ChatGPT" : session.accountEmail)
                    Picker(String(localized: "Thinking mode"), selection: thinkingBinding) {
                        Text("Thinking").tag(true)
                        Text("Standard").tag(false)
                    }
                    if let thinking = thinkingModels.thinking {
                        Text(String(localized: "Thinking model: \(thinking).")).font(.footnote).foregroundStyle(.secondary)
                    }
                    if let standard = thinkingModels.standard {
                        Text(String(localized: "Standard model: \(standard).")).font(.footnote).foregroundStyle(.secondary)
                    }
                } else if signingIn {
                    HStack(spacing: 12) { ProgressView(); Text("Signing in…").font(.subheadline) }
                } else {
                    Button { Task { await signIn() } } label: {
                        Label("Sign in with ChatGPT", systemImage: "person.crop.circle.badge.checkmark")
                    }
                    Text("Use your ChatGPT account (Plus/Pro) to build study packs and get weekly reports automatically — no API key needed.").font(.footnote).foregroundStyle(.secondary)
                }
                if let authError { Text(authError).font(.footnote).foregroundStyle(.red) }
            } header: { Text("ChatGPT") }
            if ChatGPTAuth.shared.isSignedIn {
                Section {
                    if generatingReport {
                        HStack(spacing: 12) { ProgressView(); Text("Summarizing your progress…").font(.subheadline) }
                    } else {
                        Button { Task { await generateReport() } } label: {
                            Label("Generate a new report", systemImage: "arrow.clockwise")
                        }
                    }
                    if let reportError { Text(reportError).font(.footnote).foregroundStyle(.red) }
                    if let reportDate, let reportText {
                        LabeledContent(String(localized: "Last weekly report"), value: reportDate.formatted(date: .abbreviated, time: .omitted))
                        Text(reportText).font(.subheadline)
                    } else {
                        Text("Each week, your last 7 days of progress are sent to ChatGPT to spot weak spots and suggest better study habits.").font(.footnote).foregroundStyle(.secondary)
                    }
                } header: { Text("Weekly report") }
                Section {
                    Button("Sign out", role: .destructive) { signingOut = true }
                }
            }
            Section {
                Label("On-device text recognition", systemImage: "text.viewfinder")
                Text("Scan notes and photos, PDFs up to 40 pages, or Word .docx. Word reads only main text and tables; images, embedded formula objects, captions and complex formatting may not be extracted. Export a PDF and double-check when in doubt.").font(.footnote).foregroundStyle(.secondary)
            } header: { Text("Import documents") }
            Section {
                Label("Library stored on iPhone", systemImage: "iphone")
                Text("The library stores text and progress on device; no iCloud sync yet. Deleting the app can lose your data. Content leaves the device only when you share it or send it to ChatGPT.").font(.footnote).foregroundStyle(.secondary)
                if store.lessons.contains(where: \.isSample) {
                    Button("Delete sample lessons", role: .destructive) { removeSamples = true }
                }
            } header: { Text("Your data") }
        }.navigationTitle("Settings").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .confirmationDialog("Delete the sample lessons and their progress?", isPresented: $removeSamples, titleVisibility: .visible) {
                Button("Delete samples", role: .destructive) {
                    do { try store.removeSamples() } catch { store.errorMessage = error.localizedDescription }
                }
            }
            .confirmationDialog("Sign out of ChatGPT?", isPresented: $signingOut, titleVisibility: .visible) {
                Button("Sign out", role: .destructive) { ChatGPTAuth.shared.signOut() }
            }
            .task {
                ChatGPTAuth.shared.restore()
                if ChatGPTAuth.shared.isSignedIn {
                    thinkingModels = (try? await ChatGPTClient.shared.resolveModels()) ?? (nil, nil)
                }
                if let last = WeeklyReport.lastReport {
                    reportText = last.text
                    reportDate = last.date
                }
            }
    }

    private var deviceDescription: String {
        String(localized: "\(UIDevice.current.model) · iOS \(UIDevice.current.systemVersion)")
    }

    private var languageBinding: Binding<AppLanguage> {
        Binding(get: { appSettings.language }, set: { appSettings.language = $0 })
    }

    private var retentionBinding: Binding<Double> {
        Binding(get: { appSettings.targetRetention }, set: { appSettings.targetRetention = $0 })
    }

    private var thinkingBinding: Binding<Bool> {
        Binding(get: { appSettings.prefersThinking }, set: { appSettings.prefersThinking = $0 })
    }

    private func signIn() async {
        signingIn = true
        authError = nil
        defer { signingIn = false }
        do {
            try await ChatGPTAuth.shared.signIn()
            thinkingModels = (try? await ChatGPTClient.shared.resolveModels()) ?? (nil, nil)
        } catch {
            authError = error.localizedDescription
        }
    }

    private func generateReport() async {
        generatingReport = true
        reportError = nil
        defer { generatingReport = false }
        do {
            let answer = try await WeeklyReport.generate(for: store, thinking: appSettings.prefersThinking)
            reportText = answer
            reportDate = WeeklyReport.lastReport?.date
        } catch {
            reportError = error.localizedDescription
        }
    }
}
