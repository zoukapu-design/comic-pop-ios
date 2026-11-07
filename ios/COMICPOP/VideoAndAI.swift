import AVFoundation
import Foundation
import UIKit

struct CloudflareImageResult: Decodable {
    struct ImageResult: Decodable { var image:String? }
    struct CloudflareError: Decodable {var code:Int?;var message:String?}
    var success:Bool?
    var result:ImageResult?
    var errors:[CloudflareError]?
}
struct TokenVerification:Decodable {
    struct Token:Decodable {var status:String?}
    var success:Bool?
    var result:Token?
}

enum MangaError: LocalizedError {
    case noVideo,emptyCards,invalidImage,credentialsMissing,server(String),badResponse
    var errorDescription:String? {
        switch self {
        case .noVideo:return "先に動画を選んでください"
        case .emptyCards:return "ピンカードを追加してください"
        case .invalidImage:return "動画からコマ画像を取得できませんでした"
        case .credentialsMissing:return "自分のCloudflare無料アカウントを接続してください"
        case .server(let m):return m
        case .badResponse:return "Cloudflareから画像を取得できませんでした"
        }
    }
}

struct VideoFrameService {
    static func frame(at seconds:Double,from url:URL) async throws -> UIImage {
        let asset=AVURLAsset(url:url)
        let generator=AVAssetImageGenerator(asset:asset)
        generator.appliesPreferredTrackTransform=true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        generator.maximumSize=CGSize(width:880,height:880)
        let (cg,_) = try await generator.image(at:CMTime(seconds:max(0,seconds),preferredTimescale:600))
        return UIImage(cgImage:cg)
    }
    static func compactJPEG(_ image:UIImage)->Data? {
        let largest=max(image.size.width,image.size.height)
        let factor=min(1,480/max(largest,1))
        let size=CGSize(width:max(1,round(image.size.width*factor)),height:max(1,round(image.size.height*factor)))
        let format=UIGraphicsImageRendererFormat();format.scale=1;format.opaque=true
        let scaled=UIGraphicsImageRenderer(size:size,format:format).image{_ in
            UIColor.white.setFill();UIRectFill(CGRect(origin:.zero,size:size))
            image.draw(in:CGRect(origin:.zero,size:size))
        }
        return scaled.jpegData(compressionQuality:0.7)
    }
}

private struct FormDataBuilder {
    let boundary:String = "comicpop-\(UUID().uuidString)"
    private(set) var data=Data()
    mutating func add(name:String,value:String){
        data.append(Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(value)\r\n".utf8))
    }
    mutating func addJPEG(name:String,bytes:Data){
        data.append(Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"; filename=\"reference.jpg\"\r\nContent-Type: image/jpeg\r\n\r\n".utf8))
        data.append(bytes);data.append(Data("\r\n".utf8))
    }
    mutating func finish(){data.append(Data("--\(boundary)--\r\n".utf8))}
}

