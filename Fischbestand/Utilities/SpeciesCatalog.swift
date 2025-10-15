import Foundation

struct Species: Codable, Hashable {
    var name: String
    var aliases: [String] = []
}

enum SpeciesCatalog {
    static let defaults: [Species] = [
        Species(name: "Barsch"),
        Species(name: "Hecht"),
        Species(name: "Karpfen"),
        Species(name: "Zander"),
        Species(name: "Rotauge"),
        Species(name: "Rotfeder"),
        Species(name: "Bachforelle"),
        Species(name: "Saibling"),
        Species(name: "Schleie"),
        Species(name: "Aal"),
        Species(name: "Äsche"),
        Species(name: "Döbel"),
        Species(name: "Forelle"),
        Species(name: "Wels")
    ]

    private static let prioritizedFeatured = ["Barsch", "Hecht", "Karpfen", "Zander", "Rotfeder"]

    static var url: URL {
        let fm = FileManager.default
        let groupID = "group.com.simonmaiwald.fischbestand"
        let base = fm.containerURL(forSecurityApplicationGroupIdentifier: groupID)
            ?? fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("SpeciesCatalog.json")
    }

    static func load() -> [Species] {
        if let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode([Species].self, from: data) {
            return decoded
        }
        return defaults
    }

    static func save(_ list: [Species]) {
        guard let data = try? JSONEncoder().encode(list) else { return }
        try? data.write(to: url, options: .atomic)
    }

    static var allNames: [String] {
        load().map(\.name).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    static var featuredSpecies: [String] {
        let names = allNames
        let prioritized = prioritizedFeatured.filter { names.contains($0) }
        if prioritized.count >= 5 {
            return prioritized
        }
        let remaining = names.filter { !prioritized.contains($0) }
        return prioritized + remaining.prefix(max(0, 5 - prioritized.count))
    }

    static var defaultSpecies: [String] {
        defaults.map(\.name).sorted()
    }

    static var searchableNames: [String] {
        let species = load()
        var set = Set<String>()
        for entry in species {
            set.insert(entry.name)
            entry.aliases.forEach { set.insert($0) }
        }
        return Array(set)
    }
}
