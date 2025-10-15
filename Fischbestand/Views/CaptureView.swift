import SwiftUI
import SwiftData
import Observation
import CoreLocation

struct CaptureView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var book: SpeciesBook
    @EnvironmentObject private var store: SurveyStore

    @Bindable var survey: Survey

    @StateObject private var speech = SpeechManager()
    @StateObject private var locationManager = LocationManager()
    @State private var infoBanner: String?
    @State private var showManualInput = false
    @State private var manualSpecies: String = ""
    @State private var manualCount: Int = 1
    @State private var manualComment: String = ""
    @State private var manualYOY: Bool = false
    @State private var activeSizeBin: SizeBin = .le5
    @State private var locationError: String?
    @State private var isEditingWeather = false
    @State private var draftWeatherNote: String = ""
    @State private var lastLocationUpdate: Date?
    @State private var isShowingVoiceHelp = false

    @FocusState private var isWeatherFieldFocused: Bool

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
            locationManager.requestLocation()
            if survey.latitude != nil || survey.longitude != nil {
                lastLocationUpdate = Date()
            }
        }
        .sheet(isPresented: $showManualInput) {
            ManualEntrySheet(manualSpecies: $manualSpecies,
                             manualCount: $manualCount,
                             manualComment: $manualComment,
                             selectedSizeBin: $activeSizeBin,
                             manualYOY: $manualYOY) { entry in
                addEntry(entry)
                resetManualFields()
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $isEditingWeather) {
            NavigationStack {
                Form {
                    Section("Wetter & Bedingungen") {
                        TextField("z. B. Bewölkt, 12°C, leichter Wind",
                                  text: $draftWeatherNote,
                                  axis: .vertical)
                            .focused($isWeatherFieldFocused)
                            .submitLabel(.done)
                    }

                    if survey.weatherNote != nil {
                        Section {
                            Button("Notiz entfernen", role: .destructive) {
                                survey.weatherNote = nil
                                try? context.save()
                                isEditingWeather = false
                            }
                        }
                    }
                }
                .scrollDismissesKeyboard(.interactively)
                .navigationTitle("Wetter notieren")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Abbrechen") {
                            isEditingWeather = false
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Speichern") {
                            let trimmed = draftWeatherNote.trimmingCharacters(in: .whitespacesAndNewlines)
                            survey.weatherNote = trimmed.isEmpty ? nil : trimmed
                            try? context.save()
                            isEditingWeather = false
                        }
                        .disabled(draftWeatherNote.trimmingCharacters(in: .whitespacesAndNewlines) == (survey.weatherNote?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""))
                    }
                }
                .task {
                    await MainActor.run {
                        draftWeatherNote = survey.weatherNote ?? ""
                        isWeatherFieldFocused = true
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $isShowingVoiceHelp) {
            VoiceCommandHelpSheet(featuredSpecies: SpeciesCatalog.featuredSpecies,
                                  sizeClassExample: currentSizeClassLabel)
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
            if newValue != nil {
                lastLocationUpdate = Date()
            }
        }
        .onChange(of: locationManager.longitude) { newValue in
            if survey.longitude != newValue {
                survey.longitude = newValue
                try? context.save()
            }
            if newValue != nil {
                lastLocationUpdate = Date()
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
        .onAppear {
            configureSpeechHandler()
            speech.activeDefaultSize = activeSizeBin.sizeRange
        }
        .onChange(of: book.items) { _ in
            configureSpeechHandler()
        }
        .onChange(of: activeSizeBin) { newValue in
            speech.activeDefaultSize = newValue.sizeRange
        }
        .onDisappear {
            speech.stop()
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
            Button {
                draftWeatherNote = survey.weatherNote ?? ""
                isEditingWeather = true
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Label(weatherSummaryText, systemImage: weatherSummaryIcon)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.subtleText)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 12)
                    Image(systemName: "square.and.pencil")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.primaryAccent)
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)

            locationStatusBadge
        }
        .glassCard()
    }

    private var weatherSummaryText: String {
        if let weather = survey.weatherNote, !weather.isEmpty {
            return weather
        }
        return "Wetter & Bedingungen hinzufügen"
    }

    private var weatherSummaryIcon: String {
        if let weather = survey.weatherNote, !weather.isEmpty {
            return "cloud.sun"
        }
        return "cloud.badge.plus"
    }

    private var locationStatusBadge: some View {
        let descriptor = makeLocationStatusDescriptor()

        return HStack(alignment: .center, spacing: 12) {
            Image(systemName: descriptor.icon)
                .font(.headline)
                .foregroundStyle(descriptor.tint)

            VStack(alignment: .leading, spacing: 2) {
                Text(descriptor.title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.mutedText)
                if let subtitle = descriptor.subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(AppTheme.subtleText)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var transcriptCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Label("Sprachaufnahme", systemImage: speech.isRecording ? "waveform" : "waveform.circle")
                    .font(.headline)
                    .foregroundStyle(AppTheme.mutedText)

                Spacer(minLength: 12)

                Button {
                    isShowingVoiceHelp = true
                } label: {
                    Label("Sprachbefehle", systemImage: "questionmark.circle")
                        .font(.footnote.weight(.semibold))
                        .labelStyle(.titleAndIcon)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(Color.white.opacity(0.12), in: Capsule())
                }
                .buttonStyle(.plain)
            }
            Text(speech.latestText.isEmpty ? "Sag z. B.: Barsch bis 5 Zentimeter, drei Stück, Kommentar: Jungfische" : speech.latestText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(alignment: .topTrailing) {
                    if speech.isRecording {
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
                if speech.isRecording {
                    speech.stop()
                } else {
                    do {
                        infoBanner = nil
                        speech.speciesCatalog = book.namesAndAliases()
                        speech.activeDefaultSize = activeSizeBin.sizeRange
                        try speech.start()
                    } catch {
                        infoBanner = "Spracherkennung nicht verfügbar. Prüfe Berechtigungen."
                    }
                }
            } label: {
                Label(speech.isRecording ? "Aufnahme stoppen" : "Aufnahme starten",
                      systemImage: speech.isRecording ? "stop.fill" : "mic.fill")
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
        if speech.isRecording {
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
                            let entry = SurveyEntry(species: species,
                                                    sizeBin: activeSizeBin,
                                                    count: 1,
                                                    isYOY: false,
                                                    note: nil)
                            addEntry(entry)
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
                ForEach(SizeBin.ordered, id: \.self) { bin in
                    Button(action: { activeSizeBin = bin }) {
                        Label(bin.title, systemImage: bin == activeSizeBin ? "checkmark" : "")
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
            if store.entries.isEmpty {
                ContentUnavailableView("Noch keine Fische erfasst",
                                       systemImage: "fish",
                                       description: Text("Starte die Aufnahme oder füge manuell Einträge hinzu."))
                .foregroundStyle(.white)
            } else {
                List {
                    Section {
                        ForEach(store.entries) { entry in
                            EntryCard(entry: entry)
                                .listRowBackground(Color.clear)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        withAnimation { store.delete(entry) }
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    } label: {
                                        Label("Löschen", systemImage: "trash")
                                    }
                                }
                        }
                        .onDelete { offsets in
                            withAnimation {
                                store.deleteEntries(at: offsets)
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .listRowSeparator(.hidden)
                .scrollContentBackground(.hidden)
                .frame(height: entryListHeight)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
        .glassCard()
    }

    @discardableResult
    private func addEntry(_ entry: SurveyEntry, showBanner: Bool = true) -> SurveyEntry? {
        guard store.currentSurvey != nil else { return nil }
        var normalized = entry
        normalized.species = book.canonicalName(for: entry.species)
        withAnimation {
            store.add(normalized)
            if showBanner {
                infoBanner = "Erfasst: \(normalized.species) – \(normalized.sizeBin.title) – \(normalized.count)x"
            }
        }
        return normalized
    }

    private func undoLastEntry() {
        guard let last = store.entries.first else {
            infoBanner = "Kein Eintrag zum Löschen."
            return
        }
        withAnimation {
            store.delete(last)
            infoBanner = "Letzten Eintrag gelöscht."
        }
    }

    private func configureSpeechHandler() {
        speech.speciesCatalog = book.namesAndAliases()
        speech.activeDefaultSize = activeSizeBin.sizeRange
        speech.onCommands = { [weak self] commands in
            self?.handleCommands(commands)
        }
        speech.onUnrecognized = { [weak self] text in
            self?.handleUnrecognized(text: text)
        }
    }

    private func handleCommands(_ commands: [ParsedCommand]) {
        guard store.currentSurvey != nil else { return }
        var captured: [SurveyEntry] = []
        for command in commands {
            let entry = SurveyEntry(species: command.species,
                                    sizeBin: SizeBin(range: command.sizeRange),
                                    count: command.count,
                                    isYOY: command.isYOY,
                                    note: nil)
            if let normalized = addEntry(entry, showBanner: false) {
                captured.append(normalized)
            }
        }
        if !captured.isEmpty {
            let message = captured.map { "\($0.species) – \($0.sizeBin.title) – \($0.count)x" }.joined(separator: ", ")
            infoBanner = "Erfasst: \(message)"
        }
    }

    private func handleUnrecognized(text: String) {
        guard store.currentSurvey != nil else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let fallbackBin = speech.activeDefaultSize?.sizeBin ?? activeSizeBin
        let noteEntry = SurveyEntry(species: "Unbestimmt",
                                    sizeBin: fallbackBin,
                                    count: 1,
                                    isYOY: detectYOY(trimmed),
                                    note: trimmed)
        _ = addEntry(noteEntry, showBanner: false)
        infoBanner = "Nicht erkannt, als Notiz gespeichert."
    }

    private func resetManualFields() {
        manualSpecies = ""
        manualCount = 1
        manualComment = ""
        manualYOY = false
    }

    private var currentSizeClassLabel: String { activeSizeBin.title }

    private var entryListHeight: CGFloat {
        let base: CGFloat = 80
        let rowHeight: CGFloat = 92
        let count = CGFloat(store.entries.count)
        let calculated = base + rowHeight * count
        return min(max(calculated, 200), 440)
    }

    private struct LocationStatusDescriptor {
        let title: String
        let subtitle: String?
        let icon: String
        let tint: Color
    }

    private func makeLocationStatusDescriptor() -> LocationStatusDescriptor {
        if let error = locationManager.errorMessage {
            return LocationStatusDescriptor(title: "Standortfehler",
                                            subtitle: error,
                                            icon: "exclamationmark.triangle.fill",
                                            tint: .orange)
        }

        switch locationManager.authorizationStatus {
        case .restricted, .denied:
            return LocationStatusDescriptor(title: "Standortzugriff deaktiviert",
                                            subtitle: "Aktiviere den Zugriff in den Einstellungen.",
                                            icon: "lock.slash",
                                            tint: .orange)
        case .notDetermined:
            return LocationStatusDescriptor(title: "Standortfreigabe erforderlich",
                                            subtitle: "Tippe auf \"Standort abrufen\" oben.",
                                            icon: "questionmark.circle",
                                            tint: AppTheme.primaryAccent)
        default:
            break
        }

        if locationManager.isUpdating {
            return LocationStatusDescriptor(title: "Standort wird gesucht …",
                                            subtitle: "Bitte bleib kurz an Ort und Stelle.",
                                            icon: "location.circle",
                                            tint: AppTheme.primaryAccent)
        }

        if let lastLocationUpdate {
            return LocationStatusDescriptor(title: "Standort aktualisiert",
                                            subtitle: locationStatusSubtitle(lastUpdate: lastLocationUpdate),
                                            icon: "checkmark.circle.fill",
                                            tint: .green)
        }

        if survey.latitude != nil && survey.longitude != nil {
            return LocationStatusDescriptor(title: "Standort gespeichert",
                                            subtitle: locationStatusSubtitle(lastUpdate: nil),
                                            icon: "checkmark.circle",
                                            tint: .green)
        }

        return LocationStatusDescriptor(title: "Kein Standort erfasst",
                                        subtitle: "Der letzte Standort konnte nicht bestimmt werden.",
                                        icon: "location.slash",
                                        tint: .yellow)
    }

    private func locationStatusSubtitle(lastUpdate: Date?) -> String? {
        var components: [String] = []

        if let lastUpdate {
            let relative = lastUpdate.formatted(.relative(presentation: .numeric, unitsStyle: .narrow))
            components.append("vor \(relative)")
        }

        if let accuracyDescription = formattedLocationAccuracy() {
            components.append(accuracyDescription)
        }

        return components.isEmpty ? nil : components.joined(separator: " • ")
    }

    private func formattedLocationAccuracy() -> String? {
        guard let accuracy = locationManager.horizontalAccuracy, accuracy > 0 else { return nil }
        let measurement = Measurement(value: accuracy, unit: UnitLength.meters)
        let formatted = measurement.formatted(.measurement(width: .abbreviated,
                                                           usage: .asProvided,
                                                           numberFormatStyle: .number.precision(.fractionLength(0))))
        return "Genauigkeit ±\(formatted)"
    }
}

private struct VoiceCommandHelpSheet: View {
    @Environment(\.dismiss) private var dismiss

    let featuredSpecies: [String]
    let sizeClassExample: String

    private var primarySpecies: String { featuredSpecies.first ?? "Barsch" }
    private var secondarySpecies: String { featuredSpecies.dropFirst().first ?? primarySpecies }

    var body: some View {
        NavigationStack {
            List {
                Section("Grundsyntax") {
                    VoiceCommandExampleRow(phrase: "\(primarySpecies) bis \(sizeClassExample), drei Stück, Kommentar: Jungfische",
                                           detail: "Art + Größenklasse + Anzahl + optionaler Kommentar in einem Satz.")
                    VoiceCommandExampleRow(phrase: "\(secondarySpecies) bis \(sizeClassExample), 2 Stück",
                                           detail: "Zahlen funktionieren als Worte oder Ziffern – beide Varianten werden verstanden.")
                    VoiceCommandExampleRow(phrase: "Rückgängig",
                                           detail: "Entfernt den zuletzt erfassten Eintrag, falls du dich versprochen hast.")
                }

                Section("Tipps für bessere Erkennung") {
                    Label("Mach nach der Art eine kurze Pause, damit die App Größenklasse und Menge sauber trennt.", systemImage: "waveform.badge.mic")
                        .labelStyle(.titleAndIcon)
                    Label("Sprich die Größenklasse so aus, wie sie oben angezeigt wird (z. B. „\(sizeClassExample)“).", systemImage: "ruler")
                        .labelStyle(.titleAndIcon)
                    Label("Falls es windig ist, halte das Mikrofon näher und wiederhole die Anzahl deutlich.", systemImage: "wind")
                        .labelStyle(.titleAndIcon)
                }

                Section("Wenn Spracheingabe nicht möglich ist") {
                    Label("Nutze die Schaltfläche „Manuell“, um Einträge per Tastatur zu erfassen.", systemImage: "square.and.pencil")
                        .labelStyle(.titleAndIcon)
                    Label("Greife bei häufigen Arten auf den Schnellzugriff oberhalb der Größenklasse zurück.", systemImage: "bolt.fill")
                        .labelStyle(.titleAndIcon)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Sprachbefehle")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }
}

private struct VoiceCommandExampleRow: View {
    let phrase: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("„\(phrase)“")
                .font(.body.weight(.semibold))
            Text(detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

private struct EntryCard: View {
    let entry: SurveyEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(entry.species)
                    .font(.headline)
                Spacer()
                Text(entry.timestamp, style: .time)
                    .font(.caption)
                    .foregroundStyle(AppTheme.subtleText)
            }
            Text(entry.sizeBin.title)
                .font(.subheadline)
                .foregroundStyle(AppTheme.subtleText)
            HStack(spacing: 8) {
                Label("\(entry.count) Stück", systemImage: "number")
                if entry.isYOY {
                    Divider().frame(height: 12)
                    Label("0+", systemImage: "leaf")
                        .labelStyle(.titleAndIcon)
                }
                if let comment = entry.note, !comment.isEmpty {
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
