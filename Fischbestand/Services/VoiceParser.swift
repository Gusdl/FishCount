import Foundation

struct ParsedEntry: Equatable {
    let species: String
    let sizeClass: String
    let count: Int
    let comment: String?
}

enum VoiceCommand: Equatable {
    case add(ParsedEntry)
    case undo
    case none
}

struct VoiceParser {
    private let aliasLookup: [String: String]
    private let aliasCandidates: [String]
    private let canonicalSpecies: [String]

    init(speciesList: [String] = SpeciesCatalog.allSpecies, speciesAliases: [String: [String]] = [:]) {
        canonicalSpecies = speciesList
        var lookup: [String: String] = [:]
        var candidateSet: Set<String> = []

        for species in speciesList {
            lookup[FuzzyMatcher.normalize(species)] = species
            candidateSet.insert(species)
        }

        for (canonical, variants) in speciesAliases {
            lookup[FuzzyMatcher.normalize(canonical)] = canonical
            candidateSet.insert(canonical)
            for variant in variants {
                lookup[FuzzyMatcher.normalize(variant)] = canonical
                candidateSet.insert(variant)
            }
        }

        aliasLookup = lookup
        aliasCandidates = Array(candidateSet).sorted()
    }

    func parse(text: String) -> VoiceCommand {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .none }
        let lower = trimmed.lowercased()

        if lower.contains("rückgängig") || lower.contains("undo") || lower.contains("letzte löschen") {
            return .undo
        }

        let parts = lower.split(separator: "kommentar:", maxSplits: 1, omittingEmptySubsequences: false)
        let main = parts.first.map(String.init) ?? lower
        let comment = parts.count > 1 ? String(parts[1]).trimmingCharacters(in: .whitespaces) : nil

        guard let size = detectSizeClass(in: main) else { return .none }
        let count = detectCount(in: main) ?? 1
        let speciesTokens = extractSpeciesTokens(from: main, removing: size, count: count)
        guard !speciesTokens.isEmpty else { return .none }
        let species = resolveSpecies(from: speciesTokens)

        let normalizedSize = size
            .replacingOccurrences(of: "cm", with: " cm")
            .replacingOccurrences(of: "bis", with: "bis ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespaces)

        let entry = ParsedEntry(species: species, sizeClass: normalizedSize.capitalizedSizeLabel(), count: count, comment: comment)
        return .add(entry)
    }

    func canonicalSpecies(from text: String) -> String {
        return resolveSpecies(from: text)
    }

    private func detectSizeClass(in text: String) -> String? {
        if let range = text.range(of: #"(\d{1,3})\s*bis\s*(\d{1,3})\s*cm"#, options: .regularExpression) {
            return String(text[range]).replacingOccurrences(of: " ", with: "")
        }

        if let range = text.range(of: #"bis\s*(\d{1,3})\s*cm"#, options: .regularExpression) {
            return String(text[range]).replacingOccurrences(of: " ", with: "")
        }

        if let range = text.range(of: #"ab\s*(\d{1,3})\s*cm"#, options: .regularExpression) {
            return String(text[range]).replacingOccurrences(of: " ", with: "")
        }

        return nil
    }

    private func detectCount(in text: String) -> Int? {
        if let range = text.range(of: #"(\d{1,3})\s*(st(ü|u)ck|tiere)?"#, options: .regularExpression) {
            let num = String(text[range]).components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
            if let value = Int(num), value > 0 { return value }
        }

        let tokens = text.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
        for token in tokens {
            if let value = VoiceParser.parseGermanNumber(token) {
                return value
            }
        }
        return nil
    }

    private func extractSpeciesTokens(from text: String, removing size: String, count: Int) -> String {
        var cleaned = text
        cleaned = cleaned.replacingOccurrences(of: size, with: "")
        if let countRange = cleaned.range(of: #"(\d{1,3})\s*(st(ü|u)ck|tiere)?"#, options: .regularExpression) {
            cleaned.removeSubrange(countRange)
        }
        VoiceParser.numberWords.forEach { word in
            cleaned = cleaned.replacingOccurrences(of: " " + word + " ", with: " ")
        }
        cleaned = cleaned.replacingOccurrences(of: "kommentar:", with: "")
        cleaned = cleaned.replacingOccurrences(of: ",", with: " ")
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func resolveSpecies(from text: String) -> String {
        let normalized = FuzzyMatcher.normalize(text)
        if let canonical = aliasLookup[normalized] {
            return canonical
        }

        if let aliasMatch = FuzzyMatcher.bestMatch(for: text, in: aliasCandidates, threshold: 0.7) {
            let normalizedAlias = FuzzyMatcher.normalize(aliasMatch)
            if let canonical = aliasLookup[normalizedAlias] {
                return canonical
            }
        }

        if let canonicalMatch = FuzzyMatcher.bestMatch(for: text, in: canonicalSpecies, threshold: 0.65) {
            return canonicalMatch
        }

        return text.capitalized
    }

    static func parseGermanNumber(_ token: String) -> Int? {
        let mapping: [String: Int] = numberWordMap
        if let value = mapping[token.lowercased()] { return value }
        let digits = token.filter { $0.isNumber }
        return Int(digits)
    }

    private static let numberWordMap: [String: Int] = {
        var map: [String: Int] = [
            "null": 0, "eins": 1, "ein": 1, "eine": 1, "einen": 1, "erstes": 1,
            "zwei": 2, "drei": 3, "vier": 4, "fünf": 5, "sechs": 6,
            "sieben": 7, "acht": 8, "neun": 9, "zehn": 10, "elf": 11, "zwölf": 12,
            "dreizehn": 13, "vierzehn": 14, "fünfzehn": 15, "sechzehn": 16,
            "siebzehn": 17, "achtzehn": 18, "neunzehn": 19, "zwanzig": 20
        ]
        return map
    }()

    private static let numberWords: [String] = Array(numberWordMap.keys)
}

private extension String {
    func capitalizedSizeLabel() -> String {
        guard contains("cm") else { return capitalized }
        let sanitized = replacingOccurrences(of: "cm", with: " cm")
        return sanitized.replacingOccurrences(of: "  ", with: " ").trimmingCharacters(in: .whitespaces).capitalized
    }
}
