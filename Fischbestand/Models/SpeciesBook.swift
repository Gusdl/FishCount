import Foundation

struct SpeciesEntry: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var aliases: [String] = []
}

final class SpeciesBook: ObservableObject {
    @Published var items: [SpeciesEntry] = [] { didSet { save() } }

    private let url: URL = {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return dir.appendingPathComponent("species_book.json")
    }()

    init(defaultSpecies: [String] = SpeciesCatalog.defaultSpecies) {
        if let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode([SpeciesEntry].self, from: data) {
            items = decoded
        } else {
            items = defaultSpecies.map { SpeciesEntry(name: $0) }
            save()
        }
    }

    func namesAndAliases() -> [String] {
        items.flatMap { [$0.name] + $0.aliases }
    }

    func canonicalName(for value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return value }
        let normalized = normalize(trimmed)
        for entry in items {
            if normalize(entry.name) == normalized { return entry.name }
            for alias in entry.aliases where normalize(alias) == normalized {
                return entry.name
            }
        }
        return trimmed
    }

    private func normalize(_ value: String) -> String {
        value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .replacingOccurrences(of: "ß", with: "ss")
            .replacingOccurrences(of: "-", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func save() {
        if let data = try? JSONEncoder().encode(items) {
            try? data.write(to: url, options: .atomic)
        }
    }
}
