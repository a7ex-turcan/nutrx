import XCTest
@testable import nutrx

/// The rule-based label reader against a corpus of label texts as on-device text recognition returns them (one
/// line per row, the odd OCR slip). Each case says what a person would type into the form.
final class LabelParserTests: XCTestCase {
    private func assertLabel(_ text: String, name: String?, unit: String?, amount: Double?, servings: Int?,
                             file: StaticString = #filePath, line: UInt = #line) {
        let label = LabelParser.parse(text)
        XCTAssertEqual(label.name, name, "name", file: file, line: line)
        XCTAssertEqual(label.unit, unit, "unit", file: file, line: line)
        XCTAssertEqual(label.amountPerServing, amount, "amount", file: file, line: line)
        XCTAssertEqual(label.servingsPerContainer, servings, "servings", file: file, line: line)
    }

    func testVitaminD3Softgels() {
        assertLabel("""
            VITAMIN D3
            Dietary supplement · 120 softgels
            Supplement Facts
            Serving size: 1 softgel
            Servings per container: 120
            Amount Per Serving %DV
            Vitamin D3 1,000 IU 125%
            (as cholecalciferol)
            """, name: "Vitamin D3", unit: "IU", amount: 1000, servings: 120)
    }

    func testVitaminDInMicrogramsAndIUPrefersIU() {
        assertLabel("""
            Nature's Best
            Vitamin D3
            High potency
            Supplement Facts
            Serving Size 1 Softgel
            Servings Per Container 180
            Vitamin D3 (as cholecalciferol) 125 mcg (5,000 IU) 625%
            """, name: "Vitamin D3", unit: "IU", amount: 5000, servings: 180)
    }

    func testMagnesiumCapsulesTwoPerServing() {
        assertLabel("""
            MAGNESIUM GLYCINATE
            120 Veggie Capsules
            Supplement Facts
            Serving Size: 2 Capsules
            Amount Per Serving
            Magnesium (as magnesium glycinate) 200 mg 48%
            """, name: "Magnesium Glycinate", unit: "mg", amount: 200, servings: 60)
    }

    func testFishOilPicksTheLabelledAmount() {
        assertLabel("""
            Omega-3 Fish Oil
            Supplement Facts
            Serving Size 2 Softgels
            Servings Per Container 60
            Calories 20
            Total Fat 2 g 3%
            Omega-3 Fatty Acids 1,280 mg
            EPA 650 mg
            DHA 450 mg
            """, name: "Omega-3", unit: "mg", amount: 1280, servings: 60)
    }

    func testCreatinePowderInGrams() {
        assertLabel("""
            CREATINE MONOHYDRATE
            Unflavored powder
            Supplement Facts
            Serving Size 1 Scoop (5 g)
            Servings Per Container About 100
            Creatine Monohydrate 5 g
            """, name: "Creatine Monohydrate", unit: "g", amount: 5, servings: 100)
    }

    func testZincTablets() {
        assertLabel("""
            Zinc
            50 mg
            100 Tablets
            Supplement Facts
            Serving Size 1 Tablet
            Zinc (as zinc gluconate) 50 mg 455%
            """, name: "Zinc", unit: "mg", amount: 50, servings: 100)
    }

    func testVitaminB12Micrograms() {
        assertLabel("""
            Vitamin B12
            Methylcobalamin
            Supplement Facts
            Serving Size 1 Lozenge
            Servings Per Container 60
            Vitamin B12 (as methylcobalamin) 1000 µg 41667%
            """, name: "Vitamin B12", unit: "mcg", amount: 1000, servings: 60)
    }

    func testMelatoninDecimalAmount() {
        assertLabel("""
            Melatonin
            Supplement Facts
            Serving Size 1 Gummy
            Servings Per Container 60
            Melatonin 2.5 mg †
            """, name: "Melatonin", unit: "mg", amount: 2.5, servings: 60)
    }

    func testAnUnknownProductUsesTheFirstTitleLine() {
        assertLabel("""
            Sleep Blend
            Dietary Supplement
            30 capsules
            Supplement Facts
            Serving Size 1 Capsule
            Proprietary blend 450 mg
            """, name: "Sleep Blend", unit: "mg", amount: 450, servings: 30)
    }

    func testPartialLabelLeavesUnreadFieldsEmpty() {
        // The facts panel was cut off: no bottle size.
        let label = LabelParser.parse("""
            VITAMIN C
            Supplement Facts
            Vitamin C (as ascorbic acid) 500 mg
            """)
        XCTAssertEqual(label.name, "Vitamin C")
        XCTAssertEqual(label.amountPerServing, 500)
        XCTAssertNil(label.servingsPerContainer)
    }

    func testNothingReadable() {
        XCTAssertTrue(LabelParser.parse("Store in a cool dry place.\nKeep out of reach of children.").isEmpty)
    }

    func testNumbersAndUnits() {
        XCTAssertEqual(LabelParser.number("1,000"), 1000)
        XCTAssertEqual(LabelParser.number("1 000"), 1000)
        XCTAssertEqual(LabelParser.number("2.5"), 2.5)
        XCTAssertEqual(LabelParser.number("2,5"), 2.5, "a decimal comma")
        XCTAssertEqual(LabelParser.normalisedUnit("µg"), "mcg")
        XCTAssertEqual(LabelParser.normalisedUnit("iu"), "IU")
        XCTAssertEqual(LabelParser.titleCased("VITAMIN D3"), "Vitamin D3")
        XCTAssertEqual(LabelParser.titleCased("coq10"), "CoQ10")
    }
}
