import XCTest
@testable import nutrx

final class StackSheetLayoutTests: XCTestCase {
    func testNameLinesAreOnePerWord() {
        XCTAssertEqual(LogStackSheet.nameLineLimit("Magnesium"), 1)
        XCTAssertEqual(LogStackSheet.nameLineLimit("Vitamin D"), 2)
        XCTAssertEqual(LogStackSheet.nameLineLimit("Omega-3 Fish Oil"), 3)
        XCTAssertEqual(LogStackSheet.nameLineLimit(""), 1)
    }

    func testAWordTooLongToShrinkGetsAnExtraLine() {
        XCTAssertEqual(LogStackSheet.nameLineLimit("Phosphatidylserine"), 2)
        XCTAssertEqual(LogStackSheet.nameLineLimit("Liposomal Phosphatidylserine"), 3)
        XCTAssertEqual(LogStackSheet.nameLineLimit("Ashwagandha"), 1)
    }
}
