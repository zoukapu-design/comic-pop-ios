import Foundation
import Security

enum CloudflareCredentialVault {
    private static let service = "com.comicpop.cloudflare.personal"
    private static let account = "api_token"

    static func save(_ value:String) -> Bool {
        let query: [String:Any] = [kSecClass as String: kSecClassGenericPassword,
                                   kSecAttrService as String: service,kSecAttrAccount as String:account]
        SecItemDelete(query as CFDictionary)
        var add = query
        add[kSecValueData as String] = Data(value.utf8)
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        return SecItemAdd(add as CFDictionary,nil) == errSecSuccess
    }
    static func load() -> String? {
        let query: [String:Any] = [kSecClass as String:kSecClassGenericPassword,
           kSecAttrService as String:service,kSecAttrAccount as String:account,
           kSecReturnData as String:true,kSecMatchLimit as String:kSecMatchLimitOne]
        var result:CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary,&result)==errSecSuccess,
              let data=result as? Data else {return nil}
        return String(data:data,encoding:.utf8)
    }
    static func remove() {
        let query: [String:Any] = [kSecClass as String:kSecClassGenericPassword,
                                   kSecAttrService as String:service,kSecAttrAccount as String:account]
        SecItemDelete(query as CFDictionary)
    }
}
