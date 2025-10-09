import SwiftUI
import SwiftData

struct SurveyListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Survey.date, order: .reverse) private var surveys: [Survey]

    @State private var newSurveyTitle: String = ""
    @State private var isAddingSurvey = false
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.backgroundGradient
                    .ignoresSafeArea()

                List {
                    if !surveys.isEmpty {
                        Section {
                            HeroHeader(totalSurveys: surveys.count,
                                       totalEntries: totalEntries,
                                       uniqueSpecies: uniqueSpecies)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))
                        }
                        .textCase(nil)
                    }

                    Section(header: Text("Meine Sessions").foregroundStyle(.white)) {
                        ForEach(surveys) { survey in
                            NavigationLink(value: survey) {
                                SurveyRow(survey: survey)
                            }
                            .listRowBackground(Color.white.opacity(0.1))
                            .listRowSeparator(.hidden)
                        }
                        .onDelete(perform: delete)
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .overlay {
                    if surveys.isEmpty {
                        ContentUnavailableView("Noch keine Zählung",
                                               systemImage: "list.bullet",
                                               description: Text("Lege deine erste Session mit dem Plus-Button an."))
                        .foregroundStyle(.white)
                    }
                }
            }
            .navigationDestination(for: Survey.self) { survey in
                SurveyDetailView(survey: survey)
            }
            .navigationTitle("Zählungen")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.black.opacity(0.2), for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { showSettings = true }) {
                        Label("Einstellungen", systemImage: "gearshape")
                    }
                    .tint(.white)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { isAddingSurvey = true }) {
                        Label("Neu", systemImage: "plus")
                    }
                    .tint(.white)
                }
            }
            .sheet(isPresented: $isAddingSurvey) {
                NewSurveySheet(title: $newSurveyTitle) { title in
                    addSurvey(title: title)
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
        }
    }

    private var totalEntries: Int {
        surveys.reduce(0) { $0 + $1.entries.count }
    }

    private var uniqueSpecies: Int {
        Set(surveys.flatMap { $0.entries.map(\.species) }).count
    }

    private func addSurvey(title: String) {
        let survey = Survey(title: title)
        context.insert(survey)
        try? context.save()
    }

    private func delete(at offsets: IndexSet) {
        offsets.map { surveys[$0] }.forEach(context.delete)
        try? context.save()
    }
}

private struct SurveyRow: View {
    let survey: Survey

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(survey.title)
                .font(.headline)
                .foregroundStyle(.white)
            HStack(spacing: 12) {
                Label {
                    Text(survey.date, style: .date)
                } icon: {
                    Image(systemName: "calendar")
                }
                if !survey.entries.isEmpty {
                    Label {
                        Text("\(survey.entries.count) Einträge")
                    } icon: {
                        Image(systemName: "fish")
                    }
                }
            }
            .labelStyle(.titleAndIcon)
            .font(.caption)
            .foregroundStyle(AppTheme.subtleText)
        }
        .padding(.vertical, 12)
    }
}

private struct HeroHeader: View {
    let totalSurveys: Int
    let totalEntries: Int
    let uniqueSpecies: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Deine Zählungen")
                .font(.title.bold())
                .foregroundStyle(.white)

            HStack(spacing: 16) {
                MetricCard(title: "Sessions", value: totalSurveys)
                MetricCard(title: "Einträge", value: totalEntries)
                MetricCard(title: "Arten", value: uniqueSpecies)
            }
        }
        .padding(20)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private struct MetricCard: View {
    let title: String
    let value: Int

    var body: some View {
        VStack(spacing: 6) {
            Text("\(value)")
                .font(.title2.bold())
                .foregroundStyle(.white)
            Text(title)
                .font(.caption)
                .foregroundStyle(AppTheme.subtleText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct NewSurveySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var title: String
    var onCreate: (String) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Titel")) {
                    TextField("z. B. Elbufer Vormittag", text: $title)
                        .textInputAutocapitalization(.words)
                }
            }
            .navigationTitle("Neue Zählung")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Anlegen") {
                        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        onCreate(trimmed)
                        title = ""
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
