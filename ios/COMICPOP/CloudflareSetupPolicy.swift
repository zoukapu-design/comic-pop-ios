import Foundation

/// Pure first-run/account readiness rules, shared by the actual SwiftUI app
/// and Linux unit tests. The user may always choose offline mode instead.
enum CloudflareSetupPolicy {
    static func shouldShowFirstRun(
        hasSeenWelcome:Bool,
        didFinishSetup:Bool,
        hasSavedCredentials:Bool
    ) -> Bool {
        !hasSeenWelcome || (!didFinishSetup && !hasSavedCredentials)
    }

    /// Prefer a saved Account ID when this field was not re-entered.
    static func resolvedAccountID(entered:String,saved:String)->String {
        let typed=entered.trimmingCharacters(in:.whitespacesAndNewlines)
        return typed.isEmpty ? saved.trimmingCharacters(in:.whitespacesAndNewlines) : typed
    }
    static func isValidAccountID(_ input:String)->Bool {
        let id=input.trimmingCharacters(in:.whitespacesAndNewlines)
        return id.utf8.count==32 &&
            id.utf8.allSatisfy { "0123456789abcdefABCDEF".utf8.contains($0) }
    }
    /// Explain why a disabled connection button cannot be tapped.
    static func connectionHint(accountID:String,confirmedFree:Bool)->String? {
        if !isValidAccountID(accountID) {
            return accountID.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty
                ? "CloudflareのAccount ID（32桁）が未登録です。トークンの再入力は不要です。"
                : "Account IDは32桁の16進数（0–9、a–f）で入力してください。"
        }
        if !confirmedFree {
            return "利用前にWorkers Free契約を確認し、チェックをオンにしてください。"
        }
        return nil
    }

    /// A token saved in Keychain is not sufficient without its Account ID and
    /// an explicit user confirmation of the Workers Free contract.
    static func mayGenerateWithAI(
        hasSavedToken:Bool,
        accountID:String,
        didConfirmWorkersFree:Bool
    ) -> Bool {
        hasSavedToken &&
        isValidAccountID(accountID) &&
        didConfirmWorkersFree
    }

    /// Token text is requested only on a genuinely new or replacement setup.
    static func shouldAskForToken(
        hasSavedToken:Bool,
        replacingToken:Bool
    ) -> Bool {
        !hasSavedToken || replacingToken
    }
}
