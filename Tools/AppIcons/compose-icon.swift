// compose-icon.swift: an alternate app icon from the app icon's own mark (#139).
//
//   swift Tools/AppIcons/compose-icon.swift <app icon.png> <out.png> --background <#RRGGBB | image.png> --mark <#RRGGBB>
//
// The "n+" mark is never redrawn (DESIGN.md §5.8): each pixel of the 1024 pt app icon is placed on the line from its
// forest background to its green mark, which gives the mark's anti-aliased edges as an alpha mask. The mark is then
// drawn in `--mark` over `--background`, a flat colour or an image scaled to 1024 × 1024. The output is an opaque
// 1024 × 1024 PNG, as App Store icons have to be.
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct RGB { var r, g, b: Double }

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

func hex(_ text: String) -> RGB? {
    let digits = text.hasPrefix("#") ? String(text.dropFirst()) : text
    guard digits.count == 6, let value = UInt32(digits, radix: 16) else { return nil }
    return RGB(r: Double((value >> 16) & 0xFF), g: Double((value >> 8) & 0xFF), b: Double(value & 0xFF))
}

func load(_ path: String) -> CGImage {
    guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { fail("Can't read \(path)") }
    return image
}

/// RGBA bytes of `image` drawn at `size` × `size`.
func pixels(_ image: CGImage, size: Int) -> [UInt8] {
    var bytes = [UInt8](repeating: 0, count: size * size * 4)
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    bytes.withUnsafeMutableBytes { buffer in
        let context = CGContext(data: buffer.baseAddress, width: size, height: size, bitsPerComponent: 8,
                                bytesPerRow: size * 4, space: space,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: size, height: size))
    }
    return bytes
}

let arguments = CommandLine.arguments
guard arguments.count >= 7 else {
    fail("usage: compose-icon.swift <app icon.png> <out.png> --background <#RRGGBB | image.png> --mark <#RRGGBB>")
}
let size = 1024
let iconPath = arguments[1], outPath = arguments[2]
var backgroundArgument: String?
var markArgument: String?
var index = 3
while index + 1 < arguments.count {
    switch arguments[index] {
    case "--background": backgroundArgument = arguments[index + 1]
    case "--mark": markArgument = arguments[index + 1]
    default: fail("Unknown option \(arguments[index])")
    }
    index += 2
}
guard let backgroundArgument, let markArgument, let mark = hex(markArgument) else { fail("Need --background and --mark") }

let icon = pixels(load(iconPath), size: size)
func colour(at x: Int, _ y: Int) -> RGB {
    let i = (y * size + x) * 4
    return RGB(r: Double(icon[i]), g: Double(icon[i + 1]), b: Double(icon[i + 2]))
}
// The icon's two colours: its background in a corner, its mark in the n's left stem.
let forest = colour(at: 12, 12)
let green = colour(at: 215, 700)
let axis = RGB(r: green.r - forest.r, g: green.g - forest.g, b: green.b - forest.b)
let axisLength = axis.r * axis.r + axis.g * axis.g + axis.b * axis.b
guard axisLength > 100 else { fail("The icon's mark and background are too alike to separate") }

let background: [UInt8]
if let flat = hex(backgroundArgument) {
    background = (0..<(size * size)).flatMap { _ in [UInt8(flat.r), UInt8(flat.g), UInt8(flat.b), 255] }
} else {
    background = pixels(load(backgroundArgument), size: size)
}

var out = [UInt8](repeating: 255, count: size * size * 4)
for pixel in 0..<(size * size) {
    let i = pixel * 4
    let p = RGB(r: Double(icon[i]) - forest.r, g: Double(icon[i + 1]) - forest.g, b: Double(icon[i + 2]) - forest.b)
    let alpha = min(1, max(0, (p.r * axis.r + p.g * axis.g + p.b * axis.b) / axisLength))
    out[i] = UInt8((Double(background[i]) * (1 - alpha) + mark.r * alpha).rounded())
    out[i + 1] = UInt8((Double(background[i + 1]) * (1 - alpha) + mark.g * alpha).rounded())
    out[i + 2] = UInt8((Double(background[i + 2]) * (1 - alpha) + mark.b * alpha).rounded())
}

let space = CGColorSpace(name: CGColorSpace.sRGB)!
let image: CGImage = out.withUnsafeMutableBytes { buffer in
    let context = CGContext(data: buffer.baseAddress, width: size, height: size, bitsPerComponent: 8,
                            bytesPerRow: size * 4, space: space,
                            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    return context.makeImage()!
}
guard let destination = CGImageDestinationCreateWithURL(URL(fileURLWithPath: outPath) as CFURL,
                                                        UTType.png.identifier as CFString, 1, nil) else {
    fail("Can't write \(outPath)")
}
CGImageDestinationAddImage(destination, image, nil)
guard CGImageDestinationFinalize(destination) else { fail("Can't write \(outPath)") }
print("\(outPath): mark \(markArgument) on \(backgroundArgument), the icon's colours \(forest) / \(green)")