struct CloudflareAIService {
    // Native iOS calls the user's own Cloudflare account DIRECTLY. No COMIC POP! server receives the API token.
    private static let root="https://api.cloudflare.com/client/v4"
    private static let model="@cf/black-forest-labs/flux-2-klein-4b"
    private static func accountURL(_ id:String)->URL? {
        guard id.count==32,id.utf8.allSatisfy({("0123456789abcdefABCDEF").utf8.contains($0)}) else{return nil}
        return URL(string:"\(root)/accounts/\(id)/ai/run/\(model)")
    }
    static func verify(account:String,token:String) async throws -> Bool {
        guard accountURL(account) != nil,!token.isEmpty else{return false}
        var request=URLRequest(url:URL(string:"\(root)/user/tokens/verify")!)
        request.httpMethod="GET";request.setValue("Bearer \(token)",forHTTPHeaderField:"Authorization")
        request.timeoutInterval=20
        let (data,response)=try await URLSession.shared.data(for:request)
        guard let http=response as? HTTPURLResponse,http.statusCode==200 else{return false}
        let status=try JSONDecoder().decode(TokenVerification.self,from:data)
        // Token validity is not a confirmation of the Workers Free plan or account permissions.
        return status.success == true && status.result?.status == "active"
    }
    static func redraw(image:UIImage,card:PinDefinition,pin:MangaPin,style:String,colorMode:String,account:String,token:String,seed:Int,story:MangaStoryBeat?=nil,seriesPremise:String="",previousDrawing:UIImage?=nil) async throws -> UIImage {
        guard let jpg=VideoFrameService.compactJPEG(image),jpg.count<700_000 else{throw MangaError.invalidImage}
        guard let url=accountURL(account),!token.isEmpty else{throw MangaError.credentialsMissing}
        let aspect=image.size.width/max(image.size.height,1)
        func align16(_ n:Double)->Int {min(768,max(256,Int((n/16).rounded())*16))}
        let width=aspect>=1 ? 768 : align16(768*aspect)
        let height=aspect>=1 ? align16(768/aspect) : 768
        let color=colorMode=="mono" ? "All panels use the same black and white ink and screentones, no color." : "All panels use consistent full comic color."
        // These are preference *hints* from the UI, not measured quality scores.
        let defaults=UserDefaults.standard
        let character=(defaults.object(forKey:"pop.hint.character") as? Bool) ?? true
        let palette=(defaults.object(forKey:"pop.hint.palette") as? Bool) ?? true
        let scene=(defaults.object(forKey:"pop.hint.scene") as? Bool) ?? false
        let fidelity=(defaults.object(forKey:"pop.hint.fidelity") as? Bool) ?? false
        let hints=[
            character ? "Preserve recognisable facial features and clothing of the original subject in every panel." : "",
            palette ? "Keep a coherent ink density, line weight and limited palette throughout the page." : "",
            scene ? "Place especially strong emphasis on actual shot changes and background transitions." : "",
            fidelity ? "Prioritise faithful composition and object positions over dramatic embellishment." : ""
        ].filter{!$0.isEmpty}.joined(separator:" ")
        // The pin is one dramatic beat in a whole chapter. The source frame is
        // visual evidence, not a command to copy the shot exactly.
        let prompt=[
            "Original cinematic JAPANESE MANGA illustration from a continuous sequential story.",
            "Make this panel advance the story. It is NOT a still-photo filter or documentary storyboard.",
            "Shared chapter premise: \(seriesPremise).",
            "Current storytelling role: \(card.title) / \(card.subtitle).",
            "Panel event: \(story?.scene ?? pin.note).",
            "What to draw: \(story?.imagePrompt ?? pin.note).",
            "Causal transition from prior panel: \(story?.transition ?? "continue preceding action").",
            "Keep principal characters visibly recognizable across adjacent panels: same face, hairstyle, clothing and accessories, and believable recurring locations.",
            "You MAY change camera angle, pose, expression, background detail and implied intermediate action to turn the scene into a compelling manga beat.",
            "Input image 0 is the CURRENT video reference: use its people, place and relevant action as the scene inspiration.",
            "When image 1 is provided, it is the PREVIOUS FINISHED MANGA PANEL. Transfer ONLY character identity, clothing and drawing style from it; do NOT duplicate its pose, background composition or storyline beat.",
            "The written storyboard governs the NEW action and camera angle in this panel. Let the comic progress rather than drawing two near-identical pictures.",
            "Express card emotion strongly in character posture and faces. A reaction must respond to the previous action; final panel should pay off earlier events.",
            MangaStyles.prompt(for:style),color,hints,
            "ABSOLUTELY NO TEXT of ANY language, NO WORDS, NO KANJI, NO GIBBERISH GLYPHS, NO CAPTIONS, NO WATERMARKS, NO speech balloons. The app typeset Japanese speech and captions after generation."
        ].joined(separator:" ")
        var form=FormDataBuilder()
        // Keep the text-exclusion rule intact even when a long screenplay
        // causes the descriptive portion to be truncated.
        let neverText="ABSOLUTELY NO WORDS OR LETTERS OR JAPANESE CHARACTERS OR FAKE WRITING IN THE PICTURE. APP WILL TYPESET ALL JAPANESE CAPTIONS AND SPEECH."
        form.add(name:"prompt",value:String(prompt.prefix(2400))+" "+neverText)
        form.add(name:"width",value:String(width))
        form.add(name:"height",value:String(height))
        form.add(name:"seed",value:String(seed))
        form.add(name:"guidance",value:"4.5")
        form.addJPEG(name:"input_image_0",bytes:jpg)
        if let previousDrawing,
           let continuityJPEG=VideoFrameService.compactJPEG(previousDrawing),
           continuityJPEG.count<700_000 {
            form.addJPEG(name:"input_image_1",bytes:continuityJPEG)
        }
        form.finish()
        var request=URLRequest(url:url)
        request.httpMethod="POST"
        request.timeoutInterval=65
        request.setValue("Bearer \(token)",forHTTPHeaderField:"Authorization")
        request.setValue("multipart/form-data; boundary=\(form.boundary)",forHTTPHeaderField:"Content-Type")
        request.httpBody=form.data
        let (data,response)=try await URLSession.shared.data(for:request)
        guard let http=response as? HTTPURLResponse else{throw MangaError.badResponse}
        let responseBody=try? JSONDecoder().decode(CloudflareImageResult.self,from:data)
        if !(200...299).contains(http.statusCode){
            let code=responseBody?.errors?.first?.code
            let description:String
            switch code {
            case 3036,4006:description="無料枠の制限に達しました。次回の利用可能時刻をCloudflareで確認してください。"
            case 3030:description="このコマはAIの入力審査で拒否されました。無料枠切れではありません。"
            default:description=responseBody?.errors?.first?.message ?? "Cloudflareのエラー"
            }
            throw MangaError.server("\(description) (HTTP \(http.statusCode) / CF \(code.map(String.init) ?? "-") )")
        }
        guard let b64=responseBody?.result?.image,let bytes=Data(base64Encoded:b64),let result=UIImage(data:bytes) else {throw MangaError.badResponse}
        return result
    }
}
