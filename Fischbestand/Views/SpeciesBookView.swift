import SwiftUI

struct SpeciesBookView: View {
    @EnvironmentObject var book: SpeciesBook
    @State private var newName = ""

    var body: some View {
        List {
            Section("Neue Art hinzufügen") {
                HStack {
                    TextField("z. B. Barsch", text: $newName)
                    Button("Add") {
                        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !name.isEmpty else { return }
                        book.items.append(SpeciesEntry(name: name))
                        newName = ""
                    }
                }
            }
            Section("Arten") {
                ForEach($book.items) { $entry in
                    NavigationLink(entry.name) { SpeciesEditView(entry: $entry) }
                }
                .onDelete { book.items.remove(atOffsets: $0) }
                .onMove { book.items.move(fromOffsets: $0, toOffset: $1) }
            }
        }
        .toolbar { EditButton() }
        .navigationTitle("Artenbuch")
    }
}

private struct SpeciesEditView: View {
    @Binding var entry: SpeciesEntry
    @State private var aliasText = ""

    var body: some View {
        Form {
            Section("Name") { TextField("Artname", text: $entry.name) }
            Section("Synonyme / Aliase") {
                ForEach(Array(entry.aliases.enumerated()), id: \.offset) { i, a in
                    HStack {
                        Text(a); Spacer()
                        Button(role: .destructive) { entry.aliases.remove(at: i) } label: {
                            Image(systemName: "trash")
                        }
                    }
                }
                HStack {
                    TextField("Alias hinzufügen", text: $aliasText)
                    Button("Add") {
                        let t = aliasText.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !t.isEmpty else { return }
                        entry.aliases.append(t); aliasText = ""
                    }
                }
            }
        }
        .navigationTitle(entry.name)
    }
}
