import SwiftUI
import SwiftData
import Observation
import CoreLocation

struct CaptureView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \SizeClassPreset.label) private var sizeClassPresets: [SizeClassPreset]

    @Bindable var survey: Survey

    @StateObject private var speechManager = SpeechManager()
    @StateObject private var locationManager = LocationManager()
    @State private var parser = VoiceParser(speciesList: SpeciesCatalog.allSpecies,
                                           speciesAliases: SpeciesCatalog.aliases)
    @State private var liveTranscript: String = ""
    @State private var infoBanner: String?
    @State private var showManualInput = false
    @State private var selectedSizeClassID: PersistentIdentifier?
    @State private var manualSpecies: String = ""
    @State private var manualCount: Int = 1
    @State private var manualComment: String = ""
    @State private var locationError: String?

    private let numberWordHints: [String] = [
        "null", "eins", "eine", "einen", "zwei", "drei", "vier", "fünf", "sechs",
        "sieben", "acht", "neun", "zehn", "elf", "zwölf", "dreizehn", "vierzehn",
        "fünfzehn", "sechzehn", "siebzehn", "achtzehn", "neunzehn", "zwanzig"
    ]

    private let contextVocabulary: [String] = [
        "bis", "bis zu", "Zentimeter", "zentimeter", "Zentimetern", "cm", "Zentimeterbereich",
        "Stück", "Stueck", "Anzahl", "Kommentar", "Kommentare"
    ]

    var body: some View {
        ZStack {
            AppTheme.backgroundGradient
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    transcriptCard
                    actionButtons
                    quickAddPanel
                    entryList
                }
                .padding(.vertical, 32)
                .padding(.horizontal)
            }
        }
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
            locationManager.requestLocation()
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
        .onChange(of: locationManager.locationName) { newValue in
            guard let newValue, newValue != survey.locationName else { return }
            survey.locationName = newValue
            try? context.save()
        }
        .onChange(of: locationManager.latitude) { newValue in
            if survey.latitude != newValue {
                survey.latitude = newValue
                try? context.save()
            }
        }
        .onChange(of: locationManager.longitude) { newValue in
            if survey.longitude != newValue {
                survey.longitude = newValue
                try? context.save()
            }
        }
        .onChange(of: locationManager.authorizationStatus) { status in
            if status == .denied || status == .restricted {
                locationError = "Bitte erlaube den Standortzugriff in den Systemeinstellungen."
            }
        }
        .onChange(of: locationManager.errorMessage) { message in
            if let message { locationError = message }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(survey.title)
                .font(.largeTitle.bold())
                .foregroundStyle(.white)
            Text(survey.date, style: .date)
                .font(.subheadline)
                .foregroundStyle(AppTheme.subtleText)
            if let locationName = survey.locationName, !locationName.isEmpty {
                Label(locationName, systemImage: "mappin.and.ellipse")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.subtleText)
            } else if locationManager.isUpdating {
                Label("Standort wird gesucht …", systemImage: "location.circle")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.subtleText)
            } else {
                Button {
                    locationManager.requestLocation()
                } label: {
                    Label("Standort abrufen", systemImage: "location")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.subtleText)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderless)
            }
            if let weather = survey.weatherNote, !weather.isEmpty {
                Label(weather, systemImage: "cloud.sun")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.subtleText)
            }
        }
        .glassCard()
    }

    private var transcriptCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Sprachaufnahme", systemImage: speechManager.isRecording ? "waveform" : "waveform.circle")
                .font(.headline)
                .foregroundStyle(AppTheme.mutedText)
            Text(liveTranscript.isEmpty ? "Sag z. B.: Barsch bis 5 Zentimeter, drei Stück, Kommentar: Jungfische" : liveTranscript)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(alignment: .topTrailing) {
                    if speechManager.isRecording {
                        RecordingIndicator()
                            .padding(12)
                    }
                }
                .foregroundStyle(.white)
            if let infoBanner {
                InfoBanner(text: infoBanner)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut, value: infoBanner)
        .glassCard()
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                if speechManager.isRecording {
                    speechManager.stop()
                } else {
                    Task {
                        do {
                            liveTranscript = ""
                            try await speechManager.start(hints: speechHints) { text in
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
                    .background(
                        recordingButtonBackground,
                        in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                    )
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.25), radius: 8, y: 6)
            }
            .buttonStyle(.plain)

            HStack(spacing: 16) {
                Button {
                    undoLastEntry()
                } label: {
                    Label("Rückgängig", systemImage: "arrow.uturn.backward")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .foregroundStyle(.white)
                }

                Button {
                    showManualInput = true
                } label: {
                    Label("Manuell", systemImage: "square.and.pencil")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .foregroundStyle(.white)
                }
            }
        }
        .glassCard()
    }

    private var recordingButtonBackground: AnyShapeStyle {
        if speechManager.isRecording {
            return AnyShapeStyle(Color.red.gradient)
        } else {
            return AnyShapeStyle(AppTheme.buttonGradient)
        }
    }

    private var quickAddPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Schnellzugriff", systemImage: "bolt.fill")
                .font(.headline)
                .foregroundStyle(AppTheme.mutedText)
            Text("Aktive Größenklasse: \(currentSizeClassLabel)")
                .font(.caption)
                .foregroundStyle(AppTheme.subtleText)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(SpeciesCatalog.featuredSpecies, id: \.self) { species in
                        Button {
                            addEntry(ParsedEntry(species: species, sizeClass: currentSizeClassLabel, count: 1, comment: nil))
                        } label: {
                            Text(species)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Color.white.opacity(0.15), in: Capsule())
                                .overlay(Capsule().stroke(AppTheme.primaryAccent.opacity(0.6)))
                                .foregroundStyle(.white)
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            sizeClassPicker
        }
        .glassCard()
    }

    private var sizeClassPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Größenklasse")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.mutedText)
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
                .background(Color.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .foregroundStyle(.white)
            }
        }
    }

    private var entryList: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Erfasste Einträge", systemImage: "fish.fill")
                .font(.headline)
                .foregroundStyle(AppTheme.mutedText)
            if survey.entries.isEmpty {
                ContentUnavailableView("Noch keine Fische erfasst",
                                       systemImage: "fish",
                                       description: Text("Starte die Aufnahme oder füge manuell Einträge hinzu."))
                .foregroundStyle(.white)
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
        .glassCard()
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

    private var speechHints: [String] {
        var hints = Set(SpeciesCatalog.searchableNames)
        hints.formUnion(contextVocabulary)
        hints.formUnion(numberWordHints)
        hints.formUnion((0...50).map { String($0) })
        return Array(hints)
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
                    .foregroundStyle(AppTheme.subtleText)
            }
            Text(entry.sizeClass)
                .font(.subheadline)
                .foregroundStyle(AppTheme.subtleText)
            HStack(spacing: 8) {
                Label("\(entry.count) Stück", systemImage: "number")
                if let comment = entry.comment, !comment.isEmpty {
                    Divider().frame(height: 12)
                    Label(comment, systemImage: "text.bubble")
                        .labelStyle(.titleAndIcon)
                }
            }
            .font(.footnote)
            .foregroundStyle(AppTheme.subtleText)
        }
        .padding()
        .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.08))
        )
        .foregroundStyle(.white)
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
