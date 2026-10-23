import AppKit
import CoreImage

/// Renders and caches glyph images per character, size, appearance and scale.
@MainActor
enum GlyphCache {
    struct Glyph {
        let sharp: CGImage
        let blurred: CGImage
        /// Point size of the image, including padding for the blur.
        let size: CGSize
        let advance: CGFloat
    }

    static let blurPadding: CGFloat = 6

    private static var fonts: [CGFloat: NSFont] = [:]
    private static var glyphs: [String: Glyph] = [:]

    /// Semibold SF Rounded with tabular digits.
    static func font(size: CGFloat) -> NSFont {
        if let font = fonts[size] { return font }
        var descriptor = NSFont.systemFont(ofSize: size, weight: .semibold).fontDescriptor
        descriptor = descriptor.withDesign(.rounded) ?? descriptor
        descriptor = descriptor.addingAttributes([
            .featureSettings: [[
                NSFontDescriptor.FeatureKey.typeIdentifier: kNumberSpacingType,
                NSFontDescriptor.FeatureKey.selectorIdentifier: kMonospacedNumbersSelector,
            ]],
        ])
        let font = NSFont(descriptor: descriptor, size: size) ?? .monospacedDigitSystemFont(ofSize: size, weight: .semibold)
        fonts[size] = font
        return font
    }

    static func lineHeight(_ font: NSFont) -> CGFloat {
        ceil(font.ascender - font.descender + font.leading)
    }

    static func glyph(_ char: Character, size: CGFloat, dark: Bool, scale: CGFloat) -> Glyph {
        let key = "\(char)|\(size)|\(dark)|\(scale)"
        if let glyph = glyphs[key] { return glyph }

        let font = font(size: size)
        let string = NSAttributedString(string: String(char), attributes: [
            .font: font,
            .foregroundColor: dark ? NSColor.white : NSColor.black.withAlphaComponent(0.88),
        ])
        let advance = string.size().width
        let pad = blurPadding
        let pointSize = CGSize(width: ceil(advance + pad * 2), height: lineHeight(font) + pad * 2)
        let pixelWidth = Int(pointSize.width * scale), pixelHeight = Int(pointSize.height * scale)

        let sharp = render(pixelWidth, pixelHeight) { context in
            context.scaleBy(x: scale, y: scale)
            // Same placement as a SwiftUI Text line box: baseline `ascender` below the top.
            context.textPosition = CGPoint(x: pad, y: pad + lineHeight(font) - font.ascender)
            CTLineDraw(CTLineCreateWithAttributedString(string), context)
        }
        let blurred = blur(sharp, radius: 4 * scale) ?? sharp

        let glyph = Glyph(sharp: sharp, blurred: blurred, size: pointSize, advance: advance)
        glyphs[key] = glyph
        return glyph
    }

    private static func render(_ width: Int, _ height: Int, draw: (CGContext) -> Void) -> CGImage {
        let context = CGContext(
            data: nil, width: max(width, 1), height: max(height, 1), bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.setShouldSmoothFonts(false)
        draw(context)
        return context.makeImage()!
    }

    private static func blur(_ image: CGImage, radius: CGFloat) -> CGImage? {
        let input = CIImage(cgImage: image)
        guard let filter = CIFilter(name: "CIGaussianBlur", parameters: [kCIInputImageKey: input, kCIInputRadiusKey: radius]),
              let output = filter.outputImage
        else { return nil }
        return CIContext(options: [.useSoftwareRenderer: false]).createCGImage(output, from: input.extent)
    }
}
