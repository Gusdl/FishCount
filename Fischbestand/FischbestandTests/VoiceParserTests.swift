import XCTest
@testable import Fischbestand

final class VoiceParserTests: XCTestCase {
    private var parser: VoiceParser!

    override func setUpWithError() throws {
        parser = VoiceParser(
            speciesList: ["Barsch", "Hecht", "Rotauge"],
            speciesAliases: [
                "Hecht": ["Esox"],
                "Barsch": ["Flussbarsch"],
                "Rotauge": ["Plötze"]
            ]
        )
    }

    func testParsesStructuredCommandWithComment() throws {
        let command = parser.parse(text: "Barsch bis 15 cm, drei Stück, Kommentar: Jungfische am Schilf")
        guard case let .add(entry) = command else {
            return XCTFail("Expected add command, got \(command)")
        }

        XCTAssertEqual(entry.species, "Barsch")
        XCTAssertEqual(entry.sizeClass, "Bis 15 Cm")
        XCTAssertEqual(entry.count, 3)
        XCTAssertEqual(entry.comment, "Jungfische am Schilf")
    }

    func testResolvesAliasesAndFuzzyMatches() throws {
        let aliasCommand = parser.parse(text: "Esox bis 80 cm, 2 Stück")
        guard case let .add(aliasEntry) = aliasCommand else {
            return XCTFail("Expected add command, got \(aliasCommand)")
        }
        XCTAssertEqual(aliasEntry.species, "Hecht")

        let fuzzyCommand = parser.parse(text: "Plotze bis 20 cm 4")
        guard case let .add(fuzzyEntry) = fuzzyCommand else {
            return XCTFail("Expected add command, got \(fuzzyCommand)")
        }
        XCTAssertEqual(fuzzyEntry.species, "Rotauge")
        XCTAssertEqual(fuzzyEntry.count, 4)
    }

    func testRecognizesUndoCommand() {
        XCTAssertEqual(parser.parse(text: "Bitte rückgängig machen"), .undo)
        XCTAssertEqual(parser.parse(text: "letzte löschen"), .undo)
    }

    func testCanonicalSpeciesNormalization() {
        XCTAssertEqual(parser.canonicalSpecies(from: "flusSbarsch"), "Barsch")
        XCTAssertEqual(parser.canonicalSpecies(from: "Äsche"), "Äsche")
    }
}
