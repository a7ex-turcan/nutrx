import SwiftData
import UIKit
import XCTest
@testable import nutrx

/// Scan a label: the model's output checked against the text and merged with the parser, the form prefill, and
/// on-device text recognition on a rendered label.
@MainActor
final class LabelScanTests: XCTestCase {
    private let vitaminD = """
        VITAMIN D3
        Dietary supplement · 120 softgels
        Supplement Facts
        Serving size: 1 softgel
        Servings per container: 120
        Vitamin D3 1,000 IU 125%
        """

    private struct StubModel: LabelExtractor.Model {
        var label: SupplementLabel?
        func read(_ text: String) async throws -> SupplementLabel {
            guard let label else { throw CancellationError() }
            return label
        }
    }

    // MARK: - Extractor

    func testTheModelsFieldsAreUsedWhenTheLabelBacksThemUp() async {
        let model = StubModel(label: .init(name: "vitamin d3", unit: "iu", amountPerServing: 1000,
                                           servingsPerContainer: 120, servingForm: "softgels"))
        let result = await LabelExtractor.extract(from: vitaminD, model: model)
        XCTAssertTrue(result.usedModel)
        XCTAssertEqual(result.label, .init(name: "Vitamin D3", unit: "IU", amountPerServing: 1000,
                                           servingsPerContainer: 120, servingForm: "softgels"))
    }

    func testANumberThatIsntOnTheLabelIsDroppedAndTheParserFillsIn() async {
        // The model "read" 2,000 IU and 90 servings: neither is on the label.
        let model = StubModel(label: .init(name: "Vitamin D3", unit: "IU", amountPerServing: 2000, servingsPerContainer: 90))
        let result = await LabelExtractor.extract(from: vitaminD, model: model)
        XCTAssertEqual(result.label.amountPerServing, 1000, "from the parser")
        XCTAssertEqual(result.label.servingsPerContainer, 120, "from the parser")
    }

    func testGapsAreFilledFromTheParserAndBadUnitsDropped() async {
        let model = StubModel(label: .init(name: nil, unit: "softgel", amountPerServing: nil, servingsPerContainer: 120))
        let result = await LabelExtractor.extract(from: vitaminD, model: model)
        XCTAssertEqual(result.label.name, "Vitamin D3")
        XCTAssertEqual(result.label.unit, "IU")
        XCTAssertEqual(result.label.amountPerServing, 1000)
    }

    func testAModelErrorFallsBackToTheParser() async {
        let result = await LabelExtractor.extract(from: vitaminD, model: StubModel(label: nil))
        XCTAssertFalse(result.usedModel)
        XCTAssertEqual(result.label.name, "Vitamin D3")
        XCTAssertEqual(result.label.servingsPerContainer, 120)
    }

    func testWithoutAModelTheParserReadsIt() async {
        let result = await LabelExtractor.extract(from: vitaminD, model: nil)
        XCTAssertFalse(result.usedModel)
        XCTAssertEqual(result.label.amountPerServing, 1000)
    }

    func testNumbersOnTheLabel() {
        // The 3 of "D3" is a code, not a number; "120" on the next line stays 120, never 3,120.
        XCTAssertEqual(LabelExtractor.numbersOnLabel("Vitamin D3 1,000 IU 125% · 2.5 mg"), [1000, 125, 2.5])
        XCTAssertEqual(LabelExtractor.numbersOnLabel("VITAMIN D3\n120 softgels\nD3 400 IU"), [120, 400])
    }

    func testAUnitThatIsntWrittenAfterTheAmountIsDropped() async {
        // The label says 1,000 IU; the model answered mg.
        let model = StubModel(label: .init(name: "Vitamin D3", unit: "mg", amountPerServing: 1000, servingsPerContainer: 120))
        let result = await LabelExtractor.extract(from: vitaminD, model: model)
        XCTAssertEqual(result.label.unit, "IU", "the parser's unit, from the label")
        XCTAssertEqual(result.label.amountPerServing, 1000)
    }

