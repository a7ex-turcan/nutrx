// Composes App Store marketing screenshots from raw simulator captures: a forest background (or a light one),
// a two-line headline in SF Pro Rounded, and the capture inside a drawn device frame.
//
//   swift Tools/AppStoreScreenshots/compose.swift <panels.json> <raw dir> <output dir>
//
// panels.json: { "panels": [ { "output", "device": "iphone" | "ipad" | "ipadLandscape" | "duoOuter" |
// "duoInner" | "watch", "raw", "line1", "line2", "style": "forest" | "light" } ] }. Raw paths are relative to <raw dir>. Dependency-free (AppKit / Core Graphics).

import AppKit

/// `ipadLandscape` is the iPad 13" slot in landscape (2752 × 2064); `duoOuter` and `duoInner` are the iPhone Duo's
/// two slots: the outer display in portrait (1398 × 2034) and the inner display unfolded, in landscape (2853 × 2007).
enum Device: String, Decodable { case iphone, ipad, ipadLandscape, duoOuter, duoInner, watch }
enum Style: String, Decodable { case forest, light }

/// A typo in panels.json ("iPhone", "dark") fails the decode instead of falling back to a default.
struct Panel: Decodable {
    let output: String
    let device: Device
    let raw: String
    let line1: String
    let line2: String
    let style: Style
}

struct Config: Decodable { let panels: [Panel] }

/// Canvas and layout per App Store display type.
struct Layout {
    let canvas: CGSize
    let headlineTop: CGFloat
    let fontSize: CGFloat
    let deviceWidth: CGFloat      // drawn screen width
    let deviceTop: CGFloat        // screen top, from the canvas top
    let cornerRatio: CGFloat      // screen corner radius / screen width
    let bezel: CGFloat
    let island: Bool

    static func forDevice(_ device: Device) -> Layout {
        switch device {
        case .ipad:
            return Layout(canvas: CGSize(width: 2064, height: 2752), headlineTop: 170, fontSize: 118,
                          deviceWidth: 1860, deviceTop: 540, cornerRatio: 0.028, bezel: 40, island: false)
        case .ipadLandscape:
            // Headline above, the landscape iPad below, sized to the height that's left.
            return Layout(canvas: CGSize(width: 2752, height: 2064), headlineTop: 110, fontSize: 108,
                          deviceWidth: 1960, deviceTop: 440, cornerRatio: 0.026, bezel: 38, island: false)
        case .duoOuter:
            return Layout(canvas: CGSize(width: 1398, height: 2034), headlineTop: 120, fontSize: 86,
                          deviceWidth: 1020, deviceTop: 420, cornerRatio: 0.11, bezel: 22, island: false)
        case .duoInner:
            // Unfolded, in landscape, like an open book.
            return Layout(canvas: CGSize(width: 2853, height: 2007), headlineTop: 105, fontSize: 104,
                          deviceWidth: 2080, deviceTop: 420, cornerRatio: 0.03, bezel: 30, island: false)
        case .watch:
            // Watch art on the iPhone canvas: the capture is small, so it's drawn large in a watch case.
            return Layout(canvas: CGSize(width: 1320, height: 2868), headlineTop: 190, fontSize: 104,
                          deviceWidth: 920, deviceTop: 940, cornerRatio: 0.24, bezel: 76, island: false)
        case .iphone:
            return Layout(canvas: CGSize(width: 1320, height: 2868), headlineTop: 190, fontSize: 104,
                          deviceWidth: 1000, deviceTop: 600, cornerRatio: 0.145, bezel: 24, island: true)
        }
    }
}

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

let forest = color(0x1B3B2D), green = color(0x1EB955), greenSoft = color(0x7BE3A0), ground = color(0xF2F4EF)

func roundedHeavy(_ size: CGFloat) -> NSFont {
    let base = NSFont.systemFont(ofSize: size, weight: .heavy)
    guard let descriptor = base.fontDescriptor.withDesign(.rounded) else { return base }
    return NSFont(descriptor: descriptor, size: size) ?? base
}

/// Draws `image` to fill `rect` (aspect fill, centred), in a flipped context.
func drawFill(_ image: NSImage, in rect: CGRect, anchorBottom: Bool = false) {
    let scale = max(rect.width / image.size.width, rect.height / image.size.height)
    let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
    let origin = CGPoint(x: rect.midX - size.width / 2,
                         y: anchorBottom ? rect.maxY - size.height : rect.midY - size.height / 2)
    image.draw(in: CGRect(origin: origin, size: size), from: .zero, operation: .sourceOver, fraction: 1,
               respectFlipped: true, hints: [.interpolation: NSImageInterpolation.high])
}

