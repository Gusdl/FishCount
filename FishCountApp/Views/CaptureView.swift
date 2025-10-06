import SwiftUI
import SwiftData

struct CaptureView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \SizeClassPreset.label) private var sizeClassPresets: [SizeClassPreset]

    @Bindable var survey: Survey

    @StateObject private var speechManager = SpeechManager()
    @State private var parser = VoiceParser(speciesAliases: SpeciesCatalog.aliases)
    @State private var liveTranscript: String = ""
    @State private var infoBanner: String?
    @State private var showManualInput = false
    @State private var selectedSizeClassID: PersistentIdentifier?
    @State private var manualSpecies: String = ""
    @State private var manualCount: Int = 1
    @State private var manualComment: String = ""
    @State private var locationError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                transcriptCard
                actionButtons
                quickAddPanel
                entryList
            }
            .padding(.vertical, 24)
            .padding(.horizontal)
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Fertig") { dismiss() }
            }
        }
        .task {
            await ensureDefaultSizeClasses()
            if selectedSizeClassID == nil {
                selectedSizeClassID = sizeClassPresets.first?.persistentModelID
            }
        }
        .sheet(isPresented: $showManualInput) {
            ManualEntrySheet(manualSpecies: $manualSpecies,
                             manualCount: $manualCount,
                             manualComment: $manualComment,
                             sizeClasses: sizeClassPresets,
                             selectedSizeClassID: $selectedSizeClassID) { entry in
                addEntry(entry)
                resetManualFields()
            }
            .presentationDetents([.medium, .large])
        }
        .alert("Standort konnte nicht ermittelt werden", isPresented: Binding(get: {
            locationError != nil
        }, set: { _ in
            locationError = nil
        })) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(locationError ?? "")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(survey.title)
                .font(.largeTitle).fontWeight(.bold)
            Text(survey.date, style: .date)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if let locationName = survey.locationName, !locationName.isEmpty {
                Label(locationName, systemImage: "mappin.and.ellipse")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if let weather = survey.weatherNote, !weather.isEmpty {
                Label(weather, systemImage: "cloud.sun")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var transcriptCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Sprachaufnahme", systemImage: speechManager.isRecording ? "waveform" : "waveform.circle")
                .font(.headline)
            Text(liveTranscript.isEmpty ? "Sag z. B.: Barsch bis 5 Zentimeter, drei Stück, Kommentar: Jungfische" : liveTranscript)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(alignment: .topTrailing) {
                    if speechManager.isRecording {
                        RecordingIndicator()
                            .padding(12)
                    }
                }
            if let infoBanner {
                InfoBanner(text: infoBanner)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut, value: infoBanner)
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                if speechManager.isRecording {
                    speechManager.stop()
                } else {
                    Task {
                        do {
                            try await speechManager.start { text in
                                liveTranscript = text
                                handleVoice(text)
                            }
                        } catch {
                            infoBanner = "Spracherkennung nicht verfügbar. Prüfe Berechtigungen."
                        }
                    }
                }
            } label: {
                Label(speechManager.isRecording ? "Aufnahme stoppen" : "Aufnahme starten",
                      systemImage: speechManager.isRecording ? "stop.fill" : "mic.fill")
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(speechManager.isRecording ? Color.red.gradient : Color.accentColor.gradient,
                                in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .shadow(color: .black.opacity(0.2), radius: 8, y: 4)

            HStack(spacing: 16) {
                Button {
                    undoLastEntry()
                } label: {
                    Label("Rückgängig", systemImage: "arrow.uturn.backward")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray5), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                Button {
                    showManualInput = true
                } label: {
                    Label("Manuell", systemImage: "square.and.pencil")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray5), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
        }
    }

    private var quickAddPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Schnellzugriff", systemImage: "bolt.fill")
                .font(.headline)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(SpeciesCatalog.featuredSpecies, id: \.self) { species in
                        Button {
                            addEntry(ParsedEntry(species: species, sizeClass: currentSizeClassLabel, count: 1, comment: nil))
                        } label: {
                            Text(species)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Color(.systemBackground), in: Capsule())
                                .overlay(Capsule().stroke(Color.accentColor.opacity(0.6)))
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            sizeClassPicker
        }
    }

    private var sizeClassPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Größenklasse")
                .font(.subheadline.weight(.semibold))
            Menu {
                ForEach(sizeClassPresets) { preset in
                    Button(action: { selectedSizeClassID = preset.persistentModelID }) {
                        Label(preset.label, systemImage: preset.persistentModelID == selectedSizeClassID ? "checkmark" : "")
                    }
                }
            } label: {
                HStack {
                    Text(currentSizeClassLabel)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                }
                .padding()
                .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
            }
        }
    }

    private var entryList: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Erfasste Einträge", systemImage: "fish.fill")
                .font(.headline)
            if survey.entries.isEmpty {
                ContentUnavailableView("Noch keine Fische erfasst",
                                       systemImage: "fish",
                                       description: Text("Starte die Aufnahme oder füge manuell Einträge hinzu."))
            } else {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(survey.entries.sorted(by: { $0.createdAt > $1.createdAt })) { entry in
                        EntryCard(entry: entry)
                            .contextMenu {
                                Button("Löschen", role: .destructive) {
                                    delete(entry)
                                }
                            }
                    }
                }
            }
        }
    }

    private func handleVoice(_ text: String) {
        let command = parser.parse(text: text)
        switch command {
        case .undo:
            undoLastEntry()
        case .add(let entry):
            addEntry(entry)
        case .none:
            break
        }
    }

    private func addEntry(_ parsed: ParsedEntry) {
        withAnimation {
            let entry = CountEntry(species: parsed.species,
                                   sizeClass: parsed.sizeClass,
                                   count: parsed.count,
                                   comment: parsed.comment)
            survey.entries.append(entry)
            infoBanner = "Erfasst: \(parsed.species) – \(parsed.sizeClass) – \(parsed.count)x"
            try? context.save()
        }
    }

    private func undoLastEntry() {
        guard let last = survey.entries.sorted(by: { $0.createdAt < $1.createdAt }).last else {
            infoBanner = "Kein Eintrag zum Löschen."
            return
        }
        withAnimation {
            context.delete(last)
            infoBanner = "Letzten Eintrag gelöscht."
            try? context.save()
        }
    }

    private func delete(_ entry: CountEntry) {
        withAnimation {
            context.delete(entry)
            try? context.save()
        }
    }

    private func ensureDefaultSizeClasses() async {
        if !sizeClassPresets.isEmpty { return }
        let defaults: [SizeClassPreset] = [
            SizeClassPreset(label: "0–5 cm", lowerBound: 0, upperBound: 5, isDefault: true),
            SizeClassPreset(label: "6–10 cm", lowerBound: 6, upperBound: 10, isDefault: true),
            SizeClassPreset(label: "11–15 cm", lowerBound: 11, upperBound: 15, isDefault: true),
            SizeClassPreset(label: "16–20 cm", lowerBound: 16, upperBound: 20, isDefault: true)
        ]
        defaults.forEach(context.insert)
        try? context.save()
    }

    private func resetManualFields() {
        manualSpecies = ""
        manualCount = 1
        manualComment = ""
    }

    private var currentSizeClassLabel: String {
        if let selected = sizeClassPresets.first(where: { $0.persistentModelID == selectedSizeClassID }) {
            return selected.label
        }
        return sizeClassPresets.first?.label ?? "bis 5 cm"
    }
}

private struct EntryCard: View {
    let entry: CountEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(entry.species)
                    .font(.headline)
                Spacer()
                Text(entry.createdAt, style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(entry.sizeClass)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack {
                Label("\(entry.count) Stück", systemImage: "number")
                if let comment = entry.comment, !comment.isEmpty {
                    Divider().frame(height: 12)
                    Label(comment, systemImage: "text.bubble")
                        .labelStyle(.titleAndIcon)
                }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.05))
        )
    }
}

private struct RecordingIndicator: View {
    @State private var animate = false

    var body: some View {
        Circle()
            .fill(Color.red)
            .frame(width: 16, height: 16)
            .overlay(
                Circle()
                    .stroke(Color.red.opacity(0.4), lineWidth: 4)
                    .scaleEffect(animate ? 1.2 : 0.8)
                    .opacity(animate ? 0 : 1)
            )
            .onAppear {
                withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
                    animate = true
                }
            }
    }
}

private struct InfoBanner: View {
    let text: String

    var body: some View {
        HStack {
            Image(systemName: "info.circle.fill")
            Text(text)
                .font(.footnote)
        }
        .foregroundStyle(.white)
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.accentColor, in: Capsule())
    }
}
