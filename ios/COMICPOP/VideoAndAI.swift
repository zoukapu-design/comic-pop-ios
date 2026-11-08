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
    static func redraw(image:UIImage,card:PinDefinition,pin:MangaPin,style:String,colorMode:String,account:String,token:String,seed:Int,story:MangaStoryBeat?=nil,seriesPremise:String="",previousDrawing:UIImage?=nil,alternateComposition:Bool=false) async throws -> UIImage {
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
        let scene=(defaults.object(forKey:"pop.hint.scene") as? Bool) ?? true
        let fidelity=(defaults.object(forKey:"pop.hint.fidelity") as? Bool) ?? false
        let hints=[
            character ? "Preserve recognisable facial features and clothing of the original subject in every panel." : "",
            palette ? "Keep a coherent ink density, line weight and limited palette throughout the page." : "",
            scene ? "Place especially strong emphasis on actual shot changes and background transitions." : "",
            fidelity ? "Prioritise faithful composition and object positions over dramatic embellishment." : ""
        ].filter{!$0.isEmpty}.joined(separator:" ")
        // The pin is one dramatic beat in a whole chapter. The source frame is
        // visual evidence, not a command to copy the shot exactly.
        let alternate=alternateComposition
            ? "THIS IS A RETAKE BECAUSE THE LAST COMPOSITION WAS TOO SIMILAR. Use a very DIFFERENT camera distance and angle, clearer emotion and different character posing, while keeping story beats, characters and clothing consistent."
            : "Produce a different meaningful event and camera framing from the preceding scene; never reuse its composition."
        let combinedEmotion=card.title.contains("＋")
            ? "CRITICAL: all emotional cards \(card.title) belong to ONE SAME VIDEO MOMENT. Blend ALL effects in ONE illustration. Dramatic + Horror means an ominous, high-stakes manga scene, NOT two pictures."
            : "Express the requested narrative card naturally in this one illustration."
        let approvedDirection=story?.userVisualDirection ?? ""
        let plotAction=String((story?.plotDescriptionJP ?? pin.note).prefix(150))
        let plannedIllustration=String((story?.imagePrompt ?? pin.note).prefix(540))
        // Critical: this model prompt is capped. Put the actual action and the
        // scene's story responsibility FIRST, never after verbose style advice.
        let primaryInstructions=[
            "Original sequential JAPANESE MANGA art. ONE panel, a NEW story event; not a photo filter.",
            MangaStyles.prompt(for:style),color,
            "ACTUAL PLOT EVENT: \(plotAction).",
            "DRAW THIS SPECIFIC EVENT AND COMPOSITION: \(plannedIllustration).",
            "CAUSAL CONNECTION TO PREVIOUS SCENE: \(String((story?.causalLinkJP ?? "").prefix(120))).",
            "STORY ROLE: \(story?.narrativeDutyJP ?? "").",
            combinedEmotion,
            approvedDirection.isEmpty
                ? ""
                : "HIGHEST PRIORITY USER DIRECTION: \(String(approvedDirection.prefix(300))). Override the AI's suggested scene action and composition when this conflicts.",
            alternate,
            "CHAPTER: \(String(seriesPremise.prefix(150))).",
            "CARD EMOTIONS: \(card.title), \(String(card.subtitle.prefix(160)))."
        ].filter{!$0.isEmpty}
        let secondaryInstructions=[
            "Keep the same protagonist, clothing, hairstyle and setting across adjacent panels.",
            "Input image 0 depicts the current moment. Use it as evidence, not as a fixed camera angle.",
            "If image 1 exists, use it ONLY for continuity of the person's identity, clothing and drawing style. Draw a NEW pose, angle and narrative action.",
            "The reaction must answer the prior event. A payoff must visibly follow an earlier setup.",
            "Scene context: \(String((story?.scene ?? "").prefix(125))).",
            "Transition: \(String((story?.transition ?? "").prefix(125))).",
            hints
        ]
        let prompt=(primaryInstructions+secondaryInstructions).joined(separator:" ")
        var form=FormDataBuilder()
        // Always append the no-gibberish instruction OUTSIDE the truncation.
        // The iOS renderer typesets natural Japanese dialogue and captions.
        let neverText="ABSOLUTELY NO WORDS, NO KANJI, NO FAKE LETTERS OR SPEECH BALLOONS. APP TYPESETS ALL JAPANESE LETTERING AFTER GENERATION."
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
