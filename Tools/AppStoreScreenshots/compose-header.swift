// Composes the App Store "Header and Search Results" creative asset: one universal 5244×2950 image (16:9) that
// App Store Connect crops to the 21:9 product page header and the 3:2 search result. The headline sits on the left
// and the real Today screen in an iPhone, with the Watch app beside it, on the right — all inside the area both
// crops keep (x 410–4834, y 352–2598).
//
//   swift Tools/AppStoreScreenshots/compose-header.swift <iPhone capture> <Watch capture> <output.png> [--guides]
//
// --guides draws the two crops (red: header, blue: search) for review; never upload that version. The Watch
// simulator can't fake its status-bar time, so its clock is redrawn as 9:41 to match the iPhone capture.
// Dependency-free (AppKit / Core Graphics); the output is an opaque PNG.

import AppKit

let width: CGFloat = 5244, height: CGFloat = 2950

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

func roundedHeavy(_ size: CGFloat) -> NSFont {
    let base = NSFont.systemFont(ofSize: size, weight: .heavy)
    return base.fontDescriptor.withDesign(.rounded).flatMap { NSFont(descriptor: $0, size: size) } ?? base
}

func load(_ path: String) -> NSImage {
    guard let image = NSImage(contentsOfFile: path) else { print("can't read \(path)"); exit(1) }
    if let rep = image.representations.first { image.size = CGSize(width: rep.pixelsWide, height: rep.pixelsHigh) }
    return image
}

/// An opaque, top-left-origin sRGB context that AppKit drawing goes into.
func makeContext(width: Int, height: Int) -> CGContext {
    let cg = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                       space: CGColorSpace(name: CGColorSpace.sRGB)!,
                       bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    NSGraphicsContext.current = NSGraphicsContext(cgContext: cg, flipped: true)
    cg.translateBy(x: 0, y: CGFloat(height))
    cg.scaleBy(x: 1, y: -1)
    return cg
}

/// The Watch capture with its status-bar clock (top right of the 416×496 screen) redrawn as 9:41.
func watchAt941(_ capture: NSImage) -> NSImage {
    let size = capture.size
    let cg = makeContext(width: Int(size.width), height: Int(size.height))
    capture.draw(in: CGRect(origin: .zero, size: size), from: .zero, operation: .copy, fraction: 1,
                 respectFlipped: true, hints: nil)
    let scale = size.width / 416
    NSColor.black.setFill()
    CGRect(x: 296 * scale, y: 28 * scale, width: 110 * scale, height: 44 * scale).fill()
    let font = NSFont.systemFont(ofSize: 31 * scale, weight: .regular)
    let time = NSAttributedString(string: "9:41", attributes: [.font: font, .foregroundColor: NSColor.white])
    time.draw(at: CGPoint(x: 389 * scale - time.size().width, y: 66 * scale - font.ascender))
    let image = NSImage(cgImage: cg.makeImage()!, size: size)
    return image
}

/// A device body (shadow, bezel, edge highlight), the capture clipped to the screen, and an island or a crown.
func drawDevice(_ shot: NSImage, screen: CGRect, cornerRatio: CGFloat, bezel: CGFloat, island: Bool, crown: Bool) {
    let radius = screen.width * cornerRatio, body = screen.insetBy(dx: -bezel, dy: -bezel)
    let path = NSBezierPath(roundedRect: body, xRadius: radius + bezel, yRadius: radius + bezel)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.55)
    shadow.shadowBlurRadius = 120
    shadow.shadowOffset = CGSize(width: 0, height: -50)
    shadow.set()
    color(0x0C110E).setFill(); path.fill()
    NSGraphicsContext.restoreGraphicsState()
    color(0xFFFFFF, 0.16).setStroke(); path.lineWidth = 4; path.stroke()
    if crown {
        color(0x2A302C).setFill()
        NSBezierPath(roundedRect: CGRect(x: body.maxX - 8, y: body.minY + body.height * 0.24, width: 40,
                                         height: body.height * 0.16), xRadius: 16, yRadius: 16).fill()
        color(0x1E2320).setFill()
        NSBezierPath(roundedRect: CGRect(x: body.maxX - 6, y: body.minY + body.height * 0.52, width: 26,
                                         height: body.height * 0.22), xRadius: 12, yRadius: 12).fill()
    }
    NSGraphicsContext.saveGraphicsState()
    NSBezierPath(roundedRect: screen, xRadius: radius, yRadius: radius).addClip()
    shot.draw(in: screen, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true,
              hints: [.interpolation: NSImageInterpolation.high])
    NSGraphicsContext.restoreGraphicsState()
    if island {
        let w = screen.width * 0.29, h = screen.width * 0.085
        NSColor.black.setFill()
        NSBezierPath(roundedRect: CGRect(x: screen.midX - w / 2, y: screen.minY + screen.width * 0.026, width: w,
                                         height: h), xRadius: h / 2, yRadius: h / 2).fill()
    }
}

