import Foundation

enum FuzzyMatcher {
    static func normalize(_ string: String) -> String {
        let folded = string.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        let allowed = CharacterSet.alphanumerics.union(.whitespaces)
        let filteredScalars = folded.unicodeScalars.filter { allowed.contains($0) }
        let filtered = String(String.UnicodeScalarView(filteredScalars))
        return filtered.replacingOccurrences(of: "\\s+", with: "", options: .regularExpression)
    }

    static func similarity(between lhs: String, and rhs: String) -> Double {
        let left = normalize(lhs)
        let right = normalize(rhs)
        guard !left.isEmpty, !right.isEmpty else { return 0 }
        let distance = Double(levenshtein(left, right))
        let maxLength = Double(max(left.count, right.count))
        guard maxLength > 0 else { return 0 }
        return 1 - (distance / maxLength)
    }

    static func bestMatch(for query: String, in candidates: [String], threshold: Double = 0.65) -> String? {
        let scored = rankedMatches(for: query, in: candidates, limit: 1, threshold: threshold)
        return scored.first
    }

    static func rankedMatches(for query: String, in candidates: [String], limit: Int = 5, threshold: Double = 0.6) -> [String] {
        let uniqueCandidates = Array(Set(candidates))
        let scores: [(String, Double)] = uniqueCandidates.map { candidate in
            (candidate, similarity(between: query, and: candidate))
        }
        let filtered = scores
            .filter { $0.1 >= threshold }
            .sorted { lhs, rhs in
                if lhs.1 == rhs.1 {
                    return lhs.0 < rhs.0
                }
                return lhs.1 > rhs.1
            }
        return filtered.prefix(limit).map { $0.0 }
    }

    private static func levenshtein(_ lhs: String, _ rhs: String) -> Int {
        let lhsArray = Array(lhs)
        let rhsArray = Array(rhs)
        var distances = Array(0...rhsArray.count)

        for (i, leftChar) in lhsArray.enumerated() {
            var previous = i
            distances[0] = i + 1

            for (j, rightChar) in rhsArray.enumerated() {
                let cost = leftChar == rightChar ? 0 : 1
                let insertion = distances[j + 1] + 1
                let deletion = previous + 1
                let substitution = distances[j] + cost
                previous = distances[j + 1]
                distances[j + 1] = min(insertion, deletion, substitution)
            }
        }

        return distances[rhsArray.count]
    }
}
