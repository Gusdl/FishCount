import SwiftUI
import Charts

struct SurveyBreakdownChart: View {
    let entries: [CountEntry]

    private var totals: [ChartEntry] {
        let grouped = Dictionary(grouping: entries) { entry in
            (entry.sizeClass, entry.species)
        }
        return grouped.map { key, values in
            ChartEntry(sizeClass: key.0, species: key.1, total: values.reduce(0) { $0 + $1.count })
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Verteilung")
                .font(.headline)
                .foregroundStyle(.white)
            Chart(totals) { entry in
                BarMark(
                    x: .value("Größenklasse", entry.sizeClass),
                    y: .value("Anzahl", entry.total)
                )
                .foregroundStyle(by: .value("Art", entry.species))
                .cornerRadius(6)
            }
            .frame(height: 260)
            .chartLegend(.visible)
            .chartXAxis {
                AxisMarks(values: .automatic) { value in
                    AxisGridLine()
                    AxisValueLabel().font(.caption)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private struct ChartEntry: Identifiable {
        var id: String { "\(species)-\(sizeClass)" }
        let sizeClass: String
        let species: String
        let total: Int
    }
}
