import AVFoundation
import Foundation
import Speech
import UIKit
import Vision

/// Uses Apple's device-side Vision framework to identify visual context.
/// This is evidence, not a caption that the model may treat as a certain fact.
enum MangaSceneObservation {
    static func describe(_ image: UIImage) async -> String {
        await Task.detached(priority:.utility) {
            guard let source=image.cgImage else {return "映像情報なし"}
            let request=VNClassifyImageRequest()
            request.usesCPUOnly=true
            do {
                try VNImageRequestHandler(cgImage:source,options:[:]).perform([request])
                let labels=(request.results ?? [])
                    .filter{$0.confidence >= 0.16}
                    .prefix(5)
                    .map{$0.identifier}
                // Original videos often have subtitles or on-screen context
                // absent from still-image classification; read this Japanese
                // text locally and give it to the storyline model as evidence.
                let textRequest=VNRecognizeTextRequest()
                textRequest.recognitionLevel = .accurate
                textRequest.usesLanguageCorrection = true
                textRequest.recognitionLanguages = ["ja-JP","en-US"]
                try? VNImageRequestHandler(cgImage:source,options:[:]).perform([textRequest])
                let recognized=(textRequest.results ?? [])
                    .compactMap{$0.topCandidates(1).first?.string}
                    .filter{!$0.isEmpty}
                    .prefix(3)
                    .joined(separator:" / ")
                let visual=labels.isEmpty ? "映像の分類情報なし" : labels.joined(separator:", ")
                return recognized.isEmpty ? visual : visual + " / on-screen text: " + String(recognized.prefix(115))
            } catch {return "映像の分類に失敗"}
        }.value
    }
}

/// Optional, on-device Japanese speech around user-inserted timestamps.
/// No user audio is sent to Cloudflare or Apple servers by this service.
enum MangaSpeechEvidence {
    static func permission() async -> Bool {
        let status=SFSpeechRecognizer.authorizationStatus()
        if status == .authorized {return true}
        if status == .denied || status == .restricted {return false}
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning:status == .authorized)
            }
        }
    }

    static func around(video:URL,seconds:Double,duration:Double) async -> String {
        guard let recognizer=SFSpeechRecognizer(locale:Locale(identifier:"ja-JP")),
              recognizer.supportsOnDeviceRecognition,recognizer.isAvailable else {return ""}
        let start=max(0,seconds-5)
        let length=max(0.1,min(10,max(0,duration-start)))
        let tmp=FileManager.default.temporaryDirectory
            .appendingPathComponent("movikoma-speech-\(UUID().uuidString).m4a")
        defer {try? FileManager.default.removeItem(at:tmp)}
        let asset=AVURLAsset(url:video)
        guard let exporter=AVAssetExportSession(asset:asset,presetName:AVAssetExportPresetAppleM4A) else {
            return ""
        }
        exporter.outputURL=tmp
        exporter.outputFileType = .m4a
        exporter.timeRange=CMTimeRange(start:CMTime(seconds:start,preferredTimescale:600),
                                        duration:CMTime(seconds:length,preferredTimescale:600))
        let exported=await withCheckedContinuation { (continuation:CheckedContinuation<Bool,Never>) in
            exporter.exportAsynchronously {
                continuation.resume(returning:exporter.status == .completed)
            }
        }
        guard exported else {return ""}
        let request=SFSpeechURLRecognitionRequest(url:tmp)
        request.requiresOnDeviceRecognition=true
        request.shouldReportPartialResults=false
        let gate=SpeechCompletionGate()
        return await withCheckedContinuation { continuation in
            let task=recognizer.recognitionTask(with:request) { result,error in
                if result?.isFinal == true || error != nil {
                    gate.finish(String((result?.bestTranscription.formattedString ?? "").prefix(140)),
                                continuation:continuation)
                }
            }
            // On some iOS builds the recognition callback never delivers a final
            // result. A bounded timeout prevents one card from freezing manga creation.
            DispatchQueue.global().asyncAfter(deadline:.now()+18) {
                task.cancel()
                gate.finish("",continuation:continuation)
            }
        }
    }
}

