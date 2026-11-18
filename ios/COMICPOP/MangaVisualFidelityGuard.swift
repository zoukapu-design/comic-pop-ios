import UIKit
import Vision

struct MangaVisualFidelityResult {
    let image:UIImage
    let usedSafeFallback:Bool
}

/// Protect user video identity without spending a second AI request.
/// If a locked AI image becomes radically different, use a faithful
/// Core Image manga conversion of the recorded source frame instead.
/// Visual feature prints are a best-effort semantic safeguard; they
/// cannot prove exact person identity, scene meaning or correct age.
enum MangaVisualFidelityGuard {
    private static func fingerprint(_ image:UIImage)->VNFeaturePrintObservation? {
        guard let cg=image.cgImage else {return nil}
        let request=VNGenerateImageFeaturePrintRequest()
        do {
            try VNImageRequestHandler(cgImage:cg,options:[:]).perform([request])
            return request.results?.first
        } catch {
            return nil
        }
    }

    private static func recognizedText(_ image:UIImage)->[String]? {
        guard let cg=image.cgImage else {return nil}
        let request=VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["ja-JP","en-US"]
        request.usesLanguageCorrection = false
        do {
            try VNImageRequestHandler(cgImage:cg,options:[:]).perform([request])
            return request.results?.compactMap{$0.topCandidates(1).first?.string} ?? []
        } catch {
            return nil
        }
    }

    /// Geometric text detection catches distorted glyphs that fail OCR,
    /// including pseudo-kanji in AI-drawn speech balloons. Positions are
    /// normalized so the source and generated frames can be compared.
    private static func textRegions(_ image:UIImage)->[MangaDetectedTextRegion]? {
        guard let cg=image.cgImage else {return nil}
        let request=VNDetectTextRectanglesRequest()
        request.reportCharacterBoxes=true
        do {
            try VNImageRequestHandler(cgImage:cg,options:[:]).perform([request])
            return (request.results ?? []).map { observation in
                let r=observation.boundingBox
                return MangaDetectedTextRegion(
                    centerX:Double(r.midX),centerY:Double(r.midY),
                    width:Double(r.width),height:Double(r.height)
                )
            }
        } catch {
            return nil
        }
    }

    static func protectedImage(generated:UIImage,original:UIImage,
                               style:String,colorMode:String)->MangaVisualFidelityResult {
        let faithful=OfflineComicFilter.render(original,style:style,colorMode:colorMode) ?? original
        // The generated image must be free of *new* letter-like regions.
        // Shape detection is more robust than Japanese OCR for pseudo-glyphs.
        // If Vision cannot inspect either image, fail closed to the faithful
        // filmed-frame comic instead of displaying unchecked fake lettering.
        guard let aiRegions=textRegions(generated),
              let sourceRegions=textRegions(original) else {
            return MangaVisualFidelityResult(image:faithful,usedSafeFallback:true)
        }
        if MangaFidelityDistancePolicy.hasUnexpectedTextRegions(
            generated:aiRegions,original:sourceRegions
        ) {
            return MangaVisualFidelityResult(image:faithful,usedSafeFallback:true)
        }
        // Text painted into the AI image is distinct from editable native
        // lettering. Reject sufficiently clear new glyphs not present in
        // the user's actual recorded frame.
        if let imageTexts=recognizedText(generated),
           let sourceTexts=recognizedText(original),
           MangaFidelityDistancePolicy.hasUnexpectedText(
               generated:imageTexts,original:sourceTexts
           ) {
            return MangaVisualFidelityResult(image:faithful,usedSafeFallback:true)
        }
        guard let sourcePrint=fingerprint(original),
              let localPrint=fingerprint(faithful),
              let aiPrint=fingerprint(generated) else {
            // Preserve the actual filmed content when automated assessment
            // is unavailable instead of silently publishing an unchecked AI scene.
            return MangaVisualFidelityResult(image:faithful,usedSafeFallback:true)
        }
        var localDistance:Float=0
        var aiDistance:Float=0
        do {
            try sourcePrint.computeDistance(&localDistance,to:localPrint)
            try sourcePrint.computeDistance(&aiDistance,to:aiPrint)
        } catch {
            return MangaVisualFidelityResult(image:faithful,usedSafeFallback:true)
        }
        guard !MangaFidelityDistancePolicy.isUnreliable(
            generated:aiDistance,localComic:localDistance
        ) else {
            return MangaVisualFidelityResult(image:faithful,usedSafeFallback:true)
        }
        return MangaVisualFidelityResult(image:generated,usedSafeFallback:false)
    }
}
