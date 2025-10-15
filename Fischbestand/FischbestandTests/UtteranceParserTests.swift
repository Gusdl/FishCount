import XCTest
@testable import Fischbestand

final class UtteranceParserTests: XCTestCase {
    override func setUp() {
        super.setUp()
        SpeciesCatalog.save(SpeciesCatalog.defaults)
    }

    func testUpperBoundBinning() {
        let result = entry(from: "Barsch bis 5 cm fünf Stück", fallbackBin: .gt10to15)
        XCTAssertEqual(result?.species, "Barsch")
        XCTAssertEqual(result?.sizeBin, .le5)
        XCTAssertEqual(result?.count, 5)
    }

    func testRangeBinning() {
        let result = entry(from: "Forelle 10 bis 15 Zentimeter 3 Stück", fallbackBin: .le5)
        XCTAssertEqual(result?.sizeBin, .gt10to15)
        XCTAssertEqual(result?.count, 3)
    }

    func testWordNumbersAndYOY() {
        let result = entry(from: "Zander bis 8 cm zehn Stück Jungfische", fallbackBin: .le5)
        XCTAssertEqual(result?.count, 10)
        XCTAssertTrue(result?.isYOY ?? false)
    }
}
