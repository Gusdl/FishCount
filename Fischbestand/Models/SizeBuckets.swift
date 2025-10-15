import Foundation

struct SizeRange: Identifiable, Hashable, Codable {
    let id: String
    let lower: Double?   // exklusive Untergrenze (nil = -∞)
    let upper: Double?   // inklusive Obergrenze (nil = +∞)
    let label: String    // Anzeige, z.B. "≤5", "5–10", "10–15", …, ">60"

    func contains(_ cm: Double) -> Bool {
        if let lo = lower, !(cm > lo) { return false }
        if let hi = upper, !(cm <= hi) { return false }
        return true
    }
}

enum SizeBuckets {
    static let `default`: [SizeRange] = [
        SizeRange(id: "le5",   lower: nil, upper: 5,  label: "≤5"),
        SizeRange(id: "5-10",  lower: 5,   upper: 10, label: "5–10"),
        SizeRange(id: "10-15", lower: 10,  upper: 15, label: "10–15"),
        SizeRange(id: "15-20", lower: 15,  upper: 20, label: "15–20"),
        SizeRange(id: "20-25", lower: 20,  upper: 25, label: "20–25"),
        SizeRange(id: "25-30", lower: 25,  upper: 30, label: "25–30"),
        SizeRange(id: "30-40", lower: 30,  upper: 40, label: "30–40"),
        SizeRange(id: "40-50", lower: 40,  upper: 50, label: "40–50"),
        SizeRange(id: "50-60", lower: 50,  upper: 60, label: "50–60"),
        SizeRange(id: "gt60",  lower: 60,  upper: nil,label: ">60")
    ]

    static func bucket(for cm: Double, in bins: [SizeRange] = SizeBuckets.default) -> SizeRange {
        for b in bins where b.contains(cm) { return b }
        return bins.first! // fallback
    }
}

extension SizeRange {
    var sizeBin: SizeBin {
        switch id {
        case "le5": return .le5
        case "5-10": return .gt5to10
        case "10-15": return .gt10to15
        case "15-20": return .gt15to20
        case "20-25": return .gt20to25
        case "25-30": return .gt25to30
        case "30-40": return .gt30to40
        case "40-50": return .gt40to50
        case "50-60": return .gt50to60
        case "gt60": return .gt60
        default: return .le5
        }
    }
}

extension SizeBin {
    var sizeRange: SizeRange {
        switch self {
        case .le5: return SizeBuckets.default[0]
        case .gt5to10: return SizeBuckets.default[1]
        case .gt10to15: return SizeBuckets.default[2]
        case .gt15to20: return SizeBuckets.default[3]
        case .gt20to25: return SizeBuckets.default[4]
        case .gt25to30: return SizeBuckets.default[5]
        case .gt30to40: return SizeBuckets.default[6]
        case .gt40to50: return SizeBuckets.default[7]
        case .gt50to60: return SizeBuckets.default[8]
        case .gt60: return SizeBuckets.default[9]
        }
    }

    init(range: SizeRange) {
        self = range.sizeBin
    }
}
