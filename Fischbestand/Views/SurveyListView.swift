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

                if surveys.isEmpty {
                    ContentUnavailableView("Noch keine Zählung",
                                           systemImage: "list.bullet",
                                           description: Text("Lege deine erste Session mit dem Plus-Button an."))
                    .foregroundStyle(.white)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 28) {
                            HeroHeader(totalSurveys: surveys.count,
                                       totalEntries: totalEntries,
                                       uniqueSpecies: uniqueSpecies)

                            SectionHeader(title: "Meine Sessions")
                                .padding(.horizontal, 4)

                            LazyVStack(spacing: 18) {
                                ForEach(surveys) { survey in
                                    NavigationLink(value: survey) {
                                        SurveyRow(survey: survey)
                                    }
                                    .buttonStyle(.plain)
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            withAnimation { delete(survey) }
                                        } label: {
                                            Label("Löschen", systemImage: "trash")
                                        }
                                    }
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            withAnimation { delete(survey) }
                                        } label: {
                                            Label("Löschen", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 28)
                    }
                    .scrollIndicators(.hidden)
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

    private func delete(_ survey: Survey) {
        context.delete(survey)
        try? context.save()
    }
}

private struct SurveyRow: View {
    let survey: Survey

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(survey.title)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Label(survey.date.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                        .font(.caption)
                        .foregroundStyle(AppTheme.subtleText)
                    if let locationName = survey.locationName, !locationName.isEmpty {
                        Label(locationName, systemImage: "mappin.and.ellipse")
                            .font(.caption)
                            .foregroundStyle(AppTheme.subtleText)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.subtleText)
            }

            if !survey.entries.isEmpty {
                HStack(spacing: 16) {
                    MetricPill(icon: "fish", label: "Einträge", value: survey.entries.count)
                    MetricPill(icon: "leaf", label: "Arten", value: Set(survey.entries.map(\.species)).count)
                }
            } else {
                Text("Noch keine Einträge")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.subtleText)
            }
        }
        .padding(18)
        .background(
            LinearGradient(colors: [Color.white.opacity(0.14), Color.white.opacity(0.06)],
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.15))
        )
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
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
        .padding(24)
        .background(
            LinearGradient(colors: [AppTheme.primaryAccent.opacity(0.45), Color.white.opacity(0.08)],
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 28, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.12))
        )
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
        .padding(.vertical, 18)
        .background(
            LinearGradient(colors: [Color.white.opacity(0.16), Color.white.opacity(0.05)],
                           startPoint: .top,
                           endPoint: .bottom),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.1))
        )
    }
}

private struct MetricPill: View {
    let icon: String
    let label: String
    let value: Int

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
            Text("\(value) \(label)")
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.12), in: Capsule(style: .continuous))
        .foregroundStyle(.white)
    }
}

private struct SectionHeader: View {
    let title: String

    var body: some View {
        HStack {
            Label(title, systemImage: "list.bullet")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppTheme.mutedText)
            Spacer()
        }
        .padding(.leading, 12)
        .padding(.bottom, 4)
        .textCase(nil)
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