let args = CommandLine.arguments
guard args.count == 4 || (args.count == 5 && args[4] == "--guides") else {
    print("usage: swift compose-header.swift <iPhone capture> <Watch capture> <output.png> [--guides]"); exit(2)
}
let toolDir = URL(fileURLWithPath: args[0]).deletingLastPathComponent()
let background = load(toolDir.appendingPathComponent("background-forest-wide.jpg").path)
let phone = load(args[1])
let watch = watchAt941(load(args[2]))

let cg = makeContext(width: Int(width), height: Int(height))
background.draw(in: CGRect(x: 0, y: 0, width: width, height: height), from: .zero, operation: .copy, fraction: 1,
                respectFlipped: true, hints: [.interpolation: NSImageInterpolation.high])

// Headline, left, vertically centred.
let paragraph = NSMutableParagraphStyle()
paragraph.lineHeightMultiple = 0.9
let headline = NSMutableAttributedString(string: "Track what\nyou take.\n", attributes: [
    .font: roundedHeavy(250), .foregroundColor: NSColor.white, .paragraphStyle: paragraph, .kern: -4])
headline.append(NSAttributedString(string: "Nothing else.", attributes: [
    .font: roundedHeavy(250), .foregroundColor: color(0x7BE3A0), .paragraphStyle: paragraph, .kern: -4]))
let textBounds = headline.boundingRect(with: CGSize(width: 2300, height: 2000), options: [.usesLineFragmentOrigin])
headline.draw(with: CGRect(x: 760, y: (height - textBounds.height) / 2 - 40, width: 2300,
                           height: textBounds.height + 40), options: [.usesLineFragmentOrigin])

// iPhone on the right; the Watch to its left, overlapping only the phone's edge.
let phoneHeight: CGFloat = 1960, phoneWidth = phoneHeight * phone.size.width / phone.size.height
let phoneScreen = CGRect(x: 3560 - phoneWidth / 2, y: (height - phoneHeight) / 2, width: phoneWidth,
                         height: phoneHeight)
drawDevice(phone, screen: phoneScreen, cornerRatio: 0.145, bezel: 22, island: true, crown: false)
let watchWidth: CGFloat = 470, watchHeight = watchWidth * watch.size.height / watch.size.width
drawDevice(watch, screen: CGRect(x: phoneScreen.minX - watchWidth * 1.02, y: phoneScreen.maxY - watchHeight - 120,
                                 width: watchWidth, height: watchHeight),
           cornerRatio: 0.24, bezel: 40, island: false, crown: true)

if args.count == 5 {
    color(0xFF3B30, 0.9).setStroke()
    let header = NSBezierPath(rect: CGRect(x: 0, y: (height - width * 9 / 21) / 2, width: width, height: width * 9 / 21))
    header.lineWidth = 8; header.stroke()
    color(0x0A84FF, 0.9).setStroke()
    let search = NSBezierPath(rect: CGRect(x: (width - height * 1.5) / 2, y: 0, width: height * 1.5, height: height))
    search.lineWidth = 8; search.stroke()
}

let url = URL(fileURLWithPath: args[3]) as CFURL
guard let image = cg.makeImage(), let destination = CGImageDestinationCreateWithURL(url, "public.png" as CFString, 1, nil)
else { print("can't write \(args[3])"); exit(1) }
CGImageDestinationAddImage(destination, image, nil)
guard CGImageDestinationFinalize(destination) else { print("writing \(args[3]) failed"); exit(1) }
print("\(args[3])  \(image.width)×\(image.height)")
