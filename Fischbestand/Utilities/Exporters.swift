import Foundation
import ZIPFoundation

struct ExportRow: Codable {
    let dateISO: String
    let species: String
    let sizeLabel: String
    let count: Int
    let note: String
}

enum SurveyExport {
    static func makeCSV(rows: [ExportRow]) -> URL {
        let headers = ["Zeit", "Art", "Größe", "Anzahl", "Kommentar"]
        var csv = headers.joined(separator: ";") + "\n"
        let esc: (String) -> String = { $0.replacingOccurrences(of: "\"", with: "\"\"") }
        for r in rows {
            csv += [r.dateISO, r.species, r.sizeLabel, String(r.count), r.note]
                .map { "\"\(esc($0))\"" }.joined(separator: ";") + "\n"
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Fischbestand-\(UUID().uuidString).csv")
        try? csv.data(using: .utf8)!.write(to: url)
        return url
    }

    static func makeXLSX(rows: [ExportRow]) throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("xlsx-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let relsDir = root.appendingPathComponent("_rels", isDirectory: true)
        let xlDir = root.appendingPathComponent("xl", isDirectory: true)
        let xlRels = xlDir.appendingPathComponent("_rels", isDirectory: true)
        let wsDir = xlDir.appendingPathComponent("worksheets", isDirectory: true)
        try [relsDir, xlDir, xlRels, wsDir].forEach {
            try FileManager.default.createDirectory(at: $0, withIntermediateDirectories: true)
        }

        let contentTypes = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
          <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
          <Default Extension="xml" ContentType="application/xml"/>
          <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
          <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
        </Types>
        """
        try contentTypes.data(using: .utf8)!.write(to: root.appendingPathComponent("[Content_Types].xml"))

        let rels = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
        </Relationships>
        """
        try rels.data(using: .utf8)!.write(to: relsDir.appendingPathComponent(".rels"))

        let workbook = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"
                  xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
          <sheets><sheet name="Daten" sheetId="1" r:id="rId1"/></sheets>
        </workbook>
        """
        try workbook.data(using: .utf8)!.write(to: xlDir.appendingPathComponent("workbook.xml"))

        let wbRels = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
        </Relationships>
        """
        try wbRels.data(using: .utf8)!.write(to: xlRels.appendingPathComponent("workbook.xml.rels"))

        let headers = ["Zeit", "Art", "Größe", "Anzahl", "Kommentar"]
        let allRows: [[String]] = [headers] + rows.map { [$0.dateISO, $0.species, $0.sizeLabel, String($0.count), $0.note] }

        func colRef(_ idx: Int) -> String { var i = idx, s = ""; repeat { s = String(UnicodeScalar(65 + (i % 26))!) + s; i = i / 26 - 1 } while i >= 0; return s }
        func esc(_ t: String) -> String { t.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;") }

        var sheet = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>
        """
        for (rIdx, row) in allRows.enumerated() {
            let rr = rIdx + 1
            sheet += "<row r=\"\(rr)\">"
            for (cIdx, val) in row.enumerated() {
                let ref = "\(colRef(cIdx))\(rr)"
                sheet += "<c r=\"\(ref)\" t=\"inlineStr\"><is><t>\(esc(val))</t></is></c>"
            }
            sheet += "</row>"
        }
        sheet += "</sheetData></worksheet>"
        try sheet.data(using: .utf8)!.write(to: wsDir.appendingPathComponent("sheet1.xml"))

        let xlsxURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("Fischbestand-\(UUID().uuidString).xlsx")
        guard let archive = Archive(url: xlsxURL, accessMode: .create) else {
            throw NSError(domain: "xlsx", code: -10)
        }
        try archive.addEntry(with: "[Content_Types].xml", relativeTo: root)
        try archive.addEntry(with: "_rels/.rels", relativeTo: root)
        try archive.addEntry(with: "xl/workbook.xml", relativeTo: root)
        try archive.addEntry(with: "xl/_rels/workbook.xml.rels", relativeTo: root)
        try archive.addEntry(with: "xl/worksheets/sheet1.xml", relativeTo: root)
        return xlsxURL
    }

    // Mappe deine Survey-Entries -> ExportRow
    static func rows(from survey: Survey) -> [ExportRow] {
        survey.entries.map {
            ExportRow(
                dateISO: ISO8601DateFormatter().string(from: $0.createdAt),
                species: $0.species,
                sizeLabel: $0.sizeClass,
                count: $0.count,
                note: $0.comment ?? ""
            )
        }
    }
}
