import SwiftUI
import SwiftData
import Charts

struct SurveyDetailView: View {
    @Bindable var survey: Survey

    @State private var selection: DetailSection = .capture

    var body: some View {
        VStack(spacing: 0) {
            Picker("Bereich", selection: $selection) {
                ForEach(DetailSection.allCases, id: \.self) { section in
                    Text(section.title).tag(section)
                }
            }
            .pickerStyle(.segmented)
            .padding([.horizontal, .top])

            TabView(selection: $selection) {
                CaptureView(survey: survey)
                    .tag(DetailSection.capture)
                AnalysisContainerView(survey: survey)
                    .tag(DetailSection.analysis)
                ExportView(survey: survey)
                    .tag(DetailSection.export)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .navigationTitle(survey.title)
    }

    enum DetailSection: CaseIterable {
        case capture
        case analysis
        case export

        var title: String {
            switch self {
            case .capture: return "Erfassung"
            case .analysis: return "Analyse"
            case .export: return "Export"
            }
        }
    }
}

private struct AnalysisContainerView: View {
    let survey: Survey

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if survey.entries.isEmpty {
                    ContentUnavailableView("Noch keine Daten",
                                           systemImage: "chart.bar.fill",
                                           description: Text("Sobald Einträge vorhanden sind, siehst du hier die Auswertung."))
                } else {
                    SurveyBreakdownChart(entries: survey.entries)
                    Divider()
                    GroupedList(entries: survey.entries)
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }
}

private struct GroupedList: View {
    let entries: [CountEntry]

    private var grouped: [String: [CountEntry]] {
        Dictionary(grouping: entries, by: { $0.species })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Aufschlüsselung")
                .font(.headline)
            ForEach(grouped.keys.sorted(), id: \.self) { species in
                let speciesEntries = grouped[species] ?? []
                VStack(alignment: .leading, spacing: 6) {
                    Text(species)
                        .font(.headline)
                    ForEach(speciesEntries.sorted(by: { $0.sizeClass < $1.sizeClass })) { entry in
                        HStack {
                            Text(entry.sizeClass)
                            Spacer()
                            Text("\(entry.count)")
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }
}
