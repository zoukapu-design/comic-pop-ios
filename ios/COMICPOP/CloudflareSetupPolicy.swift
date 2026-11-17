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

    /// A token saved in Keychain is not sufficient without its Account ID and
    /// an explicit user confirmation of the Workers Free contract.
    static func mayGenerateWithAI(
        hasSavedToken:Bool,
        accountID:String,
        didConfirmWorkersFree:Bool
    ) -> Bool {
        hasSavedToken &&
        !accountID.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty &&
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
