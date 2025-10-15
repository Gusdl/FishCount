import Foundation

struct FieldMeta {
    var gewaesser: String
    var ort: String
    var datum: String
    var leitfaehigkeit: String
    var temperatur: String
}

func exportFieldTemplateCSV(surveyEntries: [SurveyEntry], meta: FieldMeta, speciesOrder: [String]) throws -> URL {
    var table: [String: [SizeBin: Int]] = [:]
    var yoy: [String: Int] = [:]

    for entry in surveyEntries {
        table[entry.species, default: [:]][entry.sizeBin, default: 0] += entry.count
        if entry.isYOY { yoy[entry.species, default: 0] += entry.count }
    }

    let separator = ";"
    var csv = ""
    csv += "Nachgewiesene Arten und Größenklassen [cm]\n"
    csv += "Gewässer:\(separator)\(meta.gewaesser)\n"
    csv += "Ortsangabe:\(separator)\(meta.ort)\n"
    csv += "Datum:\(separator)\(meta.datum)\n"
    csv += "Leitfähigkeit:\(separator)\(meta.leitfaehigkeit) µS/cm\n"
    csv += "Temperatur:\(separator)\(meta.temperatur) °C\n\n"

    csv += (["Art"] + SizeBin.ordered.map(\.title) + ["davon 0+"]).joined(separator: separator) + "\n"

    let allSpecies = Array(Set(table.keys).union(speciesOrder)).sorted {
        let ia = speciesOrder.firstIndex(of: $0) ?? .max
        let ib = speciesOrder.firstIndex(of: $1) ?? .max
        return (ia, $0) < (ib, $1)
    }

    for species in allSpecies {
        var row = [species]
        let counts = table[species] ?? [:]
        for bin in SizeBin.ordered { row.append(String(counts[bin] ?? 0)) }
        row.append(String(yoy[species] ?? 0))
        csv += row.joined(separator: separator) + "\n"
    }
    csv += "\nBesatz:\n"

    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("Fischbestand_\(Int(Date().timeIntervalSince1970)).csv")
    try csv.data(using: .utf8)?.write(to: url, options: .atomic)
    return url
}
