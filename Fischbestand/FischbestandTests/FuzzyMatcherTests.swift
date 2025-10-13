import XCTest
@testable import Fischbestand

final class FuzzyMatcherTests: XCTestCase {
    func testNormalizeRemovesDiacriticsAndSpaces() {
        XCTAssertEqual(FuzzyMatcher.normalize("  Äs ché " ), "asche")
        XCTAssertEqual(FuzzyMatcher.normalize("Barsch"), "barsch")
    }

    func testSimilarityRanksCloserStringsHigher() {
        let close = FuzzyMatcher.similarity(between: "Plotze", and: "Plötze")
        let far = FuzzyMatcher.similarity(between: "Plotze", and: "Hecht")
        XCTAssertGreaterThan(close, far)
    }

    func testBestMatchRespectsThresholdAndOrder() {
        let candidates = ["Barsch", "Hecht", "Rotauge"]
        XCTAssertEqual(FuzzyMatcher.bestMatch(for: "Rottauge", in: candidates), "Rotauge")
        XCTAssertNil(FuzzyMatcher.bestMatch(for: "Unbekannt", in: candidates, threshold: 0.9))
    }

    func testRankedMatchesReturnsSortedList() {
        let ranked = FuzzyMatcher.rankedMatches(for: "hect", in: ["Barsch", "Hecht"], limit: 2)
        XCTAssertEqual(ranked.first, "Hecht")
        XCTAssertEqual(ranked.count, 1)
    }
}
