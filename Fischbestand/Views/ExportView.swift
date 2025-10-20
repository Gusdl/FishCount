import SwiftUI

struct ExportView: View {
    @EnvironmentObject var store: SurveyStore
    @State private var shareItems: [Any] = []
    @State private var showShare = false
    @State private var gewaesser: String = ""
    @State private var ort: String = ""
    @State private var datum: String = ""
    @State private var leitfaehigkeit: String = ""
    @State private var temperatur: String = ""
    @State private var exportError: String?

    var body: some View {
        Form {
            Section("Metadaten") {
                TextField("Gewässer", text: $gewaesser)
                TextField("Ortsangabe", text: $ort)
                TextField("Datum (z. B. 2024-07-15)", text: $datum)
                TextField("Leitfähigkeit (µS/cm)", text: $leitfaehigkeit)
                    .keyboardType(.numbersAndPunctuation)
                TextField("Temperatur (°C)", text: $temperatur)
                    .keyboardType(.numbersAndPunctuation)
            }

            Section {
                Button {
                    export()
                } label: {
                    Label("CSV im Feldvorlagen-Layout teilen", systemImage: "square.and.arrow.up")
                }
                .disabled(store.entries.isEmpty)
            }
        }
        .navigationTitle("Export")
        .onAppear(perform: populateDefaults)
        .onChange(of: store.currentSurvey?.id) {
            populateDefaults()
        }
        .sheet(isPresented: $showShare) {
            ShareSheet(activityItems: shareItems)
        }
        .alert("Export fehlgeschlagen", isPresented: Binding(
            get: { exportError != nil },
            set: { _ in exportError = nil }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportError ?? "Unbekannter Fehler")
        }
    }

    private func export() {
        guard let survey = store.currentSurvey else { return }
        do {
            let meta = FieldMeta(gewaesser: gewaesser,
                                 ort: ort,
                                 datum: datum,
                                 leitfaehigkeit: leitfaehigkeit,
                                 temperatur: temperatur)
            let url = try survey.exportProtocolCSV(meta: meta,
                                                   speciesOrder: SpeciesCatalog.all)
            shareItems = [url]
            showShare = true
        } catch {
            exportError = error.localizedDescription
        }
    }

    private func populateDefaults() {
        guard let survey = store.currentSurvey else { return }
        gewaesser = survey.title
        ort = survey.locationName ?? ort
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        datum = formatter.string(from: survey.date)
    }
}
