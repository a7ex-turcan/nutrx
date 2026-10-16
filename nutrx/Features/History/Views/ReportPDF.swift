import SwiftUI

/// Draws the report for your doctor into a PDF, one `ReportPageView` per `ReportLayout` page through `ImageRenderer`,
/// so text and bars stay vector (searchable, sharp when printed). Made on the device; the file lives only as long as
/// the share sheet that sends it.
enum ReportPDF {
    struct RenderError: Error {}

    static func data(report: DoctorReport, layout: ReportLayout, generatedOn: Date = .now) throws -> Data {
        let data = NSMutableData()
        var mediaBox = CGRect(origin: .zero, size: layout.paper.size)
        let info = [kCGPDFContextTitle: ReportText.title, kCGPDFContextCreator: "nutrx"] as CFDictionary
        guard let consumer = CGDataConsumer(data: data),
              let pdf = CGContext(consumer: consumer, mediaBox: &mediaBox, info) else { throw RenderError() }
        for index in layout.pages.indices {
            let renderer = ImageRenderer(content: ReportPageView(report: report, layout: layout, index: index,
                                                                 generatedOn: generatedOn))
            renderer.proposedSize = ProposedViewSize(layout.paper.size)
            renderer.render { _, draw in
                pdf.beginPDFPage(nil)
                draw(pdf)
                pdf.endPDFPage()
            }
        }
        pdf.closePDF()
        return data as Data
    }

    /// Where reports are written: `tmp/nutrx-report/<uuid>/<file name>`.
    static var reportsFolder: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("nutrx-report", isDirectory: true)
    }

    /// Writes the PDF to a fresh folder for the share sheet; the caller removes it when the sheet closes (`remove`).
    /// Each report first clears what an earlier one left behind (the app was killed with the share sheet up).
    static func write(report: DoctorReport, layout: ReportLayout, generatedOn: Date = .now) throws -> URL {
        try? FileManager.default.removeItem(at: reportsFolder)
        let folder = reportsFolder.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent(ReportText(report: report).fileName)
        // A failed render throws (the sheet's "Couldn't make the PDF"), never shares an empty file.
        try data(report: report, layout: layout, generatedOn: generatedOn).write(to: url, options: .atomic)
        return url
    }

    static func remove(at url: URL) {
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }
}
