import Foundation

enum CSVExporter {
    static func makeCSV(from survey: Survey) -> String {
        var rows: [String] = ["Survey,Date,Species,SizeClass,Count,Comment"]
        let df = ISO8601DateFormatter()
        for entry in survey.entries.sorted(by: { $0.createdAt < $1.createdAt }) {
            let columns: [String] = [
                escape(survey.title),
                df.string(from: entry.createdAt),
                escape(entry.species),
                escape(entry.sizeClass),
                "\(entry.count)",
                escape(entry.comment ?? "")
            ]
            rows.append(columns.joined(separator: ","))
        }
        return rows.joined(separator: "\n")
    }

    private static func escape(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }
}

enum JSONExporter {
    static func makeJSON(from survey: Survey) throws -> Data {
        let payload: [[String: Any]] = survey.entries.sorted(by: { $0.createdAt < $1.createdAt }).map { entry in
            [
                "survey": survey.title,
                "timestamp": ISO8601DateFormatter().string(from: entry.createdAt),
                "species": entry.species,
                "sizeClass": entry.sizeClass,
                "count": entry.count,
                "comment": entry.comment ?? ""
            ]
        }
        return try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
    }
}

extension FileManager {
    func writeTemporary(data: Data, fileName: String) throws -> URL {
        let sanitized = fileName.replacingOccurrences(of: ":", with: "-")
        let url = temporaryDirectory.appendingPathComponent(sanitized)
        try data.write(to: url, options: .atomic)
        return url
    }
}
