import SwiftUI

struct ExportView: View {
    let survey: Survey
    @State private var exportURL: URL?
    @State private var sharePresented = false
    @State private var exportFormat: ExportFormat?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                illustration
                    .glassCard()

                Text("Teile deine Zählung als CSV oder JSON über das Share-Sheet. Die Dateien werden temporär gespeichert und nach dem Teilen automatisch entfernt.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(AppTheme.subtleText)
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
                .glassCard()
            }
            .padding(.horizontal)
            .padding(.top, 40)
            .padding(.bottom, 60)
        }
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
                .foregroundStyle(AppTheme.primaryAccent)
            Text("Export & Teilen")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
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
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(AppTheme.subtleText)
            }
            Spacer()
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(AppTheme.primaryAccent)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
