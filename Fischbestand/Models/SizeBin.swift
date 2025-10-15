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
        switch self {
        case .le5: return "≤5"
        case .gt5to10: return ">5–10"
        case .gt10to15: return ">10–15"
        case .gt15to20: return ">15–20"
        case .gt20to25: return ">20–25"
        case .gt25to30: return ">25–30"
        case .gt30to40: return ">30–40"
        case .gt40to50: return ">40–50"
        case .gt50to60: return ">50–60"
        case .gt60: return ">60"
        }
    }

    static func bin(forCM cm: Double) -> SizeBin {
        switch cm {
        case ..<5: return .le5
        case 5..<10: return .gt5to10
        case 10..<15: return .gt10to15
        case 15..<20: return .gt15to20
        case 20..<25: return .gt20to25
        case 25..<30: return .gt25to30
        case 30..<40: return .gt30to40
        case 40..<50: return .gt40to50
        case 50..<60: return .gt50to60
        default: return .gt60
        }
    }
}