func render(_ panel: Panel, rawDir: URL, outDir: URL, background: NSImage, wideBackground: NSImage) throws {
    let layout = Layout.forDevice(panel.device)
    guard let shot = NSImage(contentsOf: rawDir.appendingPathComponent(panel.raw)) else {
        throw NSError(domain: "compose", code: 1, userInfo: [NSLocalizedDescriptionKey: "missing \(panel.raw)"])
    }
    let pixels = shot.representations.first.map { CGSize(width: $0.pixelsWide, height: $0.pixelsHigh) } ?? shot.size
    shot.size = pixels

    // Opaque sRGB bitmap: App Store screenshots must not have an alpha channel.
    let cg = CGContext(data: nil, width: Int(layout.canvas.width), height: Int(layout.canvas.height),
                       bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                       bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: cg, flipped: true)
    cg.translateBy(x: 0, y: layout.canvas.height)
    cg.scaleBy(x: 1, y: -1)
    let canvas = CGRect(origin: .zero, size: layout.canvas)
    let isLight = panel.style == .light

    // Background.
    if isLight {
        ground.setFill(); canvas.fill()
        let glow = NSGradient(colors: [greenSoft.withAlphaComponent(0.55), ground.withAlphaComponent(0)])!
        glow.draw(fromCenter: CGPoint(x: canvas.midX, y: canvas.height * 0.78), radius: 0,
                  toCenter: CGPoint(x: canvas.midX, y: canvas.height * 0.78), radius: canvas.width * 0.9,
                  options: [])
    } else {
        forest.setFill(); canvas.fill()
        // Landscape canvases use the wide art, so it isn't scaled up from the portrait one.
        drawFill(canvas.width > canvas.height ? wideBackground : background, in: canvas, anchorBottom: true)
    }

    // Headline: two centred lines, the second in green.
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    paragraph.lineHeightMultiple = 0.92
    let font = roundedHeavy(layout.fontSize)
    let headline = NSMutableAttributedString(string: panel.line1 + "\n", attributes: [
        .font: font, .foregroundColor: isLight ? forest : NSColor.white, .paragraphStyle: paragraph, .kern: -1.5])
    headline.append(NSAttributedString(string: panel.line2, attributes: [
        .font: font, .foregroundColor: isLight ? green : greenSoft, .paragraphStyle: paragraph, .kern: -1.5]))
    let textRect = CGRect(x: 70, y: layout.headlineTop, width: canvas.width - 140, height: layout.fontSize * 2.6)
    headline.draw(with: textRect, options: [.usesLineFragmentOrigin])

    // Device: shadow, bezel, screen, island.
    let screenSize = CGSize(width: layout.deviceWidth, height: layout.deviceWidth * pixels.height / pixels.width)
    let screen = CGRect(x: canvas.midX - screenSize.width / 2, y: layout.deviceTop, width: screenSize.width,
                        height: screenSize.height)
    let radius = screen.width * layout.cornerRatio
    let body = screen.insetBy(dx: -layout.bezel, dy: -layout.bezel)
    let bodyPath = NSBezierPath(roundedRect: body, xRadius: radius + layout.bezel, yRadius: radius + layout.bezel)

    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(isLight ? 0.25 : 0.5)
    shadow.shadowBlurRadius = 90
    shadow.shadowOffset = CGSize(width: 0, height: -40)
    shadow.set()
    color(0x0C110E).setFill(); bodyPath.fill()
    NSGraphicsContext.restoreGraphicsState()

    // Thin edge highlight, like a metal band.
    color(0xFFFFFF, isLight ? 0.35 : 0.16).setStroke()
    bodyPath.lineWidth = 3
    bodyPath.stroke()

    if panel.device == .watch {
        // Digital crown and side button.
        let crown = CGRect(x: body.maxX - 6, y: body.minY + body.height * 0.24, width: 34, height: body.height * 0.16)
        color(0x2A302C).setFill(); NSBezierPath(roundedRect: crown, xRadius: 14, yRadius: 14).fill()
        let button = CGRect(x: body.maxX - 4, y: body.minY + body.height * 0.52, width: 22, height: body.height * 0.22)
        color(0x1E2320).setFill(); NSBezierPath(roundedRect: button, xRadius: 10, yRadius: 10).fill()
    }

    NSGraphicsContext.saveGraphicsState()
    NSBezierPath(roundedRect: screen, xRadius: radius, yRadius: radius).addClip()
    shot.draw(in: screen, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true,
              hints: [.interpolation: NSImageInterpolation.high])
    NSGraphicsContext.restoreGraphicsState()

    if layout.island {
        let width = screen.width * 0.29, height = screen.width * 0.085
        let island = CGRect(x: screen.midX - width / 2, y: screen.minY + screen.width * 0.026, width: width,
                            height: height)
        NSColor.black.setFill()
        NSBezierPath(roundedRect: island, xRadius: height / 2, yRadius: height / 2).fill()
    }

    NSGraphicsContext.restoreGraphicsState()

    let url = outDir.appendingPathComponent(panel.output) as CFURL
    guard let image = cg.makeImage(),
          let destination = CGImageDestinationCreateWithURL(url, "public.png" as CFString, 1, nil) else {
        throw NSError(domain: "compose", code: 2, userInfo: [NSLocalizedDescriptionKey: "can't write \(panel.output)"])
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw NSError(domain: "compose", code: 3, userInfo: [NSLocalizedDescriptionKey: "writing \(panel.output) failed"])
    }
    print("\(panel.output)  \(cg.width)×\(cg.height)")
}

let args = CommandLine.arguments
guard args.count == 4 else {
    print("usage: swift compose.swift <panels.json> <raw dir> <output dir>"); exit(2)
}
let configURL = URL(fileURLWithPath: args[1])
let config = try JSONDecoder().decode(Config.self, from: Data(contentsOf: configURL))
let rawDir = URL(fileURLWithPath: args[2]), outDir = URL(fileURLWithPath: args[3])
try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
let backgroundURL = configURL.deletingLastPathComponent().appendingPathComponent("background-forest.jpg")
guard let background = NSImage(contentsOf: backgroundURL) else { print("missing \(backgroundURL.path)"); exit(1) }
let wideURL = configURL.deletingLastPathComponent().appendingPathComponent("background-forest-wide.jpg")
guard let wideBackground = NSImage(contentsOf: wideURL) else { print("missing \(wideURL.path)"); exit(1) }
var failed = false
for panel in config.panels {
    do { try render(panel, rawDir: rawDir, outDir: outDir, background: background, wideBackground: wideBackground) }
    catch { print("✗ \(panel.output): \(error.localizedDescription)"); failed = true }
}
exit(failed ? 1 : 0)
