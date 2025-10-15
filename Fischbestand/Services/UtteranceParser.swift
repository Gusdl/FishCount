import Foundation

struct ParsedEntry {
    let species: String
    let sizeLabel: String
    let count: Int
    let note: String?
}

enum UtteranceParser {
    static let numberWords: [String: Int] = [
        "ein": 1, "eine": 1, "einen": 1, "eins": 1,
        "zwei": 2, "drei": 3, "vier": 4, "fünf": 5, "sechs": 6, "sieben": 7, "acht": 8, "neun": 9, "zehn": 10,
        "elf": 11, "zwölf": 12, "dreizehn": 13, "vierzehn": 14, "fünfzehn": 15, "sechzehn": 16, "siebzehn": 17, "achtzehn": 18, "neunzehn": 19, "zwanzig": 20
    ]

    static func parse(_ text: String, speciesCatalog: [String]) -> ParsedEntry? {
        let lower = text.lowercased()
            .replacingOccurrences(of: ",", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "  ", with: " ")

        let count = extractCount(from: lower) ?? 1
        let size = extractSize(from: lower) ?? "bis 5 cm"
        let species = fuzzySpecies(in: lower, catalog: speciesCatalog) ?? "Unbestimmt"
        let note: String? = lower.contains("jungfisch") ? "Jungfische" : nil

        return ParsedEntry(species: species, sizeLabel: size, count: count, note: note)
    }

    private static func extractCount(from s: String) -> Int? {
        let patterns = [#"(\d+)\s*st(ue|ü)ck"#, #"(\d+)\s*$"#]
        for p in patterns {
            if let m = s.range(of: p, options: .regularExpression) {
                let n = Int(s[m].components(separatedBy: CharacterSet.decimalDigits.inverted).joined())
                if let n, n > 0 { return n }
            }
        }
        for (w, n) in numberWords {
            if s.contains("\(w) st") || s.hasSuffix(" \(w)") { return n }
        }
        return nil
    }

    private static func extractSize(from s: String) -> String? {
        if let r = s.range(of: #"bis\s*(\d{1,3})\s*(cm|zentimeter)"#, options: .regularExpression) {
            let t = String(s[r])
            let num = t.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
            if !num.isEmpty { return "bis \(num) cm" }
        }
        if let r = s.range(of: #"(\d{1,3})\s*(bis|–|-)\s*(\d{1,3})\s*(cm|zentimeter)"#, options: .regularExpression) {
            let t = String(s[r])
            let nums = t.components(separatedBy: CharacterSet.decimalDigits.inverted).filter { !$0.isEmpty }
            if nums.count >= 2 { return "\(nums[0])–\(nums[1]) cm" }
        }
        if let r = s.range(of: #"unter\s*(\d{1,3})\s*(cm|zentimeter)"#, options: .regularExpression) {
            let t = String(s[r])
            let num = t.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
            if !num.isEmpty { return "bis \(num) cm" }
        }
        return nil
    }

    private static func fuzzySpecies(in s: String, catalog: [String]) -> String? {
        let tokens = Set(s.split { !$0.isLetter }.map(String.init))
        var best: (name: String, score: Int)? = nil
        for name in catalog {
            let nlow = name.lowercased()
            let score = tokens.contains(nlow) ? 0 : levenshtein(a: nlow, b: s)
            if best == nil || score < best!.score { best = (name, score) }
        }
        return best?.name
    }

    private static func levenshtein(a: String, b: String) -> Int {
        let a = Array(a), b = Array(b)
        var d = Array(repeating: Array(repeating: 0, count: b.count + 1), count: a.count + 1)
        for i in 0...a.count { d[i][0] = i }
        for j in 0...b.count { d[0][j] = j }
        for i in 1...a.count {
            for j in 1...b.count {
                d[i][j] = min(
                    d[i - 1][j] + 1,
                    d[i][j - 1] + 1,
                    d[i - 1][j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1)
                )
            }
        }
        return d[a.count][b.count]
    }
}
