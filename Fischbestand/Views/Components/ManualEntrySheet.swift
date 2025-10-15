import SwiftUI

struct ManualEntrySheet: View {
    @EnvironmentObject private var book: SpeciesBook
    @Binding var manualSpecies: String
    @Binding var manualCount: Int
    @Binding var manualComment: String
    @Binding var selectedSizeBin: SizeBin
    @Binding var manualYOY: Bool
    var onSave: (SurveyEntry) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Art")) {
                    TextField("z. B. Barsch", text: $manualSpecies)
                    SpeciesSuggestionList(species: $manualSpecies)
                }

                Section(header: Text("Größenklasse")) {
                    Picker("Größe", selection: $selectedSizeBin) {
                        ForEach(SizeBin.ordered, id: \.self) { bin in
                            Text(bin.title).tag(bin)
                        }
                    }
                    .pickerStyle(.inline)
                }

                Section(header: Text("Anzahl")) {
                    Stepper(value: $manualCount, in: 1...999) {
                        Text("\(manualCount) Stück")
                    }
                }

                Section(header: Text("Jungfische")) {
                    Toggle("0+ / Jungfische", isOn: $manualYOY)
                }

                Section(header: Text("Kommentar")) {
                    TextField("optional", text: $manualComment, axis: .vertical)
                }
            }
            .navigationTitle("Manueller Eintrag")
            .scrollContentBackground(.hidden)
            .background(AppTheme.backgroundGradient.ignoresSafeArea())
            .tint(AppTheme.primaryAccent)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Übernehmen") {
                        guard !manualSpecies.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                        let trimmedSpecies = manualSpecies.trimmingCharacters(in: .whitespacesAndNewlines)
                        let canonicalSpecies = book.canonicalName(for: trimmedSpecies)
                        let note = manualComment.trimmingCharacters(in: .whitespaces)
                        let comment = note.isEmpty ? nil : note
                        let entry = SurveyEntry(species: canonicalSpecies,
                                                sizeBin: selectedSizeBin,
                                                count: manualCount,
                                                isYOY: manualYOY,
                                                note: comment)
                        onSave(entry)
                        dismiss()
                    }
                }
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
}

private struct SpeciesSuggestionList: View {
    @Binding var species: String
    @EnvironmentObject private var book: SpeciesBook

    var body: some View {
        let trimmed = species.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercased = trimmed.lowercased()

        let suggestions: [String] = {
            guard trimmed.count >= 1 else { return [] }

            let canonicalNames = book.items.map(\.name)
            let searchPool = book.namesAndAliases()

            let prefixMatches = canonicalNames.filter { suggestion in
                suggestion.lowercased().hasPrefix(lowercased) && suggestion.lowercased() != lowercased
            }
            let fuzzyMatches = FuzzyMatcher.rankedMatches(for: trimmed,
                                                          in: searchPool,
                                                          limit: 6,
                                                          threshold: 0.55)
            return (prefixMatches + fuzzyMatches.map { book.canonicalName(for: $0) }).reduce(into: [String]()) { result, name in
                let canonical = book.canonicalName(for: name)
                let normalized = canonical.lowercased()
                guard normalized != lowercased else { return }
                if !result.contains(where: { $0.lowercased() == normalized }) {
                    result.append(canonical)
                }
            }
        }()

        if !suggestions.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Label("Ähnliche Arten", systemImage: "sparkles")
                    .font(.caption)
                    .foregroundStyle(AppTheme.mutedText)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(suggestions, id: \.self) { suggestion in
                            Button {
                                species = suggestion
                            } label: {
                                Text(suggestion)
                                    .font(.footnote.weight(.semibold))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(
                                        LinearGradient(colors: [AppTheme.primaryAccent.opacity(0.85), AppTheme.secondaryAccent.opacity(0.8)],
                                                       startPoint: .leading,
                                                       endPoint: .trailing),
                                        in: Capsule(style: .continuous)
                                    )
                                    .overlay(
                                        Capsule(style: .continuous)
                                            .stroke(Color.white.opacity(0.18))
                                    )
                                    .foregroundStyle(.white)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding(.top, 4)
        }
    }
}
