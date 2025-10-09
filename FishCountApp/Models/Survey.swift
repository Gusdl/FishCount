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
    var createdAt: Date = Date()

    init(species: String, sizeClass: String, count: Int, comment: String? = nil) {
        self.species = species
        self.sizeClass = sizeClass
        self.count = count
        self.comment = comment
    }
}

@Model
final class SizeClassPreset {
    var id: UUID = UUID()
    var label: String
    var lowerBound: Int?
    var upperBound: Int?
    var isDefault: Bool = false

    init(label: String, lowerBound: Int?, upperBound: Int?, isDefault: Bool = false) {
        self.label = label
        self.lowerBound = lowerBound
        self.upperBound = upperBound
        self.isDefault = isDefault
    }
}
