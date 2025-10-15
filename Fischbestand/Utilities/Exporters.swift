import Foundation

struct FieldMeta {
    var gewaesser: String
    var ort: String
    var datum: String
    var leitfaehigkeit: String
    var temperatur: String
}

extension Survey {
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    func exportProtocolCSV(meta: FieldMeta? = nil,
                           speciesOrder: [String] = SpeciesCatalog.all) throws -> URL {
        let bins = SizeBuckets.default

        var lines: [String] = []
        func appendLine(_ value: String) { lines.append(value) }

        let meta = meta ?? FieldMeta(gewaesser: title,
                                     ort: locationName ?? "",
                                     datum: formattedDate,
                                     leitfaehigkeit: "",
                                     temperatur: "")

        let water = meta.gewaesser.isEmpty ? title : meta.gewaesser
        let place = meta.ort.isEmpty ? (locationName ?? "") : meta.ort
        let dateString = meta.datum.isEmpty ? formattedDate : meta.datum
        let conductivity = meta.leitfaehigkeit
        let temperature = meta.temperatur

        appendLine("Nachgewiesene Arten und Größenklassen [cm]")
        appendLine("Gewässer:;\(water)")
        appendLine("Ortsangabe:;\(place)")
        appendLine("Datum:;\(dateString)")
        appendLine("Leitfähigkeit:; \(conductivity) µS/cm")
        appendLine("Temperatur:; \(temperature) °C")

        let header = "Art;" + bins.map(\.label).joined(separator: ";") + ";davon 0+"
        appendLine(header)

        let surveyEntries = entries.map(SurveyEntry.init(from:))

        var matrix: [String: [SizeRange: Int]] = [:]
        var zeroPlus: [String: Int] = [:]

        for entry in surveyEntries {
            let key = entry.species
            var sizeCounts = matrix[key, default: [:]]
            sizeCounts[entry.sizeBin.sizeRange, default: 0] += entry.count
            matrix[key] = sizeCounts
            if entry.isYOY { zeroPlus[key, default: 0] += entry.count }
        }

        let orderedSpecies = speciesOrder + matrix.keys.filter { !speciesOrder.contains($0) }
        var rendered = Set<String>()
        for species in orderedSpecies {
            guard !rendered.contains(species) else { continue }
            rendered.insert(species)
            let counts = matrix[species] ?? [:]
            let rowCounts = bins.map { String(counts[$0, default: 0]) }
            let yoy = zeroPlus[species, default: 0]
            appendLine(([species] + rowCounts + [String(yoy)]).joined(separator: ";"))
        }

        if !rendered.contains("Unbestimmt") {
            rendered.insert("Unbestimmt")
            let counts = matrix["Unbestimmt"] ?? [:]
            let rowCounts = bins.map { String(counts[$0, default: 0]) }
            let yoy = zeroPlus["Unbestimmt", default: 0]
            appendLine((["Unbestimmt"] + rowCounts + [String(yoy)]).joined(separator: ";"))
        }

        appendLine("Besatz:")

        let csv = lines.joined(separator: "\n")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Fischbestand_\(Int(Date().timeIntervalSince1970)).csv")
        try csv.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
