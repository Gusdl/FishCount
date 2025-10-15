import Foundation

let voiceNumberWords: [String: Double] = [
    "null": 0,
    "eins": 1,
    "eine": 1,
    "ein": 1,
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

func parseSizeCM(from text: String) -> Double? {
    let t = text.lowercased().replacingOccurrences(of: ",", with: ".")
    if let r = t.range(of: #"(\d+(?:\.\d+)?)\s*(cm|zentimeter)"#, options: .regularExpression) {
        let n = String(t[r]).components(separatedBy: CharacterSet(charactersIn: "0123456789.").inverted).joined()
        return Double(n)
    }
    for (w, v) in voiceNumberWords {
        if t.contains("\(w) cm") || t.contains("\(w) zentimeter") { return v }
    }
    return nil
}

func normalizeSpecies(from text: String) -> String? {
    let t = text.lowercased()
    for species in SpeciesCatalog.load() {
        if t.contains(species.name.lowercased()) { return species.name }
        for alias in species.aliases where t.contains(alias.lowercased()) {
            return species.name
        }
    }
    return nil
}

func detectYOY(_ text: String) -> Bool {
    let t = text.lowercased()
    return t.contains("0+") || t.contains("0 plus") || t.contains("jungfisch") || t.contains("jungfische")
}

func detectCount(from text: String, defaultCount: Int) -> Int {
    let nsText = text as NSString
    let number = nsText.integerValue
    if number > 0 { return number }
    let lower = text.lowercased()
    for (word, value) in voiceNumberWords {
        if lower.contains("\(word) st") || lower.hasSuffix(" \(word)") { return Int(value) }
    }
    return defaultCount
}

func entry(from text: String, fallbackBin: SizeBin, defaultCount: Int = 1) -> SurveyEntry? {
    guard let species = normalizeSpecies(from: text) else { return nil }
    let cm = parseSizeCM(from: text)
    let lower = text.lowercased()
    let adjustedBin: SizeBin
    if let cm {
        var effective = cm
        if lower.contains("bis") || lower.contains("≤") || lower.contains("unter") {
            effective = max(cm - 0.1, 0)
        }
        adjustedBin = SizeBin.bin(forCM: effective)
    } else {
        adjustedBin = fallbackBin
    }
    let count = detectCount(from: text, defaultCount: defaultCount)
    let isYOY = detectYOY(text)
    return SurveyEntry(species: species, sizeBin: adjustedBin, count: count, isYOY: isYOY, timestamp: Date())
}
