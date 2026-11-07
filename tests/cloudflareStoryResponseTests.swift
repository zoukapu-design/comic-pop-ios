import Foundation

@main struct CloudflareStoryResponseTests {
    static func main() throws {
        func json(_ object:[String:Any]) throws -> Data {
            try JSONSerialization.data(withJSONObject:object)
        }
        let story="{\"title\":\"そば作り\",\"panels\":[]}"
        let modern=try json(["choices":[
            ["message":["role":"assistant","content":story]]
        ]])
        precondition(CloudflareStoryResponse.text(from:modern)==story,
                     "GLM documented choices[] must be decoded")
        let wrapped=try json(["result":["choices":[
            ["message":["content":story]]
        ]],"success":true])
        precondition(CloudflareStoryResponse.text(from:wrapped)==story,
                     "Some Workers AI APIs wrap choices in result")
        let legacy=try json(["success":true,"result":["response":story]])
        precondition(CloudflareStoryResponse.text(from:legacy)==story,
                     "The older REST response must stay compatible")
        let structured=try json(["choices":[["message":["content":[
            ["type":"text","text":"漫画の"],
            ["type":"text","text":"脚本"]
        ]]]]])
        precondition(CloudflareStoryResponse.text(from:structured)=="漫画の\n脚本",
                     "Newer content arrays should join text segments")
        let error=try json(["errors":[["code":4006,"message":"limit reached"]],"success":false])
        precondition(CloudflareStoryResponse.errorMessage(from:error)=="limit reached")
        precondition(CloudflareStoryResponse.text(from:error)==nil,
                     "Failed Cloudflare responses cannot masquerade as stories")
        precondition(CloudflareStoryResponse.text(from:Data("not JSON".utf8))==nil)
        precondition(CloudflareStoryResponse.text(from:try json(["result":[:]]))==nil)
        print("PASS: Workers AI choices[], wrapped choices[], legacy response, Japanese content and error parsing")
    }
}
