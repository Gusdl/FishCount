import Foundation
import SwiftData

final class SurveyStore: ObservableObject {
    @Published var currentSurvey: Survey?
    private weak var context: ModelContext?

    func bind(to survey: Survey, context: ModelContext) {
        currentSurvey = survey
        self.context = context
    }

    func addEntry(species: String, sizeLabel: String, count: Int, note: String?) {
        guard let survey = currentSurvey else { return }
        let entry = CountEntry(species: species, sizeClass: sizeLabel, count: count, comment: note)
        survey.entries.append(entry)
        try? context?.save()
    }

    func remove(_ entry: CountEntry) {
        if let survey = currentSurvey,
           let index = survey.entries.firstIndex(where: { $0.id == entry.id }) {
            survey.entries.remove(at: index)
        }
        context?.delete(entry)
        try? context?.save()
    }

    func save() {
        try? context?.save()
    }
}
