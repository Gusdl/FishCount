import XCTest
@testable import Fischbestand

final class UtteranceParserTests: XCTestCase {
    let species = ["Barsch", "Hecht", "Karpfen", "Zander", "Forelle"]

    func testBis5() {
        let p = UtteranceParser.parse("Barsch bis 5 cm fünf Stück", speciesCatalog: species)!
        XCTAssertEqual(p.species, "Barsch"); XCTAssertEqual(p.sizeLabel, "bis 5 cm"); XCTAssertEqual(p.count, 5)
    }
    func testRange() {
        let p = UtteranceParser.parse("Forelle 10 bis 15 Zentimeter 3 Stück", speciesCatalog: species)!
        XCTAssertEqual(p.sizeLabel, "10–15 cm"); XCTAssertEqual(p.count, 3)
    }
    func testWords() {
        let p = UtteranceParser.parse("Zander bis 8 cm zehn Stück Jungfische", speciesCatalog: species)!
        XCTAssertEqual(p.count, 10); XCTAssertEqual(p.note, "Jungfische")
    }
}