private struct MangaCloudflareStoryEnvelope: Decodable {
    struct Result: Decodable {let response:String?}
    struct Failure: Decodable {let code:Int?;let message:String?}
    let success:Bool?
    let result:Result?
    let errors:[Failure]?
}

private struct MangaChatCompletion: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {let content:String?}
        let message:Message
    }
    let choices:[Choice]
}
private enum MangaVisualStoryError: Error {
    case unsupported
    case quota
}

/// A single, whole-story text request BEFORE individual image generation.
/// This is the user's own Workers AI account, under the same free-tier consent.
enum MangaStoryAIService {
    private static let model="@cf/zai-org/glm-4.7-flash"
    private static let visualModel="@cf/meta/llama-4-scout-17b-16e-instruct"
    @MainActor static func createPlan(
        evidence:[MangaStoryEvidence],frames:[UIImage],account:String,token:String
    ) async throws -> MangaStoryPlan {
        guard account.count==32,
              account.utf8.allSatisfy({("0123456789abcdefABCDEF").utf8.contains($0)}),
              !token.isEmpty else {throw MangaError.credentialsMissing}
        guard let url=URL(string:"https://api.cloudflare.com/client/v4/accounts/\(account)/ai/run/\(model)") else {
            throw MangaError.credentialsMissing
        }
        let prompt="""
        Produce a SINGLE COMPLETE Japanese manga STORY outline, not independent image descriptions.
        Time ordered evidence is JSON. Every row is ONE VIDEO SCENE with one or more user-inserted cards combined. Produce EXACTLY ONE manga panel per SCENE (row), in the exact same order. Multiple directions in combinedDirections MUST be BLENDED into that same panel, NEVER drawn as separate repeated panels.
        Invent reasonable connective thoughts, character motivations and dramatic actions when needed to make a coherent manga, but stay consistent with observed location, protagonists and video speech. This is an adaptation, not a documentary.
        Each scene's card or combination controls the story beat: introduce -> setup -> action -> reaction -> resolution. A reaction must answer the preceding event; a conclusion should pay off an earlier setup. If a scene combines DRAMATIC + HORROR, make the SAME image both dramatically cinematic AND visibly frightening (e.g. anxious faces, dramatic shadows), not two almost-identical portraits. Each panel must add new meaningful story information, avoid recycled pictures or captions.
        Prefer the user's written notes/dialogue and recognizable video events. Visual classifiers are uncertain English tags, not hard facts. Never invent quoted spoken words and claim they were heard.
        Draft cohesive character/place continuity across ALL panels. Captions and dialogue MUST be natural Japanese (not romaji, symbols or nonsense), short enough for a speech bubble. imagePrompt/scene/transition must be succinct descriptive ENGLISH for an image-generation model.
        Return ONLY a JSON object with these exact keys:
        {"title":"日本語タイトル","premise":"日本語で全体の物語を一文","panels":[{"index":1,"caption":"短い日本語ナレーション","dialogue":"自然な日本語の一言、または空文字列","scene":"English scene summary","imagePrompt":"English detailed new manga illustration with coherent characters, location, action, expression, composition","transition":"English causal connection from prior panel"}]}
        Do not omit any index. No markdown. Do not insert captions into imagePrompt.
        EVIDENCE:\n\(MangaStoryPlanner.evidenceJSON(evidence))
        """
        // Prefer understanding the actual scene sequence, not just five
        // isolated photo-classification tags. One scene contact sheet + one
        // multimodal STORY call replaces the plain text-only story request.
        // If unsupported, transparently fall back to the previous GLM path.
        if UserDefaults.standard.object(forKey:"pop.story.useVisualAI") as? Bool != false,
           frames.count==evidence.count,
           let sheet=MangaSceneContactSheet.jpeg(from:frames) {
            do {
                return try await makeVisualStory(
                    prompt:prompt, sheet:sheet, evidence:evidence,
                    account:account,token:token
                )
            } catch MangaVisualStoryError.quota {
                throw MangaError.server("Cloudflareの利用枠を確認してください。画像理解AIの呼出しで制限に達しました。")
            } catch {
                // Could be unsupported vision access or invalid structured
                // response; the lower-cost GLM script remains available.
            }
        }
        let body:[String:Any]=[
            "messages":[
                ["role":"system","content":"You are a professional Japanese manga writer and storyboard artist. Output valid JSON and coherent Japanese captions only."],
                ["role":"user","content":prompt]
            ],
            "temperature":0.5,
            "max_completion_tokens":3200,
            "stream":false
        ]
        var request=URLRequest(url:url)
        request.httpMethod="POST"
        request.timeoutInterval=90
        request.setValue("Bearer \(token)",forHTTPHeaderField:"Authorization")
        request.setValue("application/json",forHTTPHeaderField:"Content-Type")
        request.httpBody=try JSONSerialization.data(withJSONObject:body)
        let (data,response)=try await URLSession.shared.data(for:request)
        guard let http=response as? HTTPURLResponse else {throw MangaError.badResponse}
        let decoded=try? JSONDecoder().decode(MangaCloudflareStoryEnvelope.self,from:data)
        guard (200...299).contains(http.statusCode) else {
            let detail=decoded?.errors?.first?.message ?? "脚本生成APIを確認してください"
            throw MangaError.server("ストーリー作成に失敗：\(detail)（HTTP \(http.statusCode)）")
        }
        guard let raw=decoded?.result?.response, !raw.isEmpty else {throw MangaStoryError.invalidJSON}
        return try MangaStoryPlanner.decodeAIStory(raw,evidence:evidence)
    }

