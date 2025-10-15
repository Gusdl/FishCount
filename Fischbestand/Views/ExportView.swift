import SwiftUI

struct ExportView: View {
    @EnvironmentObject var store: SurveyStore
    @State private var shareItems: [Any] = []
    @State private var showShare = false

    var body: some View {
        VStack(spacing: 16) {
            Button("Als CSV teilen") {
                guard let survey = store.currentSurvey else { return }
                let rows = SurveyExport.rows(from: survey)
                let url = SurveyExport.makeCSV(rows: rows)
                present(url)
            }
            Button("Als Excel (.xlsx) teilen") {
                guard let survey = store.currentSurvey else { return }
                let rows = SurveyExport.rows(from: survey)
                if let url = try? SurveyExport.makeXLSX(rows: rows) {
                    present(url)
                }
            }
        }
        .sheet(isPresented: $showShare) {
            ShareSheet(activityItems: shareItems)
        }
        .navigationTitle("Export")
    }

    private func present(_ url: URL) {
        shareItems = [url]; showShare = true
    }
}
