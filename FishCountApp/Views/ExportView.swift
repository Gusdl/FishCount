import SwiftUI

struct ExportView: View {
    let survey: Survey
    @State private var exportURL: URL?
    @State private var sharePresented = false
    @State private var exportFormat: ExportFormat?

    var body: some View {
        VStack(spacing: 24) {
            illustration
            Text("Teile deine Zählung als CSV oder JSON über das Share-Sheet. Die Dateien werden temporär gespeichert und nach dem Teilen automatisch entfernt.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            VStack(spacing: 16) {
                Button {
                    exportFormat = .csv
                    exportCSV()
                } label: {
                    ExportButtonLabel(title: "CSV exportieren", subtitle: "Für Excel und Tabellen", systemImage: "tablecells")
                }

                Button {
                    exportFormat = .json
                    exportJSON()
                } label: {
                    ExportButtonLabel(title: "JSON exportieren", subtitle: "Für APIs und Weiterverarbeitung", systemImage: "curlybraces")
                }
            }
            .padding(.horizontal)
            Spacer()
        }
        .padding(.top, 40)
        .sheet(isPresented: $sharePresented, onDismiss: cleanupExport) {
            if let exportURL {
                ShareSheet(activityItems: [exportURL])
            }
        }
    }

    private var illustration: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 56))
                .foregroundStyle(.accent)
            Text("Export & Teilen")
                .font(.title2.weight(.semibold))
        }
    }

    private func exportCSV() {
        do {
            let csv = CSVExporter.makeCSV(from: survey)
            exportURL = try FileManager.default.writeTemporary(data: csv.data(using: .utf8)!, fileName: "FishCount-\(survey.title).csv")
            sharePresented = true
        } catch {
            print("CSV export failed: \(error)")
        }
    }

    private func exportJSON() {
        do {
            let json = try JSONExporter.makeJSON(from: survey)
            exportURL = try FileManager.default.writeTemporary(data: json, fileName: "FishCount-\(survey.title).json")
            sharePresented = true
        } catch {
            print("JSON export failed: \(error)")
        }
    }

    private func cleanupExport() {
        if let exportURL {
            try? FileManager.default.removeItem(at: exportURL)
            self.exportURL = nil
        }
    }

    private enum ExportFormat {
        case csv
        case json
    }
}

private struct ExportButtonLabel: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: systemImage)
                .font(.title3)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
    }
}