    /// Uses the documented Workers AI OpenAI-compatible chat endpoint with
    /// a data:image/jpeg URI. The generated story must still pass strict
    /// one-scene-per-row and Japanese lettering validation.
    private static func makeVisualStory(
        prompt:String,sheet:Data,evidence:[MangaStoryEvidence],
        account:String,token:String
    ) async throws -> MangaStoryPlan {
        guard let url=URL(string:"https://api.cloudflare.com/client/v4/accounts/\(account)/ai/v1/chat/completions") else {
            throw MangaVisualStoryError.unsupported
        }
        let imageURI="data:image/jpeg;base64,"+sheet.base64EncodedString()
        let body:[String:Any]=[
            "model":visualModel,
            "messages":[
                ["role":"system","content":"You are a professional manga writer. Study every numbered video scene in the contact sheet and output a causally coherent Japanese manga screenplay in strictly valid JSON."],
                ["role":"user","content":[
                    ["type":"text","text":prompt+"\nThe attached contact sheet shows each scene in numbered order. Base the setting and actions on what is actually visible. Do not invent observed facts."],
                    ["type":"image_url","image_url":["url":imageURI]]
                ]]
            ],
            "temperature":0.25,
            "max_tokens":3000,
            "stream":false
        ]
        var request=URLRequest(url:url)
        request.httpMethod="POST"
        request.timeoutInterval=90
        request.setValue("Bearer \(token)",forHTTPHeaderField:"Authorization")
        request.setValue("application/json",forHTTPHeaderField:"Content-Type")
        request.httpBody=try JSONSerialization.data(withJSONObject:body)
        let (data,response)=try await URLSession.shared.data(for:request)
        guard let http=response as? HTTPURLResponse else {throw MangaVisualStoryError.unsupported}
        if http.statusCode==429 || http.statusCode==402 {
            throw MangaVisualStoryError.quota
        }
        guard (200...299).contains(http.statusCode),
              let parsed=try? JSONDecoder().decode(MangaChatCompletion.self,from:data),
              let raw=parsed.choices.first?.message.content,!raw.isEmpty else {
            throw MangaVisualStoryError.unsupported
        }
        var visual=try MangaStoryPlanner.decodeAIStory(raw,evidence:evidence)
        visual.usedVisualEvidence=true
        return visual
    }
}

private final class SpeechCompletionGate {
    private let lock=NSLock()
    private var completed=false
    func finish(_ value:String,continuation:CheckedContinuation<String,Never>) {
        lock.lock()
        let first = !completed
        if first {completed=true}
        lock.unlock()
        if first {continuation.resume(returning:value)}
    }
}