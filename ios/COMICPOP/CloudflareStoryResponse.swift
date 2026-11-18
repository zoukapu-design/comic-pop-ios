import Foundation

/// Cloudflare Workers AI text results may use the documented OpenAI-compatible
/// choices[] response or the legacy REST result.response envelope.
/// Keep this parser platform-neutral so real API fixtures can be tested without
/// constructing an iOS view or using any API credits.
enum CloudflareStoryResponse {
    static func text(from data:Data) -> String? {
        guard let root=try? JSONSerialization.jsonObject(with:data) as? [String:Any] else {
            return nil
        }
        let bodies:[ [String:Any] ] = [
            root["result"] as? [String:Any],
            root
        ].compactMap{$0}
        for body in bodies {
            if let choices=body["choices"] as? [[String:Any]] {
                for choice in choices {
                    guard let msg=choice["message"] as? [String:Any] else {continue}
                    if let output=readText(msg["content"]), !output.isEmpty {
                        return output
                    }
                }
            }
            if let legacy=readText(body["response"]),!legacy.isEmpty {return legacy}
        }
        return nil
    }

    static func errorMessage(from data:Data)->String? {
        guard let root=try? JSONSerialization.jsonObject(with:data) as? [String:Any],
              let errors=root["errors"] as? [[String:Any]] else {return nil}
        return errors.compactMap{$0["message"] as? String}.first
    }

    private static func readText(_ value:Any?) -> String? {
        if let text=value as? String {
            return text.trimmingCharacters(in:.whitespacesAndNewlines)
        }
        if let chunks=value as? [[String:Any]] {
            let lines=chunks.compactMap { part -> String? in
                if let value=part["text"] as? String {return value}
                return nil
            }
            let result=lines.joined(separator:"\n")
            return result.isEmpty ? nil : result
        }
        return nil
    }
}
