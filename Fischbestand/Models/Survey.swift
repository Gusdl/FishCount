import Foundation
import SwiftData

@Model
final class Survey {
    var id: UUID = UUID()
    var title: String
    var date: Date = Date()
    var locationName: String?
    var latitude: Double?
    var longitude: Double?
    var weatherNote: String?
    @Relationship(deleteRule: .cascade) var entries: [CountEntry] = []

    init(title: String, entries: [CountEntry] = []) {
        self.title = title
        self.entries = entries
    }
}

@Model
final class CountEntry {
    var id: UUID = UUID()
    var species: String
    var sizeClass: String
    var count: Int
    var comment: String?
    var isYOY: Bool = false
    var createdAt: Date = Date()

    init(species: String, sizeClass: String, count: Int, comment: String? = nil, isYOY: Bool = false, createdAt: Date = Date()) {
        self.species = species
        self.sizeClass = sizeClass
        self.count = count
        self.comment = comment
        self.isYOY = isYOY
        self.createdAt = createdAt
    }
}

extension CountEntry {
    var sizeBin: SizeBin {
        get {
            let trimmed = sizeClass.trimmingCharacters(in: .whitespacesAndNewlines)
            if let direct = SizeBin.ordered.first(where: { $0.title == trimmed }) {
                return direct
            }
            let sanitized = trimmed
                .lowercased()
                .replacingOccurrences(of: "cm", with: "")
                .replacingOccurrences(of: " ", with: "")
            let legacyMap: [String: SizeBin] = [
                "0–5": .le5,
                "bis5": .le5,
                "6–10": .gt5to10,
                "11–15": .gt10to15,
                "16–20": .gt15to20,
                "21–25": .gt20to25,
                "26–30": .gt25to30,
                "31–40": .gt30to40,
                "41–50": .gt40to50,
                "51–60": .gt50to60,
                "über60": .gt60,
                "ueber60": .gt60,
                ">60": .gt60
            ]
            if let mapped = legacyMap[sanitized] {
                return mapped
            }
            return .le5
        }
        set {
            sizeClass = newValue.title
        }
    }

    convenience init(from entry: SurveyEntry) {
        self.init(
            species: entry.species,
            sizeClass: entry.sizeBin.title,
            count: entry.count,
            comment: entry.note,
            isYOY: entry.isYOY,
            createdAt: entry.timestamp
        )
        self.id = entry.id
    }
}

