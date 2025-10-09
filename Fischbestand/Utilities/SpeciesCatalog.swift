import Foundation

enum SpeciesCatalog {
    static let featuredSpecies: [String] = [
        "Barsch", "Hecht", "Karpfen", "Zander", "Rotfeder"
    ]

    static let allSpecies: [String] = [
        "Aal", "Äsche", "Bachforelle", "Barsch", "Döbel", "Forelle", "Hecht", "Karpfen",
        "Rotauge", "Rotfeder", "Saibling", "Schleie", "Wels", "Zander"
    ].sorted()

    static let aliases: [String: [String]] = [
        "Barsch": ["Flussbarsch"],
        "Hecht": ["Esox", "Hechte"],
        "Karpfen": ["Cyprinus"],
        "Rotfeder": ["Plötze", "Roter", "Rotfische"],
        "Rotauge": ["Rotaugen"],
        "Zander": ["Sander"]
    ]

    static var searchableNames: [String] {
        var names: Set<String> = Set(allSpecies)
        for (canonical, variants) in aliases {
            names.insert(canonical)
            variants.forEach { names.insert($0) }
        }
        return Array(names)
    }
}
