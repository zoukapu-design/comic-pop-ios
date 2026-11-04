import CoreImage
import UIKit

/// True image operations used by the quality controls in the third screen.
/// These are post-processing filters, NOT fabricated quality/AI confidence metrics.
enum PopPageFinisher {
    private static let context = CIContext()
    static func render(_ source:UIImage,contrast:Double,brightness:Double,
                       saturation:Double,sharpness:Double)->UIImage? {
        guard let cg=source.cgImage else {return nil}
        let input=CIImage(cgImage:cg)
        var image=input
        if let color=CIFilter(name:"CIColorControls") {
            color.setValue(image,forKey:kCIInputImageKey)
            color.setValue(min(1.7,max(0.7,contrast)),forKey:kCIInputContrastKey)
            color.setValue(min(0.2,max(-0.2,brightness)),forKey:kCIInputBrightnessKey)
            color.setValue(min(1.6,max(0.0,saturation)),forKey:kCIInputSaturationKey)
            image=color.outputImage ?? image
        }
        if let sharpen=CIFilter(name:"CISharpenLuminance") {
            sharpen.setValue(image,forKey:kCIInputImageKey)
            sharpen.setValue(min(1.5,max(0.0,sharpness)),forKey:kCIInputSharpnessKey)
            image=sharpen.outputImage ?? image
        }
        guard let output=context.createCGImage(image.cropped(to:input.extent),from:input.extent)
        else {return nil}
        return UIImage(cgImage:output,scale:source.scale,orientation:source.imageOrientation)
    }
}
