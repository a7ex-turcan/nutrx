import CoreGraphics
import Foundation
import Vision

/// On-device text recognition for a label photo or a frozen scanner frame (Vision; nothing is uploaded). Text on
/// the same row is joined left to right ("Vitamin D3 … 1,000 IU" can come back as two pieces), rows top to bottom,
/// so the parser and the model see the label the way it's printed.
enum LabelTextRecognizer {
    static func text(in image: CGImage, orientation: CGImagePropertyOrientation = .up) async throws -> String {
        var request = RecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        let observations = try await request.perform(on: image, orientation: orientation)
        let pieces = observations.compactMap { observation -> Piece? in
            guard let text = observation.topCandidates(1).first?.string else { return nil }
            let box = observation.boundingBox.cgRect
            return Piece(text: text, midY: box.midY, minX: box.minX, height: box.height)
        }
        return rows(pieces).joined(separator: "\n")
    }

    /// One recognised piece of text; Vision's coordinates (origin bottom left, 0…1).
    struct Piece: Equatable {
        let text: String
        let midY: CGFloat
        let minX: CGFloat
        let height: CGFloat
    }

    /// Pieces whose centres are within half a line of each other form a row; rows top to bottom, pieces left to right.
    static func rows(_ pieces: [Piece]) -> [String] {
        var rows: [[Piece]] = []
        for piece in pieces.sorted(by: { $0.midY > $1.midY }) {
            if let index = rows.firstIndex(where: { row in
                abs(row[0].midY - piece.midY) < max(row[0].height, piece.height) * 0.5
            }) {
                rows[index].append(piece)
            } else {
                rows.append([piece])
            }
        }
        return rows.map { row in row.sorted { $0.minX < $1.minX }.map(\.text).joined(separator: " ") }
    }
}
