import SwiftUI
import SwiftData
import Observation
import Charts

struct SurveyDetailView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var store: SurveyStore
    @Bindable var survey: Survey

    @State private var selection: DetailSection = .capture

    var body: some View {
        ZStack {
            AppTheme.backgroundGradient
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Picker("Bereich", selection: $selection) {
                    ForEach(DetailSection.allCases, id: \.self) { section in
                        Text(section.title).tag(section)
                    }
                }
                .pickerStyle(.segmented)
                .padding(10)
                .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .padding(.horizontal)
                .padding(.top, 12)

                TabView(selection: $selection) {
                    CaptureView(survey: survey)
                        .tag(DetailSection.capture)
                    AnalysisContainerView(survey: survey)
                        .tag(DetailSection.analysis)
                    ExportView()
                        .tag(DetailSection.export)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .padding(.top)
        }
        .navigationTitle(survey.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            store.bind(to: survey, context: context)
        }
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
                        .foregroundStyle(.white)
                } else {
                    SurveyBreakdownChart(entries: survey.entries)
                        .glassCard()
                    GroupedList(entries: survey.entries)
                        .glassCard()
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 32)
        }
        .background(Color.clear)
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
                .foregroundStyle(.white)
            ForEach(grouped.keys.sorted(), id: \.self) { species in
                let speciesEntries = grouped[species] ?? []
                VStack(alignment: .leading, spacing: 6) {
                    Text(species)
                        .font(.headline)
                        .foregroundStyle(.white)
                    ForEach(speciesEntries.sorted(by: { $0.sizeBin.title < $1.sizeBin.title })) { entry in
                        HStack {
                            Text(entry.sizeBin.title)
                            Spacer()
                            Text("\(entry.count)")
                        }
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.subtleText)
                    }
                }
                .padding()
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
    }
}
