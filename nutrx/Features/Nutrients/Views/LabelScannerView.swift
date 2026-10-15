import AVFoundation
import PhotosUI
import SwiftUI
import VisionKit

/// The full-screen label scanner (nutrx Pro, docs/pro/design/4-scan-label: scanner, reading, fail). Live text
/// highlights from VisionKit's `DataScannerViewController`; the shutter freezes a photo, which `LabelScan` reads on
/// the device. Where live scanning isn't possible (no camera, camera access off, the simulator) a photo from the
/// library does the same job. A label that gives nothing usable opens "Couldn't read this label".
struct LabelScannerView: View {
    let onRead: (SupplementLabel) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var camera: Camera = .checking
    @State private var scanner = ScannerHandle()
    @State private var isReading = false
    @State private var showFailure = false
    @State private var torchOn = false
    @State private var photoItem: PhotosPickerItem?
    @State private var showPhotoPicker = false

    enum Camera {
        case checking, live, unsupported, denied
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch camera {
            case .checking:
                EmptyView()
            case .live:
                DataScannerView(handle: scanner)
                    .ignoresSafeArea()
                    .accessibilityHidden(true)
            case .unsupported, .denied:
                unavailablePanel
            }

            if isReading {
                Color.black.opacity(0.5).ignoresSafeArea()
                readingPill
            }
        }
        .safeAreaInset(edge: .top) { topBar }
        .safeAreaInset(edge: .bottom) { bottomBar }
        .environment(\.colorScheme, .dark)
        .task { camera = await Self.cameraState() }
        // One picker for the whole screen, presented from here rather than from a button inside the switching
        // content, so nothing it covers can take it down.
        .photosPicker(isPresented: $showPhotoPicker, selection: $photoItem, matching: .images)
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            photoItem = nil
            Task { await readPhoto(item) }
        }
        .accessibilityHidden(showFailure)
        .onDisappear { scanner.setTorch(false) }
        // Drawn in the scanner rather than presented over it: outside the dark environment above, so it follows the
        // system appearance like the design's sheet, and with no second presentation stacked on the cover.
        .overlay {
            if showFailure {
                ZStack(alignment: .bottom) {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .accessibilityHidden(true)
                    ScanFailCard(
                        onTryAgain: {
                            showFailure = false
                            scanner.resume()
                        },
                        onFillInByHand: {
                            showFailure = false
                            dismiss()
                        }
                    )
                    .transition(.move(edge: .bottom))
                }
            }
        }
        .animation(.unlessReduceMotion(reduceMotion, .easeOut(duration: 0.3)), value: showFailure)
    }

    // MARK: - Chrome

    private var topBar: some View {
        HStack {
            Button("Cancel") { dismiss() }
                .font(.body.weight(.semibold))
                .buttonStyle(.glass)
                .controlSize(.large)
            Spacer()
            if camera == .live, scanner.hasTorch {
                Button {
                    torchOn.toggle()
                    scanner.setTorch(torchOn)
                } label: {
                    Image(systemName: torchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                        .font(.title3)
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .controlSize(.large)
                .accessibilityLabel(torchOn ? "Turn off the light" : "Turn on the light")
            }
        }
        .padding(.horizontal, Theme.Spacing.screenMargin)
        .padding(.top, 8)
        .disabled(isReading)
    }

    private var bottomBar: some View {
        VStack(spacing: 18) {
            if camera == .live {
                Text(ScanText.pointAtFacts)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(.black.opacity(0.75), in: Capsule())

                HStack {
                    photoButton
                    Spacer()
                    shutter
                    Spacer()
                    // Balances the photo button so the shutter stays centred.
                    Color.clear.frame(width: 52, height: 52)
                }
                .padding(.horizontal, 28)
            }

            Label(ScanText.privacy(device: UIDevice.current.model), systemImage: "lock")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(.bottom, 8)
        .disabled(isReading)
    }

    private var shutter: some View {
        Button {
            Task { await capture() }
        } label: {
            ZStack {
                Circle().strokeBorder(.white, lineWidth: 4)
                Circle().fill(.white).padding(9)
            }
            .frame(width: 76, height: 76)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Read the label")
    }

    private var photoButton: some View {
        Button {
            showPhotoPicker = true
        } label: {
            Image(systemName: "photo.on.rectangle")
                .font(.title3)
                .frame(width: 30, height: 30)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .controlSize(.large)
        .frame(width: 52, height: 52)
        .accessibilityLabel("Choose a photo of the label")
    }

    private var readingPill: some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(Theme.green)
            Text(ScanText.reading)
                .font(.headline)
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
        .glassEffect(.regular, in: Capsule())
        .accessibilityElement(children: .combine)
    }

    /// No live scanning here: explain why, and offer a photo instead.
    private var unavailablePanel: some View {
        VStack(spacing: 14) {
            Image(systemName: camera == .denied ? "camera.badge.ellipsis" : "camera")
                .font(.system(size: 34))
                .foregroundStyle(.white.opacity(0.8))
                .accessibilityHidden(true)
            Text(camera == .denied ? "nutrx can't use the camera" : "The camera isn't available")
                .font(.title3.bold())
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Text(camera == .denied
                 ? "Allow camera access in Settings, or choose a photo of the Supplement Facts."
                 : "Choose a photo of the Supplement Facts instead.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)

            Button {
                showPhotoPicker = true
            } label: {
                Label("Choose a photo", systemImage: "photo.on.rectangle")
                    .font(.headline)
                    .foregroundStyle(Theme.forest)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(Theme.green, in: RoundedRectangle(cornerRadius: Theme.Radius.control,
                                                                  style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.top, 8)

            if camera == .denied {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(minHeight: Theme.minTouchTarget)
            }
        }
        .padding(28)
        .frame(maxWidth: 420)
    }

    // MARK: - Reading

    private func capture() async {
        guard !isReading, let photo = await scanner.capturePhoto() else { return }
        await read(photo)
    }

    private func readPhoto(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self), let photo = UIImage(data: data) else {
            showFailure = true
            return
        }
        await read(photo)
    }

    private func read(_ photo: UIImage) async {
        guard let image = photo.cgImage else {
            showFailure = true
            return
        }
        scanner.pause()
        isReading = true
        AccessibilityNotification.Announcement(ScanText.reading).post()
        let label = await LabelScan.read(image, orientation: LabelScan.orientation(of: photo))
        isReading = false
        if let label {
            onRead(label)
            dismiss()
        } else {
            showFailure = true
        }
    }

    /// Whether live scanning can run, asking for the camera the first time.
    private static func cameraState() async -> Camera {
        guard DataScannerViewController.isSupported else { return .unsupported }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined:
            guard await AVCaptureDevice.requestAccess(for: .video) else { return .denied }
        case .authorized:
            break
        default:
            return .denied
        }
        return DataScannerViewController.isAvailable ? .live : .denied
    }
}

// MARK: - VisionKit

/// The scanner's controls, held by the SwiftUI view: VisionKit's controller is created by the representable.
@MainActor
final class ScannerHandle {
    fileprivate weak var controller: DataScannerViewController?

    var hasTorch: Bool { AVCaptureDevice.default(for: .video)?.hasTorch ?? false }

    func capturePhoto() async -> UIImage? {
        try? await controller?.capturePhoto()
    }

    func pause() { controller?.stopScanning() }

    func resume() { try? controller?.startScanning() }

    /// VisionKit has no torch control, so the light goes through the capture device.
    func setTorch(_ on: Bool) {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch,
              (try? device.lockForConfiguration()) != nil else { return }
        device.torchMode = on ? .on : .off
        device.unlockForConfiguration()
    }
}

/// `DataScannerViewController` with text highlights. UIKit, because VisionKit's live scanner has no SwiftUI view.
private struct DataScannerView: UIViewControllerRepresentable {
    let handle: ScannerHandle

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let controller = DataScannerViewController(
            recognizedDataTypes: [.text()],
            qualityLevel: .accurate,
            recognizesMultipleItems: true,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: false,
            isHighlightingEnabled: true
        )
        handle.controller = controller
        try? controller.startScanning()
        return controller
    }

    func updateUIViewController(_ controller: DataScannerViewController, context: Context) {}

    static func dismantleUIViewController(_ controller: DataScannerViewController, coordinator: ()) {
        controller.stopScanning()
    }
}

// MARK: - Fail card

/// "Couldn't read this label" (docs/pro/design/4-scan-label: fail), a bottom card over the scanner.
struct ScanFailCard: View {
    let onTryAgain: () -> Void
    let onFillInByHand: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "text.viewfinder")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(Theme.textAmberInk)
                .frame(width: 64, height: 64)
                .background(NutrientTint.amber.tileBackground,
                            in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                .accessibilityHidden(true)

            Text(ScanText.failTitle)
                .font(.title2.bold())
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.top, 4)
                .accessibilityAddTraits(.isHeader)
            Text(ScanText.failBody)
                .font(.body)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 10) {
                Button(action: onTryAgain) {
                    Text("Try again")
                        .font(.headline)
                        .foregroundStyle(Theme.controlOnPrimary)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(Theme.controlPrimary,
                                    in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
                }
                Button(action: onFillInByHand) {
                    Text("Fill in by hand")
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background {
                            RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                                .strokeBorder(Theme.controlGhostBorder, lineWidth: 1.5)
                        }
                        .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
                }
            }
            .buttonStyle(.plain)
            .padding(.top, 14)
        }
        .padding(.horizontal, 24)
        .padding(.top, 28)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity)
        .background {
            UnevenRoundedRectangle(topLeadingRadius: Theme.Radius.hero + 10, topTrailingRadius: Theme.Radius.hero + 10,
                                   style: .continuous)
                .fill(Theme.surfaceGround)
                .ignoresSafeArea(edges: .bottom)
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
    }
}

#Preview("Fail") {
    ZStack(alignment: .bottom) {
        Color.black.ignoresSafeArea()
        ScanFailCard(onTryAgain: {}, onFillInByHand: {})
    }
}
