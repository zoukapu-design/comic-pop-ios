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

/// A single, whole-story text request BEFORE individual image generation.
/// This is the user's own Workers AI account, under the same free-tier consent.
enum MangaStoryAIService {
    private static let model="@cf/zai-org/glm-4.7-flash"
    private static let visualModel="@cf/meta/llama-4-scout-17b-16e-instruct"
    @MainActor static func createPlan(
        evidence:[MangaStoryEvidence],frames:[UIImage],
        video:URL,duration:Double,account:String,token:String
    ) async throws -> MangaStoryPlan {
        guard account.count==32,
              account.utf8.allSatisfy({("0123456789abcdefABCDEF").utf8.contains($0)}),
              !token.isEmpty else {throw MangaError.credentialsMissing}
        guard let url=URL(string:"https://api.cloudflare.com/client/v4/accounts/\(account)/ai/run/\(model)") else {
            throw MangaError.credentialsMissing
        }
        let prompt="""
        Produce a SINGLE COMPLETE Japanese manga STORY outline, not independent image descriptions.
        The visual contact sheet (if present) shows THREE frames per story scene, one row per scene: BEFORE | CARD MOMENT | AFTER. Analyze actual action changes, not merely still-image labels. Keep the scene order unchanged.
        Time ordered evidence is JSON. Every row is ONE VIDEO SCENE with one or more user-inserted cards combined. Produce EXACTLY ONE manga panel per SCENE (row), in the exact same order. Multiple directions in combinedDirections MUST be BLENDED into that same panel, NEVER drawn as separate repeated panels.
        Invent reasonable connective thoughts, character motivations and dramatic actions when needed to make a coherent manga, but stay consistent with observed location, protagonists and video speech. This is an adaptation, not a documentary.
        EVIDENCE now contains each scene's storyFunction, storyDuty, evidenceRestrictions, connectionToPrevious, suggestedShot, and cardIDs. These are concrete storytelling constraints, not decorative card labels. Follow the selected role, but do NOT invent unsupported outcomes just to force a four-act plot from a short video. A reaction must answer the preceding event; a payoff must resolve an earlier setup; openEnding means the result was not visible. If scene combines DRAMATIC + HORROR, create ONE dramatically frightening event with a meaningful cause and consequence, not two pictures. In every panel show a NEW action, reveal, response or result. Change camera distance only when it clarifies that event. Never repeat a static portrait as a new scene.
        Respect evidenceRestrictions as binding user card constraints: exact/noextra prohibit unrelated invented events or extra characters, quote prohibits made-up quotations, must guarantees inclusion. Prefer the user's written notes/dialogue and recognizable video events. Visual classifiers are uncertain English tags, not hard facts. Never invent quoted spoken words and claim they were heard.
        Draft coherent identity and setting across ALL panels. In each panel, plotDescriptionJP must say precisely what the character DOES or what CHANGES, not just an atmosphere like 'dramatic' or 'scary'. causalLinkJP must explain in natural Japanese the observable or clearly marked speculative connection from the prior scene; for index 1 it must be empty. Do not put characters' unconfirmed thoughts into quotation marks and claim those words were recorded. caption and dialogue must be short, meaningful natural Japanese; avoid generic narrator text and gibberish. scene/imagePrompt/transition must be concise English image directives that identify visual change and action, NOT copy an identical reference shot. Use a different useful composition when action changes. Keep any unobserved details clearly framed as adaptation.
        Return ONLY a JSON object with these exact keys:
        {"title":"日本語タイトル","premise":"日本語で全体の物語を一文","panels":[{"index":1,"caption":"短い日本語ナレーション","dialogue":"自然な日本語の一言、または空文字列","plotDescriptionJP":"このコマで起きる出来事を具体的に日本語で一文","causalLinkJP":"前のコマからの因果のつながりを日本語で一文、1コマ目は空文字列","scene":"English scene summary","imagePrompt":"English detailed new manga illustration with coherent characters, location, action, expression, composition","transition":"English causal connection from prior panel"}]}
        Do not omit any index. No markdown. Do not insert captions into imagePrompt.
        EVIDENCE:\n\(MangaStoryPlanner.evidenceJSON(evidence))
        """
        // Prefer understanding the actual scene sequence, not just five
        // isolated photo-classification tags. One scene contact sheet + one
        // multimodal STORY call replaces the plain text-only story request.
        // If unsupported, transparently fall back to the previous GLM path.
        if UserDefaults.standard.object(forKey:"pop.story.useVisualAI") as? Bool != false,
           frames.count==evidence.count {
            // Read motion around the pin time. The text-only fallback avoids
            // any extra video analysis if the user disables visual AI.
            var triples:[[UIImage]]=[]
            for index in evidence.indices {
                let now=evidence[index].seconds
                let low=max(0,(index>0 ? evidence[index-1].seconds+0.2 : 0))
                let high=max(now,min(duration-0.15,
                    index+1<evidence.count ? evidence[index+1].seconds-0.2 : duration-0.15))
                let beforeTime=max(low,now-2)
                let afterTime=min(high,now+2)
                let before:UIImage
                let after:UIImage
                if beforeTime < now-0.15 {
                    before=(try? await VideoFrameService.frame(
                        at:beforeTime,from:video)) ?? frames[index]
                } else {
                    before=frames[index]
                }
                if afterTime > now+0.15 {
                    after=(try? await VideoFrameService.frame(
                        at:afterTime,from:video)) ?? frames[index]
                } else {
                    after=frames[index]
                }
                triples.append([before,frames[index],after])
            }
            if let sheet=MangaSceneContactSheet.motionJPEG(from:triples) {
                do {
                    return try await makeVisualStory(
                        prompt:prompt, sheet:sheet, evidence:evidence,
                        account:account,token:token
                    )
                } catch MangaVisualStoryError.quota {
                    throw MangaError.server("Cloudflareの利用枠を確認してください。画像理解AIの呼出しで制限に達しました。")
                } catch MangaVisualStoryError.credentials {
                    throw MangaError.server("Cloudflareの認証・Workers AIの権限を確認してください。認証エラー時は追加のAI呼出しを行いません。")
                } catch MangaVisualStoryError.unsupported {
                    // A truly unsupported model/endpoint may use the prior
                    // text-only screenplay path. This is NOT an image retry.
                } catch MangaVisualStoryError.invalidResponse {
                    throw MangaError.server("画像AIの脚本データが不完全です。追加のAI呼出しは停止しました。画風選択画面で画像理解をOFFにすれば、文字情報だけで再試行できます。")
                } catch {
                    // A network timeout or transient server failure might
                    // already have consumed the first request's free quota.
                    // Never silently start a second model inference.
                    throw MangaError.server("画像AIの解析に失敗しました。無料枠保護のため追加呼出しを停止しました。画像理解をOFFにすれば文字情報だけで再試行できます。")
                }
            }
        }
        // The whole chapter must be returned as one JSON document.
        // A fixed 3000-token cap can truncate later panels of a 12-scene manga.
        // This is an upper bound, NOT a requirement to consume the tokens.
        let outputBudget=min(6400,max(3000,evidence.count*450+1000))
        let body:[String:Any]=[
            "messages":[
                ["role":"system","content":"You are a professional Japanese manga writer and storyboard artist. Output valid JSON and coherent Japanese captions only."],
                ["role":"user","content":prompt]
            ],
            "temperature":0.5,
            "max_completion_tokens":outputBudget,
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
        guard (200...299).contains(http.statusCode) else {
            let detail=CloudflareStoryResponse.errorMessage(from:data)
                ?? "脚本生成APIの利用枠・権限・モデルを確認してください"
            throw MangaError.server("ストーリー作成に失敗：\(detail)（HTTP \(http.statusCode)）")
        }
        guard let raw=CloudflareStoryResponse.text(from:data),!raw.isEmpty else {
            throw MangaStoryError.invalidJSON
        }
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
        let outputBudget=min(6400,max(3000,evidence.count*450+1000))
        // A contact-sheet row represents one user-selected scene and its motion.
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
            "max_tokens":outputBudget,
            "stream":false
        ]
        var request=URLRequest(url:url)
        request.httpMethod="POST"
        request.timeoutInterval=90
        request.setValue("Bearer \(token)",forHTTPHeaderField:"Authorization")
        request.setValue("application/json",forHTTPHeaderField:"Content-Type")
        request.httpBody=try JSONSerialization.data(withJSONObject:body)
        let (data,response)=try await URLSession.shared.data(for:request)
        guard let http=response as? HTTPURLResponse else {
            throw MangaVisualStoryError.serverFailure
        }
        if let failure=MangaVisualStoryRetryPolicy.failure(
            forHTTPStatus:http.statusCode
        ) {
            throw failure
        }
        guard let raw=CloudflareStoryResponse.text(from:data),!raw.isEmpty else {
            throw MangaVisualStoryError.invalidResponse
        }
        do {
            var visual=try MangaStoryPlanner.decodeAIStory(raw,evidence:evidence)
            visual.usedVisualEvidence=true
            return visual
        } catch {
            // JSON may be syntactically valid but omit or duplicate scenes.
            // This is NOT an unsupported endpoint; do not spend more quota
            // by launching GLM automatically after a consumed image request.
            throw MangaVisualStoryError.invalidResponse
        }
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