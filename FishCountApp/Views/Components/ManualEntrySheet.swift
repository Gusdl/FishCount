import SwiftUI
import SwiftData

struct ManualEntrySheet: View {
    @Binding var manualSpecies: String
    @Binding var manualCount: Int
    @Binding var manualComment: String
    let sizeClasses: [SizeClassPreset]
    @Binding var selectedSizeClassID: PersistentIdentifier?
    var onSave: (ParsedEntry) -> Void

    private let parser = VoiceParser(speciesList: SpeciesCatalog.allSpecies,
                                     speciesAliases: SpeciesCatalog.aliases)

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Art")) {
                    TextField("z. B. Barsch", text: $manualSpecies)
                    SpeciesSuggestionList(species: $manualSpecies)
                }

                Section(header: Text("Größenklasse")) {
                    Picker("Größe", selection: $selectedSizeClassID) {
                        ForEach(sizeClasses) { preset in
                            Text(preset.label)
                                .tag(PersistentIdentifier?.some(preset.persistentModelID))
                        }
                    }
                    .pickerStyle(.inline)
                }

                Section(header: Text("Anzahl")) {
                    Stepper(value: $manualCount, in: 1...999) {
                        Text("\(manualCount) Stück")
                    }
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
                        let selectedLabel = sizeClasses.first { preset in
                            guard let selectedSizeClassID else { return false }
                            return preset.persistentModelID == selectedSizeClassID
                        }?.label ?? "bis 5 cm"
                        let trimmedSpecies = manualSpecies.trimmingCharacters(in: .whitespacesAndNewlines)
                        let canonicalSpecies = parser.canonicalSpecies(from: trimmedSpecies)
                        let entry = ParsedEntry(
                            species: canonicalSpecies,
                            sizeClass: selectedLabel,
                            count: manualCount,
                            comment: manualComment.trimmingCharacters(in: .whitespaces)
                        )
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

    var body: some View {
        let trimmed = species.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercased = trimmed.lowercased()

        var combined: [String] = []
        if trimmed.count >= 1 {
            let prefixMatches = SpeciesCatalog.allSpecies.filter { suggestion in
                suggestion.lowercased().hasPrefix(lowercased) && suggestion.lowercased() != lowercased
            }
            let fuzzyMatches = FuzzyMatcher.rankedMatches(for: trimmed,
                                                          in: SpeciesCatalog.searchableNames,
                                                          limit: 6,
                                                          threshold: 0.55)
            combined = prefixMatches + fuzzyMatches
        }

        var seen = Set<String>()
        let suggestions = combined.filter { name in
            let normalized = name.lowercased()
            guard normalized != lowercased else { return false }
            return seen.insert(normalized).inserted
        }

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
