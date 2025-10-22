import Foundation

enum SpeechHints {
    private static let fallbackSpecies: [String] = [
        "Äsche", "Bachforelle", "Regenbogenforelle", "Elritze", "Grundel",
        "Schmerle", "Groppe", "Döbel", "Hasel", "Schneider", "Rotauge",
        "Rotfeder", "Aal", "Hecht", "Zander", "Wels", "Karpfen",
        "Brachse", "Schleie", "Stichling", "Bitterling", "Rapfen"
    ]

    static func species(_ override: [String]? = nil) -> [String] {
        if let override, !override.isEmpty {
            return override
        }
        return fallbackSpecies
    }

    static let sizeWords: [String] = [
        "bis", "unter", "über", "zirka", "rund",
        "zentimeter", "cm", "millimeter", "mm",
        "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10",
        "12", "15", "18", "20", "25", "30", "35", "40", "45", "50", "60"
    ]

    static let countWords: [String] = [
        "eins", "ein", "eine", "einen", "zwei", "drei", "vier", "fünf", "sechs", "sieben",
        "acht", "neun", "zehn", "elf", "zwölf", "dreizehn", "vierzehn", "fünfzehn",
        "stueck", "stück", "exemplar", "exemplare", "mal", "x"
    ]

    static let qualifiers: [String] = [
        "jungfisch", "jungfische", "adult", "groß", "klein", "maßig", "maß"
    ]

    static func contextWords(speciesCatalog: [String]? = nil) -> [String] {
        let combined = species(speciesCatalog) + sizeWords + countWords + qualifiers
        return Array(Set(combined))
    }
}
