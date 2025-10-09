import SwiftUI
import SwiftData

struct ManualEntrySheet: View {
    @Binding var manualSpecies: String
    @Binding var manualCount: Int
    @Binding var manualComment: String
    let sizeClasses: [SizeClassPreset]
    @Binding var selectedSizeClassID: PersistentIdentifier?
    var onSave: (ParsedEntry) -> Void

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
                            Text(preset.label).tag(Optional(preset.persistentModelID))
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
                        let selectedLabel = sizeClasses.first { $0.persistentModelID == selectedSizeClassID }?.label ?? "bis 5 cm"
                        let entry = ParsedEntry(
                            species: manualSpecies.trimmingCharacters(in: .whitespacesAndNewlines),
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
        let suggestions = SpeciesCatalog.allSpecies.filter { suggestion in
            guard !species.isEmpty else { return false }
            return suggestion.lowercased().hasPrefix(species.lowercased()) && suggestion.lowercased() != species.lowercased()
        }

        if !suggestions.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(suggestions, id: \.self) { suggestion in
                        Button {
                            species = suggestion
                        } label: {
                            Text(suggestion)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.accentColor.opacity(0.1), in: Capsule())
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}
