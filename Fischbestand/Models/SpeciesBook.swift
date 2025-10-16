import Foundation
import Combine

struct SpeciesEntry: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var aliases: [String] = []
}

@MainActor
final class SpeciesBook: ObservableObject {
    @Published var items: [SpeciesEntry] = [] { didSet { save() } }

    init(defaultSpecies: [String] = SpeciesCatalog.defaultSpecies) {
        let existing = SpeciesCatalog.load()
        if existing.isEmpty {
            items = defaultSpecies.map { SpeciesEntry(name: $0) }
            save()
        } else {
            items = existing.map { SpeciesEntry(name: $0.name, aliases: $0.aliases) }
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
        let species = items.map { Species(name: $0.name, aliases: $0.aliases) }
        SpeciesCatalog.save(species)
    }
}
