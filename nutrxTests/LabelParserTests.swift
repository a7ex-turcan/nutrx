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

    func testCodesInTheNameNeverJoinTheAmount() {
        assertLabel("""
            Vitamin B12
            Supplement Facts
            Servings Per Container 90
            Vitamin B12 500 mcg
            """, name: "Vitamin B12", unit: "mcg", amount: 500, servings: 90)
        assertLabel("""
            VITAMIN D3
            Supplement Facts
            Servings per container: 60
            Vitamin D3 400 IU
            """, name: "Vitamin D3", unit: "IU", amount: 400, servings: 60)
        assertLabel("""
            CoQ10
            Supplement Facts
            Servings Per Container 30
            CoQ10 100 mg
            """, name: "CoQ10", unit: "mg", amount: 100, servings: 30)
    }

    func testAHyphenatedCodeNeverJoinsTheAmount() {
        assertLabel("""
            Omega-3
            Supplement Facts
            Servings Per Container 60
            Total Omega-3 600 mg
            """, name: "Omega-3", unit: "mg", amount: 600, servings: 60)
        assertLabel("""
            Vitamin K2
            Supplement Facts
            Servings Per Container 60
            Vitamin K2 (as MK-7) 100 mcg
            """, name: "Vitamin K2", unit: "mcg", amount: 100, servings: 60)
        XCTAssertEqual(LabelParser.amounts(in: "Vitamin D-3 400 IU").map(\.0), [400])
    }

    func testABrandAloneAboveTheFactsLeavesTheNameToTheFacts() {
        assertLabel("""
            Acme Labs®
            Supplement Facts
            Servings Per Container 90
            Vitamin D3 25 mcg
            """, name: "Vitamin D3", unit: "mcg", amount: 25, servings: 90)
    }

    func testABrandLikeLineOnItsOwnIsTheName() {
        assertLabel("""
            Women's Multi
            Supplement Facts
            Servings Per Container 30
            Calcium 200 mg
            """, name: "Women's Multi", unit: "mg", amount: 200, servings: 30)
    }

    func testTheNamedIngredientsAmountBeatsOneListedFirst() {
        // Magnesium Glycinate with Vitamin B6 first, and the glycinate form on its own line without an amount.
        assertLabel("""
            MAGNESIUM GLYCINATE
            High absorption
            Supplement Facts
            Serving Size 2 Capsules
            Servings Per Container 60
            Amount Per Serving %DV
            Vitamin B6 (as pyridoxine HCl) 2.5 mg 147%
            Magnesium 200 mg 48%
            (as magnesium glycinate)
            """, name: "Magnesium Glycinate", unit: "mg", amount: 200, servings: 60)
    }

    func testAVitaminDoesntTakeAnotherVitaminsAmount() {
        // "Vitamin D3" mustn't fall back to any line starting with "vitamin", or the model's answer would be
        // replaced with Vitamin K2's.
        XCTAssertNil(LabelParser.namedAmount(in: ["Vitamin K2 (as MK-7) 100 mcg"], name: "Vitamin D3"))
        XCTAssertEqual(LabelParser.namedAmount(in: ["Vitamin K2 100 mcg", "Vitamin D3 1,000 IU"], name: "Vitamin D3")?.0, 1000)
    }

    func testAnIngredientInTheFactsDoesntNameABlend() {
        assertLabel("""
            Sleep Blend
            Supplement Facts
            Servings Per Container 30
            Melatonin 3 mg
            Proprietary blend 450 mg
            """, name: "Sleep Blend", unit: "mg", amount: 3, servings: 30)
    }

    func testABrandLineAboveAnUnknownProductIsSkipped() {
        assertLabel("""
            Nature's Best
            Calm Night
            60 capsules
            Supplement Facts
            Serving Size 1 Capsule
            Proprietary blend 450 mg
            """, name: "Calm Night", unit: "mg", amount: 450, servings: 60)
    }


    // MARK: - Real photos (back panels only), as on-device text recognition read them

    func testRealPhotoNordicOmega3() {
        assertLabel("""
            Supplement Facts
            Serving Size: 2 Soft Gels
            Servings Per Container: 60
            Amount Per Serving % Daily Value**1
            Calories 20
            Total Fat 2 g 3%
            Total Omega-3s® 1280 mg
            EPA (Eicosapentaenoic Acid) 650 mg
            DHA (Docosahexaenoic Acid) 450 mg
            **Percent Daily Values are based on a 2,000 calorie diet.
            1 Daily Value (DV) for adults.
            + Daily Value not established.
            o Includes EPA, DHA, and Other Omega-3s in triglyceride form (rIG).
            Res Less than 5 mg of Cholesterol per serving (<1% Daily Value).
            Ingredients: purified deep sea fish oil (from anchovies, sardines,
            mackerel, and herring), soft gel capsule gelatin, glycerin, water,
            natural flavor), natural flavor, RRR-alpha tocopherol (antioxidant).
            rosemary extract a natural preservative).
            No gluten, milk derivatives, or synthetic dyes.
            Fish oil processed in Norway I Manufactured in the U.S. by: Nordic Naturals Mfg, Inc.
            111 Jennings Drive, Watsonville, CA 95076 | 800.662.2544 | nordic.com
            Learn more at
            nordic.com
            EXP 05/28 LOT 252083
            """, name: "Omega-3", unit: "mg", amount: 1280, servings: 60)
    }

    func testRealPhotoPollockOmega3OverFishOil() {
        assertLabel("""
            Supplement Facts
            Servings Per Container: 90 Serving Size: 1 Softgel
            Amount Per Serving DV
            Calories 15
            Total Fat 1.5 g 26"
            Wild Alaska Pollock Fish Oil Concentrate 1250 mg
            Total Omega-3 Fatty Acids (TG as rTG) 1040 mg
            EPA (Eicosapentaenoic Acid) 690 mg
            DHA (Docosahexaenoic Acid) 260 mg
            * Percent Daily Values are based on a 2,000 calorie det.
            * Daily Value (DV) not established.
            [tilapia-sourced], vegetable glycerin, purified water. OTHER INGREDIENTS: Softgel capsule (fish gelatin
            tocopherols.
            CONTAINS: Fish (Alaska pollock).
            """, name: "Omega-3", unit: "mg", amount: 1040, servings: 90)
    }

    func testRealPhotoCollagenNotProtein() {
        assertLabel("""
            Suggested Use: Take 3 tablets twice daily, on an empty stomach at least 1 hour before or 2 hours after meals. Best
            Avoid taking with other foods containing protein as they may when taken as directed by a qualified healthcare professional.
            interfere with collagen absorption.
            Serving Size 3 Tablets Supplement Facts
            Servings Per Container About 83
            Amount %Daily
            Per Serving license
            Value
            heatron
            Calories 15
            Protein <1%*
            3 g
            Vitamin C (as Calcium Ascorbate) 30 mg 33%
            Sodium 10 mg <1%
            Hydrolyzed Bovine Collagen Peptides 3 g
            + Daily Value not established. *Percent Daily Values are based on a 2,000 calorie diet.
            Magnesium Stearate. Other Ingredients: Stearic Acid, Silicon Dioxide (Silic), and
            Not manufactured with milk, eggs, fish, crustacean shellfish, tree nuts, peanuts, wheat, soy, sesame, or gluten. Produced in
            facility that may process other products that contain thes an FDA-registered, third-party audited, and cGMP-compliant
            allergens or ingredients.
            Gudrantee, It you are not completely satiefied with vour purchase Guarantee If vou are not comnletely cotisfiod With vour burches. All California Gold Nutrition® products come with a 100% GOLD
            return the unused portion within on days for a full refund.
            """, name: "Collagen", unit: "g", amount: 3, servings: 83)
    }

    func testRealPhotoMagnesiumOverVitaminB6() {
        assertLabel("""
            SupplementFacts
            Serving Size 1 Vegan Tablet
            Amount Per Serving % Daily Value
            Vitamin B6 2.5 mg 147%
            (as pyridoxal 5-phosphate)
            Magnesium 200 mg 48%
            (from Albion® magnesium bisglycinate
            chelate buffered)
            Benfotiamine 18 mg
            Other ingredients: Citric acid, hydroxy- *Daily Value not established.
            propyl methylcellulose, microcrystalline cellulose (plant fiber), stearic acid, silica.
            aqueous film coating (puritied water. maltodextrin, guar gum, xanthan gum,
            table glenn callin hydroxypropyl methylcellulose, veg salmitate.
            """, name: "Magnesium", unit: "mg", amount: 200, servings: nil)
    }

    func testAProteinPowdersBackPanelIsProtein() {
        assertLabel("""
            Supplement Facts
            Servings Per Container 30
            Calories 120
            Total Fat 2 g
            Protein 25 g
            Sodium 50 mg
            """, name: "Protein", unit: "g", amount: 25, servings: 30)
    }

    func testALongFrontPanelLineStillNamesTheProduct() {
        assertLabel("""
            Extra Strength Vitamin D3 1000 IU Softgels
            Supplement Facts
            Servings Per Container 120
            Vitamin K2 (as MK-7) 100 mcg
            Vitamin D3 25 mcg (1,000 IU)
            """, name: "Vitamin D3", unit: "IU", amount: 1000, servings: 120)
    }

    func testBComplexDoesntTakeVitaminB6sAmount() {
        XCTAssertNil(LabelParser.namedAmount(in: ["Vitamin B6 2.5 mg"], name: "Vitamin B Complex"))
    }

    func testAFactsPanelsIngredientsAreListedWithoutNutritionRows() {
        let label = LabelParser.parse("""
            Suggested Use: Take 3 tablets twice daily, on an empty stomach at least 1 hour before or 2 hours after meals. Best
            Avoid taking with other foods containing protein as they may when taken as directed by a qualified healthcare professional.
            interfere with collagen absorption.
            Serving Size 3 Tablets Supplement Facts
            Servings Per Container About 83
            Amount %Daily
            Per Serving license
            Value
            heatron
            Calories 15
            Protein <1%*
            3 g
            Vitamin C (as Calcium Ascorbate) 30 mg 33%
            Sodium 10 mg <1%
            Hydrolyzed Bovine Collagen Peptides 3 g
            + Daily Value not established. *Percent Daily Values are based on a 2,000 calorie diet.
            Magnesium Stearate. Other Ingredients: Stearic Acid, Silicon Dioxide (Silic), and
            Not manufactured with milk, eggs, fish, crustacean shellfish, tree nuts, peanuts, wheat, soy, sesame, or gluten. Produced in
            facility that may process other products that contain thes an FDA-registered, third-party audited, and cGMP-compliant
            allergens or ingredients.
            Gudrantee, It you are not completely satiefied with vour purchase Guarantee If vou are not comnletely cotisfiod With vour burches. All California Gold Nutrition® products come with a 100% GOLD
            return the unused portion within on days for a full refund.
            """)
        XCTAssertEqual(label.ingredients.map(\.name), ["Vitamin C", "Collagen"], "Protein and Sodium are nutrition rows")
        let magnesium = LabelParser.parse("""
            SupplementFacts
            Serving Size 1 Vegan Tablet
            Amount Per Serving % Daily Value
            Vitamin B6 2.5 mg 147%
            (as pyridoxal 5-phosphate)
            Magnesium 200 mg 48%
            (from Albion® magnesium bisglycinate
            chelate buffered)
            Benfotiamine 18 mg
            Other ingredients: Citric acid, hydroxy- *Daily Value not established.
            propyl methylcellulose, microcrystalline cellulose (plant fiber), stearic acid, silica.
            aqueous film coating (puritied water. maltodextrin, guar gum, xanthan gum,
            table glenn callin hydroxypropyl methylcellulose, veg salmitate.
            """)
        XCTAssertEqual(magnesium.ingredients, [LabelIngredient(name: "Vitamin B6", amount: 2.5, unit: "mg"),
                                               LabelIngredient(name: "Magnesium", amount: 200, unit: "mg"),
                                               LabelIngredient(name: "Benfotiamine", amount: 18, unit: "mg")])
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
