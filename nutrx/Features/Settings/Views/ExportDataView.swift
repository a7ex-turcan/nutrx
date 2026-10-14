import SwiftUI
import SwiftData
import UIKit

/// Settings → Export data (docs/pro/design/1-stacks-export: export, export-done): a document tile and title, what
/// the file holds, the period (All time / Last 30 days / Last 90 days) with its entry count, and Export CSV, which
/// makes the file on the device and opens the share sheet. Once shared, a green strip names the file and the button
/// reads Export again.
struct ExportDataView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var period: ExportService.Period = .allTime
    @State private var entries: [ExportService.Entry] = []
    @State private var shareFile: ShareFile?
    /// The file on disk while the share sheet is up; removed when it closes, however it closes.
    @State private var writtenFile: URL?
    /// Set when the share sheet finished with the file sent somewhere (not cancelled).
    @State private var exported: Exported?
    @State private var exportFailed = false
    @State private var headerScrolledAway = false

    private struct ShareFile: Identifiable {
        let url: URL
        let entryCount: Int
        var id: URL { url }
    }

    private struct Exported: Equatable {
        let entryCount: Int
        let fileName: String
    }

    var body: some View {
        let summary = ExportService.summary(of: entries)
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Period")
                        .font(.footnote.weight(.semibold))
                        .textCase(.uppercase)
                        .foregroundStyle(Theme.textSecondary)
                        .padding(.horizontal, 4)
                        .accessibilityAddTraits(.isHeader)
                    periodPicker
                    summaryLine(summary)
                        .padding(.horizontal, 4)
                }
                // At accessibility sizes the button scrolls with the content: pinned, it took over a third of the
                // screen.
                if dynamicTypeSize.isAccessibilitySize {
                    footer(summary)
                        .padding(.top, 8)
                }
            }
            .padding(.horizontal, Theme.Spacing.screenMargin)
            .padding(.top, 8)
            .padding(.bottom, Theme.Spacing.sectionTop)
        }
        .onScrollGeometryChange(for: Bool.self) { geometry in
            geometry.contentOffset.y + geometry.contentInsets.top > 56
        } action: { _, scrolledAway in
            headerScrolledAway = scrolledAway
        }
        .safeAreaInset(edge: .bottom) {
            if !dynamicTypeSize.isAccessibilitySize {
                footer(summary)
                    .padding(.horizontal, Theme.Spacing.screenMargin)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                    .background(Theme.surfaceGround)
            }
        }
        .background(Theme.surfaceGround)
        // The header carries the title; the bar only shows it once the header has scrolled away.
        .navigationTitle(headerScrolledAway ? "Export data" : "")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: period, initial: true) {
            entries = ExportService.entries(for: period, context: modelContext)
            exported = nil
        }
        .sheet(item: $shareFile, onDismiss: {
            // Sent, cancelled or swiped away: the file shouldn't outlive the sheet.
            if let writtenFile { ExportService.removeExport(at: writtenFile) }
            writtenFile = nil
        }) { file in
            ActivityView(items: [file.url]) { completed in
                if completed {
                    withAnimation(.unlessReduceMotion(reduceMotion, .easeInOut(duration: 0.25))) {
                        exported = Exported(entryCount: file.entryCount, fileName: file.url.lastPathComponent)
                    }
                }
                shareFile = nil
            }
            .presentationDetents([.medium, .large])
            .ignoresSafeArea()
        }
        .alert("Couldn't make the file", isPresented: $exportFailed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your \(UIDevice.current.model) may be low on storage. Try again in a moment.")
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 16) {
                Image(systemName: "doc.text")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(colorScheme == .dark ? Theme.green : Theme.forest)
                    .frame(width: 52, height: 52)
                    .background(Theme.green.opacity(0.15),
                                in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
                    .accessibilityHidden(true)
                Text("Export data")
                    .font(.largeTitle.bold())
                    .foregroundStyle(Theme.textPrimary)
                    .accessibilityAddTraits(.isHeader)
            }
            Text("A CSV file with one row per entry: date, time, nutrient, amount, unit and note. It opens in Numbers, Excel or Google Sheets.")
                .font(.body)
                .foregroundStyle(Theme.textSecondary)
        }
    }

    // MARK: - Period

    private var periodPicker: some View {
        VStack(spacing: 0) {
            ForEach(Array(ExportService.Period.allCases.enumerated()), id: \.element) { index, option in
                if index > 0 {
                    Rectangle().fill(Theme.lineHairline).frame(height: 1)
                        .padding(.leading, Theme.Spacing.cardPadding + 2)
                }
                Button {
                    period = option
                } label: {
                    HStack {
                        Text(option.title)
                            .foregroundStyle(Theme.textPrimary)
                        Spacer(minLength: 8)
                        if period == option {
                            Image(systemName: "checkmark")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Theme.controlPrimary)
                                .accessibilityHidden(true)  // the row's .isSelected says it; VoiceOver reads ✓ as "Selected"
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.cardPadding + 2)
                    .frame(minHeight: 52)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(period == option ? .isSelected : [])
            }
        }
        .cardStyle()
    }

    private func summaryLine(_ summary: ExportService.Summary) -> some View {
        let text = ExportService.summaryText(summary)
        // The entry count in bold, as in the design: "**1,284** entries · 6 nutrients · since 2 March 2026".
        let count = summary.entryCount.formatted()
        var attributed = AttributedString(text)
        if summary.entryCount > 0, let range = attributed.range(of: count) {
            attributed[range].font = .footnote.weight(.bold)
            attributed[range].foregroundColor = Theme.textPrimary
        }
        return Text(attributed)
            .font(.footnote)
            .foregroundStyle(Theme.textSecondary)
    }

    // MARK: - Footer

    private func footer(_ summary: ExportService.Summary) -> some View {
        VStack(spacing: 12) {
            if let exported {
                doneStrip(exported)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
            Button {
                export()
            } label: {
                Label(exported == nil ? "Export CSV" : "Export again", systemImage: "square.and.arrow.up")
                    .font(.headline)
                    .foregroundStyle(Theme.controlOnPrimary)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(Theme.controlPrimary,
                                in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
                    .opacity(summary.entryCount == 0 ? 0.4 : 1)
            }
            .buttonStyle(.plain)
            .disabled(summary.entryCount == 0)
            Text("The file is made on your \(UIDevice.current.model). nutrx never sees it.")
                .font(.footnote)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    private func doneStrip(_ exported: Exported) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checkmark")
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(Theme.forest)
                .frame(width: 28, height: 28)
                .background(Theme.green, in: Circle())
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)  // the glyph stays inside its 28pt circle
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(exported.entryCount == 1 ? "Exported 1 entry" : "Exported \(exported.entryCount.formatted()) entries")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textGreenInk)
                Text(exported.fileName)
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(Theme.Spacing.cardPadding)
        .background(Theme.green.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    // MARK: - Actions

    private func export() {
        // Fetched again so an entry logged since the screen opened (another device, Siri) is included.
        let current = ExportService.entries(for: period, context: modelContext)
        entries = current
        do {
            let url = try ExportService.writeExport(ExportService.csv(current), fileName: ExportService.fileName())
            writtenFile = url
            shareFile = ShareFile(url: url, entryCount: current.count)
        } catch {
            exportFailed = true
        }
    }
}

/// The system share sheet, for its completion callback (`ShareLink` has none, and the done state needs to know the
/// file was actually sent somewhere).
private struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]
    let onComplete: (_ completed: Bool) -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.completionWithItemsHandler = { _, completed, _, _ in
            onComplete(completed)
        }
        return controller
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

#Preview("Export data") {
    NavigationStack {
        ExportDataView()
    }
    .modelContainer(previewContainer)
}

#Preview("Dark") {
    NavigationStack {
        ExportDataView()
    }
    .modelContainer(previewContainer)
    .preferredColorScheme(.dark)
}
