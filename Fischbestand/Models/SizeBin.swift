import Foundation

enum SizeBin: String, CaseIterable, Hashable, Codable {
    case le5
    case gt5to10
    case gt10to15
    case gt15to20
    case gt20to25
    case gt25to30
    case gt30to40
    case gt40to50
    case gt50to60
    case gt60

    static let ordered: [SizeBin] = [
        .le5,
        .gt5to10,
        .gt10to15,
        .gt15to20,
        .gt20to25,
        .gt25to30,
        .gt30to40,
        .gt40to50,
        .gt50to60,
        .gt60
    ]

    var title: String {
        sizeRange.label
    }

    static func bin(forCM cm: Double) -> SizeBin {
        SizeBuckets.bucket(for: cm).sizeBin
    }
}
