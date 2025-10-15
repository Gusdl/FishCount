import Foundation

struct ParsedCommand {
    let species: String
    let sizeRange: SizeRange
    let count: Int
    let isYOY: Bool
    let rawText: String
}

private let wordNumbers: [String: Int] = [
    "eins": 1,
    "ein": 1,
    "eine": 1,
    "einen": 1,
    "zwei": 2,
    "drei": 3,
    "vier": 4,
    "fünf": 5,
    "funf": 5,
    "sechs": 6,
    "sieben": 7,
    "acht": 8,
    "neun": 9,
    "zehn": 10,
    "elf": 11,
    "zwölf": 12,
    "zwolf": 12,
    "dreizehn": 13,
    "vierzehn": 14,
    "fünfzehn": 15,
    "funfzehn": 15,
    "sechzehn": 16,
    "siebzehn": 17,
    "achtzehn": 18,
    "neunzehn": 19,
    "zwanzig": 20
]

private func normalize(_ s: String) -> String {
    s
        .lowercased()
        .replacingOccurrences(of: ",", with: ".")
        .replacingOccurrences(of: "  ", with: " ")
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

private func numberFromToken(_ t: String) -> Double? {
    if let n = Double(t.replacingOccurrences(of: ",", with: ".")) { return n }
    if let n = wordNumbers[t] { return Double(n) }
    return nil
}

private func intFromToken(_ t: String) -> Int? {
    if let d = numberFromToken(t) { return Int(d.rounded()) }
    return nil
}

func detectYOY(_ text: String) -> Bool {
    let t = text.lowercased()
    return t.contains("0+") || t.contains("0 plus") || t.contains("jungfisch") || t.contains("jungfische")
}

struct VoiceParser {
    static func extractCommands(from buffer: String,
                                speciesCatalog: [String],
                                defaultSize: SizeRange?) -> (commands: [ParsedCommand], remainder: String) {

        var text = normalize(buffer)
            .replacingOccurrences(of: " stück", with: " stueck")
            .replacingOccurrences(of: " jungfisch", with: " jungfische")

        var commands: [ParsedCommand] = []

        let tokens = text.split(whereSeparator: { !$0.isLetter && !$0.isNumber && $0 != "." }).map { String($0) }

        var catalog: [(key: String, value: String)] = []
        var seenKeys = Set<String>()
        for name in speciesCatalog {
            let key = name.lowercased()
            if seenKeys.insert(key).inserted {
                catalog.append((key: key, value: name))
            }
        }
        catalog.sort { $0.key.count > $1.key.count }

        var i = 0
        while i < tokens.count {
            let token = tokens[i]
            guard let speciesMatch = catalog.first(where: { token.hasPrefix($0.key) || $0.key.hasPrefix(token) }) else {
                i += 1
                continue
            }
            let species = speciesMatch.value

            var cmValue: Double?
            var isUpperBound = false
            let window = max(0, i - 3)...min(tokens.count - 1, i + 4)

            for j in window {
                let t = tokens[j]
                if t == "bis" { isUpperBound = true; continue }
                if t == "cm" || t == "zentimeter" { continue }
                if t.hasSuffix("cm"), let n = numberFromToken(String(t.dropLast(2))) { cmValue = n; break }
                if let n = numberFromToken(t) {
                    if j + 1 <= window.upperBound, tokens[j + 1] == "cm" || tokens[j + 1] == "zentimeter" {
                        cmValue = n
                        break
                    }
                    if isUpperBound {
                        cmValue = n
                        break
                    }
                }
            }

            var count = 1
            for j in i...min(tokens.count - 1, i + 5) {
                let t = tokens[j]
                if t == "stueck" { continue }
                if let c = intFromToken(t) {
                    count = max(1, c)
                    break
                }
            }

            let sizeRange: SizeRange = {
                guard let cm = cmValue else {
                    if let fallback = defaultSize { return fallback }
                    return SizeBuckets.default.first!
                }

                if isUpperBound {
                    if let match = SizeBuckets.default.first(where: { range in
                        if let upper = range.upper { return cm <= upper }
                        return false
                    }) {
                        return match
                    }
                    return SizeBuckets.default.first!
                }

                return SizeBuckets.bucket(for: cm)
            }()

            let rawTokens = tokens[max(0, i - 2)...min(tokens.count - 1, i + 5)]
            let raw = rawTokens.joined(separator: " ")
            let command = ParsedCommand(species: species,
                                        sizeRange: sizeRange,
                                        count: count,
                                        isYOY: detectYOY(raw),
                                        rawText: raw)
            commands.append(command)

            i += 6
        }

        return (commands, "")
    }
}
