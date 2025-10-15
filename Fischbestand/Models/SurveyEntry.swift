import Foundation

struct SurveyEntry: Identifiable, Hashable, Codable {
    let id: UUID
    var species: String
    var sizeBin: SizeBin
    var count: Int
    var isYOY: Bool
    var timestamp: Date
    var note: String?

    init(id: UUID = UUID(), species: String, sizeBin: SizeBin, count: Int, isYOY: Bool, timestamp: Date = Date(), note: String? = nil) {
        self.id = id
        self.species = species
        self.sizeBin = sizeBin
        self.count = count
        self.isYOY = isYOY
        self.timestamp = timestamp
        self.note = note
    }
}

extension SurveyEntry {
    init(from entry: CountEntry) {
        self.id = entry.id
        self.species = entry.species
        self.sizeBin = entry.sizeBin
        self.count = entry.count
        self.isYOY = entry.isYOY
        self.timestamp = entry.createdAt
        self.note = entry.comment
    }

    func makeCountEntry() -> CountEntry {
        let model = CountEntry(
            species: species,
            sizeClass: sizeBin.title,
            count: count,
            comment: note,
            isYOY: isYOY,
            createdAt: timestamp
        )
        model.id = id
        return model
    }
}
