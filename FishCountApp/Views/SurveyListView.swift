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
            List {
                Section {
                    ForEach(surveys) { survey in
                        NavigationLink(value: survey) {
                            SurveyRow(survey: survey)
                        }
                    }
                    .onDelete(perform: delete)
                }
            }
            .navigationDestination(for: Survey.self) { survey in
                SurveyDetailView(survey: survey)
            }
            .navigationTitle("Zählungen")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { showSettings = true }) {
                        Label("Einstellungen", systemImage: "gearshape")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { isAddingSurvey = true }) {
                        Label("Neu", systemImage: "plus")
                    }
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
            .overlay {
                if surveys.isEmpty {
                    ContentUnavailableView("Noch keine Zählung",
                                           systemImage: "list.bullet",
                                           description: Text("Lege deine erste Session mit dem Plus-Button an."))
                }
            }
        }
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
        VStack(alignment: .leading, spacing: 4) {
            Text(survey.title)
                .font(.headline)
            HStack(spacing: 8) {
                Text(survey.date, style: .date)
                if !survey.entries.isEmpty {
                    Text("\(survey.entries.count) Einträge")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
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