    /// The real on-device model, when this machine has Apple Intelligence (skipped otherwise).
    func testTheOnDeviceModelReadsALabel() async throws {
        guard LabelExtractor.isModelAvailable else { throw XCTSkip("Apple Intelligence isn't available here") }
        // The simulator can report the model available yet fail to load it (ModelManagerError 1026); that falls
        // back to the parser, which is the behaviour to keep, but it isn't the model being tested.
        guard (try? await FoundationLabelModel().read(vitaminD)) != nil else {
            throw XCTSkip("The on-device model is listed but couldn't run here")
        }
        let result = await LabelExtractor.extract(from: vitaminD)
        XCTAssertTrue(result.usedModel)
        XCTAssertEqual(result.label.amountPerServing, 1000)
        XCTAssertEqual(result.label.servingsPerContainer, 120)
        XCTAssertEqual(result.label.unit, "IU")
    }

    // MARK: - Prefill

    func testPrefillFillsTheFormButNeverTheGoal() {
        let draft = NutrientDraft()
        draft.dailyTarget = "4000"
        LabelPrefill.apply(.init(name: "Vitamin D3", unit: "IU", amountPerServing: 1000, servingsPerContainer: 120,
                                 servingForm: "softgels"), to: draft)
        XCTAssertEqual(draft.name, "Vitamin D3")
        XCTAssertEqual(draft.unit, "IU")
        XCTAssertEqual(draft.step, "1000")
        XCTAssertEqual(draft.supplyServings, "120")
        XCTAssertEqual(draft.dailyTarget, "", "nutrx doesn't suggest a goal")
        XCTAssertEqual(draft.symbolName, "sun.max", "a known supplement's symbol")
        XCTAssertEqual(draft.scannedFields, [.name, .unit, .step, .supply])
        XCTAssertTrue(draft.unreadFields.isEmpty)
        XCTAssertFalse(draft.isValid, "Add stays off until there's a goal")
    }

    func testUnreadFieldsAreListed() {
        let draft = NutrientDraft()
        LabelPrefill.apply(.init(name: "Vitamin C", unit: "mg", amountPerServing: 500), to: draft)
        XCTAssertEqual(draft.unreadFields, [.supply])
        XCTAssertEqual(LabelPrefill.bannerText(unread: 1), "Filled from the label. One field needs you.")
        XCTAssertEqual(LabelPrefill.bannerText(unread: 0), "Filled from the label. Check it before adding.")
    }

    func testAddingAScannedNutrientStartsItsSupply() throws {
        let container = try ModelContainer.inMemoryForTests()
        let draft = NutrientDraft()
        LabelPrefill.apply(.init(name: "Vitamin D3", unit: "IU", amountPerServing: 1000, servingsPerContainer: 120), to: draft)
        draft.dailyTarget = "4000"
        let nutrient = try XCTUnwrap(draft.insertNutrient(into: container.mainContext, group: nil, sortOrder: 0))
        XCTAssertEqual(nutrient.step, 1000)
        XCTAssertEqual(nutrient.supplyServings, 120)
        XCTAssertNotNil(nutrient.supplyRefilledAt)
    }

    // MARK: - Text recognition

    func testRowsJoinPiecesOnTheSameLine() {
        let pieces = [
            LabelTextRecognizer.Piece(text: "1,000 IU", midY: 0.50, minX: 0.7, height: 0.04),
            LabelTextRecognizer.Piece(text: "Vitamin D3", midY: 0.51, minX: 0.1, height: 0.04),
            LabelTextRecognizer.Piece(text: "Supplement Facts", midY: 0.70, minX: 0.1, height: 0.05),
        ]
        XCTAssertEqual(LabelTextRecognizer.rows(pieces), ["Supplement Facts", "Vitamin D3 1,000 IU"])
    }

    func testRecognisesARenderedLabel() async throws {
        let lines = ["VITAMIN D3", "120 softgels", "Supplement Facts", "Serving size: 1 softgel",
                     "Servings per container: 120", "Vitamin D3        1,000 IU"]
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 900, height: 700))
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 900, height: 700))
            for (index, line) in lines.enumerated() {
                (line as NSString).draw(at: CGPoint(x: 60, y: 60 + index * 100),
                                        withAttributes: [.font: UIFont.systemFont(ofSize: 48, weight: .semibold),
                                                         .foregroundColor: UIColor.black])
            }
        }
        let text = try await LabelTextRecognizer.text(in: XCTUnwrap(image.cgImage))
        let label = LabelParser.parse(text)
        XCTAssertEqual(label.name, "Vitamin D3", text)
        XCTAssertEqual(label.amountPerServing, 1000, text)
        XCTAssertEqual(label.unit, "IU", text)
        XCTAssertEqual(label.servingsPerContainer, 120, text)
    }
}
