import CoreImage
import UIKit

/// An on-device visual fallback: real video frames with comic-style processing.
/// It is not generative AI and it never sends video/images to a server.
enum OfflineComicFilter {
    private static let context = CIContext(options: [.useSoftwareRenderer: false])

    static func render(_ source: UIImage, style: String, colorMode: String) -> UIImage? {
        guard let inputCG = source.cgImage else { return nil }
        let sourceImage = CIImage(cgImage: inputCG)
        var output = sourceImage
        if let comic = CIFilter(name: "CIComicEffect") {
            comic.setValue(output, forKey: kCIInputImageKey)
            output = comic.outputImage ?? output
        }
        if let colors = CIFilter(name: "CIColorControls") {
            colors.setValue(output, forKey: kCIInputImageKey)
            let saturation: Double = colorMode == "mono" ? 0.0 : (style == "american" ? 1.35 : 1.08)
            let contrast: Double = ["horror", "suspense", "shonen", "seinen"].contains(style) ? 1.36 : 1.16
            colors.setValue(saturation, forKey: kCIInputSaturationKey)
            colors.setValue(contrast, forKey: kCIInputContrastKey)
            colors.setValue(0.02, forKey: kCIInputBrightnessKey)
            output = colors.outputImage ?? output
        }
        guard let result = context.createCGImage(output.cropped(to: sourceImage.extent), from: sourceImage.extent) else { return nil }
        return UIImage(cgImage: result, scale: source.scale, orientation: source.imageOrientation)
    }
}
