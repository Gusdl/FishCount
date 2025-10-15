import Foundation
import SwiftData

final class SurveyStore: ObservableObject {
    @Published var currentSurvey: Survey? {
        didSet { reloadEntries() }
    }
    @Published private(set) var entries: [SurveyEntry] = []

    private weak var context: ModelContext?

    func bind(to survey: Survey, context: ModelContext) {
        currentSurvey = survey
        self.context = context
        reloadEntries()
    }

    func add(_ entry: SurveyEntry) {
        guard let survey = currentSurvey else { return }
        let model = entry.makeCountEntry()
        survey.entries.insert(model, at: 0)
        try? context?.save()
        reloadEntries()
    }

    func delete(at offsets: IndexSet) {
        guard let survey = currentSurvey else { return }
        let ids = offsets.map { entries[$0].id }
        for id in ids {
            guard let modelIndex = survey.entries.firstIndex(where: { $0.id == id }) else { continue }
            let model = survey.entries.remove(at: modelIndex)
            context?.delete(model)
        }
        try? context?.save()
        reloadEntries()
    }

    func delete(_ entry: SurveyEntry) {
        guard let survey = currentSurvey,
              let index = survey.entries.firstIndex(where: { $0.id == entry.id }) else { return }
        let model = survey.entries.remove(at: index)
        context?.delete(model)
        try? context?.save()
        reloadEntries()
    }

    func remove(_ entry: CountEntry) {
        let surveyEntry = SurveyEntry(from: entry)
        delete(surveyEntry)
    }

    func save() {
        try? context?.save()
        reloadEntries()
    }

    private func reloadEntries() {
        guard let survey = currentSurvey else {
            entries = []
            return
        }
        entries = survey.entries.map(SurveyEntry.init(from:)).sorted(by: { $0.timestamp > $1.timestamp })
    }
}
