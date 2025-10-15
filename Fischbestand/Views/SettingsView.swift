import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var book: SpeciesBook
    @State private var speciesList: [Species] = SpeciesCatalog.load()

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array($speciesList.enumerated()), id: \.offset) { _, $species in
                    TextField("Art", text: $species.name)
                        .textInputAutocapitalization(.words)
                }
                .onDelete { speciesList.remove(atOffsets: $0) }

                Button {
                    speciesList.append(Species(name: ""))
                } label: {
                    Label("Art hinzufügen", systemImage: "plus")
                }
            }
            .navigationTitle("Artenbuch")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        let cleaned = speciesList.filter { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
                        SpeciesCatalog.save(cleaned)
                        book.items = cleaned.map { SpeciesEntry(name: $0.name, aliases: $0.aliases) }
                        dismiss()
                    }
                    .disabled(speciesList.allSatisfy { $0.name.trimmingCharacters(in: .whitespaces).isEmpty })
                }
            }
        }
    }
}
