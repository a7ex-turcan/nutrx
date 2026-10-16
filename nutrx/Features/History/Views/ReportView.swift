import SwiftUI
import SwiftData
import UIKit

/// Report for your doctor (nutrx Pro, docs/pro/design/7-doctor-report: create): a thumbnail of the cover with the
/// page count and Preview, the period (30 days / 90 days / Custom), which nutrients, and whether the name, notes and
/// Apple Health trends go in. Create PDF makes the file on the device and opens the share sheet; the file is removed
/// when the sheet closes. Presented from History (with Cancel) and pushed from Settings.
struct ReportView: View {
    var showsCancel = false

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var viewModel = ReportViewModel()
    @State private var shareFile: ShareFile?
    /// The file on disk while the share sheet is up; removed when it closes, however it closes.
    @State private var writtenFile: URL?
    @State private var createFailed = false
    @State private var showPreview = false

    private struct ShareFile: Identifiable {
        let url: URL
        var id: URL { url }
    }

    private var healthAvailable: Bool { HealthReader.isAvailable && HealthReader.isConnected }

    var body: some View {
        List {
            Section {
                Picker("Period", selection: $viewModel.period) {
                    ForEach(ReportViewModel.Period.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            } header: {
                // In the section header rather than a row of its own: a list row clips to its rounded card shape,
                // which cut into the thumbnail's corners.
                VStack(alignment: .leading, spacing: 24) {
                    header
                        .textCase(nil)
                    Text("Period")
                }
                .padding(.top, 8)
            } footer: {
                if viewModel.period != .custom { periodFooter.padding(.top, 8) }
            }
            if viewModel.period == .custom {
                // Its own card: in the picker's section its top edge sat against the segmented control.
                Section {
                    DatePicker("From", selection: $viewModel.customStart,
                               in: viewModel.earliestDay...viewModel.customEnd, displayedComponents: .date)
                    DatePicker("To", selection: $viewModel.customEnd,
                               in: viewModel.earliestDay...viewModel.latestDay, displayedComponents: .date)
                } footer: {
                    if !viewModel.canCreate { periodFooter }
                }
                .listRowBackground(Theme.surfaceCard)
            }

            Section {
                NavigationLink {
                    ReportNutrientsView(viewModel: viewModel)
                } label: {
                    LabeledContent("Nutrients", value: viewModel.nutrientsValue)
                }
                .disabled(viewModel.candidates.isEmpty)
                if viewModel.personName != nil {
                    Toggle("Include my name", isOn: $viewModel.includesName)
                }
                Toggle("Include notes", isOn: $viewModel.includesNotes)
                if healthAvailable {
                    Toggle("Include Apple Health trends", isOn: $viewModel.includesHealth)
                }
            }
            .listRowBackground(Theme.surfaceCard)
            .tint(Theme.green)

            if dynamicTypeSize.isAccessibilitySize {
                Section {
                    createButton
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.surfaceGround)
        .safeAreaInset(edge: .bottom) {
            if !dynamicTypeSize.isAccessibilitySize {
                createButton
                    .padding(.horizontal, Theme.Spacing.screenMargin)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                    .background(Theme.surfaceGround)
            }
        }
        .navigationTitle("Report for your doctor")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if showsCancel {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .navigationDestination(isPresented: $showPreview) {
            if let report = viewModel.report, let layout = viewModel.layout {
                ReportPreviewView(report: report, layout: layout)
            }
        }
        .onAppear {
            if viewModel.report == nil { viewModel.load(context: modelContext) }
        }
        .task(id: viewModel.includesHealth) {
            if viewModel.includesHealth { await viewModel.loadHealthTrends(context: modelContext) }
        }
        .sheet(item: $shareFile, onDismiss: {
            // Sent, cancelled or swiped away: the file shouldn't outlive the sheet.
            if let writtenFile { ReportPDF.remove(at: writtenFile) }
            writtenFile = nil
        }) { file in
            ActivityView(items: [file.url]) { _ in shareFile = nil }
                .presentationDetents([.medium, .large])
                .ignoresSafeArea()
        }
        .alert("Couldn't make the PDF", isPresented: $createFailed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your \(UIDevice.current.model) may be low on storage. Try again in a moment.")
        }
    }

    @ViewBuilder
    private var periodFooter: some View {
        if let report = viewModel.report {
            Text(viewModel.canCreate ? ReportText(report: report).dates : "Nothing logged in this period")
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            thumbnail
            VStack(alignment: .leading, spacing: 6) {
                if let layout = viewModel.layout {
                    Text(layout.pages.count == 1 ? "1 page · PDF" : "\(layout.pages.count) pages · PDF")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                }
                Text("Goals, daily totals, hit rates and your notes. Made on your \(UIDevice.current.model).")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(nil)  // a section header keeps text to one line otherwise
                    .fixedSize(horizontal: false, vertical: true)
                Button("Preview") { showPreview = true }
                    .font(.body.weight(.semibold))
                    .foregroundStyle(colorScheme == .dark ? Theme.green : Theme.forest)
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                    .disabled(!viewModel.canCreate)
            }
            Spacer(minLength: 0)
        }
    }

    /// The real cover, shrunk.
    private var thumbnail: some View {
        let width: CGFloat = 92
        return ZStack {
            if let report = viewModel.report, let layout = viewModel.layout {
                let scale = width / layout.paper.size.width
                ReportPageView(report: report, layout: layout, index: 0, generatedOn: .now)
                    .scaleEffect(scale, anchor: .topLeading)
                    .frame(width: width, height: layout.paper.size.height * scale, alignment: .topLeading)
            } else {
                Color.white.frame(width: width, height: width * 1.41)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
        // A picture of the cover: its text is too small to read, and VoiceOver shouldn't walk through it.
        .accessibilityElement(children: .ignore)
        .accessibilityHidden(true)
    }

    // MARK: - Create

    private var createButton: some View {
        Button {
            create()
        } label: {
            Label("Create PDF", systemImage: "square.and.arrow.up")
                .font(.headline)
                .foregroundStyle(Theme.controlOnPrimary)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(Theme.controlPrimary,
                            in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
                .opacity(viewModel.canCreate ? 1 : 0.4)
        }
        .buttonStyle(.plain)
        .disabled(!viewModel.canCreate)
    }

    private func create() {
        guard let report = viewModel.report, let layout = viewModel.layout else { return }
        do {
            let url = try ReportPDF.write(report: report, layout: layout)
            writtenFile = url
            shareFile = ShareFile(url: url)
        } catch {
            createFailed = true
        }
    }
}

/// The report's nutrients: every one tracked in the period, checked when it's in (never-logged ones start out). At
/// least one stays in.
private struct ReportNutrientsView: View {
    @Bindable var viewModel: ReportViewModel

    var body: some View {
        List {
            Section {
                ForEach(viewModel.candidates) { candidate in
                    let isIn = viewModel.isIncluded(candidate)
                    Button {
                        viewModel.toggle(candidate)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(candidate.name).foregroundStyle(Theme.textPrimary)
                                if !candidate.hasEntries {
                                    Text("No entries in this period")
                                        .font(.footnote)
                                        .foregroundStyle(Theme.textSecondary)
                                }
                            }
                            Spacer()
                            if isIn {
                                Image(systemName: "checkmark")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(Theme.controlPrimary)
                                    .accessibilityHidden(true)  // .isSelected says it; VoiceOver reads ✓ as "Selected"
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(isIn && viewModel.selectedCount == 1)
                    .accessibilityAddTraits(isIn ? .isSelected : [])
                }
            } footer: {
                Text("Nutrients you tracked in this period. Ones with no entries start unchecked.")
            }
            .listRowBackground(Theme.surfaceCard)
        }
        .scrollContentBackground(.hidden)
        .background(Theme.surfaceGround)
        .navigationTitle("Nutrients")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// The pages as they'll print, scaled to the screen's width.
private struct ReportPreviewView: View {
    let report: DoctorReport
    let layout: ReportLayout
    @State private var width: CGFloat = 0

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(layout.pages.indices, id: \.self) { index in
                    let scale = width > 0 ? width / layout.paper.size.width : 0.5
                    ReportPageView(report: report, layout: layout, index: index, generatedOn: .now)
                        .scaleEffect(scale, anchor: .topLeading)
                        .frame(width: layout.paper.size.width * scale, height: layout.paper.size.height * scale,
                               alignment: .topLeading)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
                        .accessibilityElement(children: .contain)
                        .accessibilityLabel(ReportText.pageNumber(index + 1, of: layout.pages.count))
                }
            }
            .padding(Theme.Spacing.screenMargin)
            .onGeometryChange(for: CGFloat.self) { $0.size.width - 2 * Theme.Spacing.screenMargin } action: { width = $0 }
        }
        .background(Theme.surfaceGround)
        .navigationTitle("Preview")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("Report") {
    NavigationStack {
        ReportView(showsCancel: true)
    }
    .modelContainer(previewContainer)
}

#Preview("Dark") {
    NavigationStack {
        ReportView(showsCancel: true)
    }
    .modelContainer(previewContainer)
    .preferredColorScheme(.dark)
}
