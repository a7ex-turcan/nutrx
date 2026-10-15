import CoreGraphics
import ImageIO
import UIKit

/// From a photo of a label to what the form fills in (nutrx Pro, docs/pro/PLAN.md phase 5): text recognition, then
/// the on-device model or the parser. All on the device.
enum LabelScan {
    /// What was read, or nil when the photo gave nothing usable ("Couldn't read this label").
    static func read(_ image: CGImage, orientation: CGImagePropertyOrientation) async -> SupplementLabel? {
        guard let text = try? await LabelTextRecognizer.text(in: image, orientation: orientation),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        let label = await LabelExtractor.extract(from: text).label
        return label.isEmpty ? nil : label
    }

    /// A UIKit image's orientation as Vision takes it (a camera photo is usually stored sideways, `.right`).
    static func orientation(of image: UIImage) -> CGImagePropertyOrientation {
        switch image.imageOrientation {
        case .up: .up
        case .down: .down
        case .left: .left
        case .right: .right
        case .upMirrored: .upMirrored
        case .downMirrored: .downMirrored
        case .leftMirrored: .leftMirrored
        case .rightMirrored: .rightMirrored
        @unknown default: .up
        }
    }
}

/// Scan copy (docs/pro/design/4-scan-label, 2-paywall no-apple-intelligence), pure for `LabelScanTests`.
enum ScanText {
    /// How this device reads labels, for the notes at the entry point and on the paywall.
    enum Reading: Equatable {
        /// Apple Intelligence: the on-device model.
        case model
        /// The parser alone, because the device can't run the model.
        case basic
        /// The parser alone, because Apple Intelligence is turned off.
        case modelTurnedOff

        static var current: Reading {
            if LabelExtractor.isModelAvailable { return .model }
            return LabelExtractor.isModelTurnedOff ? .modelTurnedOff : .basic
        }
    }

    /// Under the entry card, or nil when nothing needs saying.
    static func entryNote(_ reading: Reading, device: String) -> String? {
        switch reading {
        case .model: nil
        case .basic: "This \(device) reads labels with basic text matching, so you may fill in a little more yourself."
        case .modelTurnedOff: "Turn on Apple Intelligence in Settings to read more from labels."
        }
    }

    /// Under the paywall's Scan a label row.
    static func paywallNote(_ reading: Reading, device: String) -> String? {
        reading == .model ? nil : "Basic text reading on this \(device)"
    }

    static let pointAtFacts = "Point at the Supplement Facts"
    static let reading = "Reading the label…"
    static let failTitle = "Couldn't read this label"
    static let failBody = "Try brighter light, hold the bottle steady, and fill the frame with the Supplement Facts panel."
    static let goalHint = "Set the amount you're aiming for. nutrx doesn't suggest one."

    static func privacy(device: String) -> String {
        "Read on your \(device). Nothing is uploaded."
    }
}
