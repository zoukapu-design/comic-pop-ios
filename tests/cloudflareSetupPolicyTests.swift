import Foundation

@main struct CloudflareSetupPolicyTests {
    static func main() {
        // Fresh install: show welcome first, then one optional setup.
        precondition(CloudflareSetupPolicy.shouldShowFirstRun(
            hasSeenWelcome:false,didFinishSetup:false,hasSavedCredentials:false))
        precondition(CloudflareSetupPolicy.shouldShowFirstRun(
            hasSeenWelcome:true,didFinishSetup:false,hasSavedCredentials:false))
        // A prior completed/declined setup never prompts again.
        precondition(!CloudflareSetupPolicy.shouldShowFirstRun(
            hasSeenWelcome:true,didFinishSetup:true,hasSavedCredentials:false))
        // Existing TestFlight users with Keychain credentials bypass setup,
        // even though the new completion flag did not exist in old versions.
        precondition(!CloudflareSetupPolicy.shouldShowFirstRun(
            hasSeenWelcome:true,didFinishSetup:false,hasSavedCredentials:true))
        precondition(!CloudflareSetupPolicy.shouldAskForToken(
            hasSavedToken:true,replacingToken:false))
        precondition(CloudflareSetupPolicy.shouldAskForToken(
            hasSavedToken:true,replacingToken:true))
        precondition(CloudflareSetupPolicy.shouldAskForToken(
            hasSavedToken:false,replacingToken:false))
        // The account and explicit user approval both matter to AI mode.
        precondition(!CloudflareSetupPolicy.mayGenerateWithAI(
            hasSavedToken:true,accountID:"",didConfirmWorkersFree:true))
        precondition(!CloudflareSetupPolicy.mayGenerateWithAI(
            hasSavedToken:true,accountID:"  ",didConfirmWorkersFree:true))
        precondition(!CloudflareSetupPolicy.mayGenerateWithAI(
            hasSavedToken:true,accountID:"abc",didConfirmWorkersFree:false))
        precondition(!CloudflareSetupPolicy.mayGenerateWithAI(
            hasSavedToken:false,accountID:"abc",didConfirmWorkersFree:true))
        let validAccount="0123456789abcdefABCDEF0123456789"
        precondition(CloudflareSetupPolicy.mayGenerateWithAI(
            hasSavedToken:true,accountID:validAccount,didConfirmWorkersFree:true))
        precondition(!CloudflareSetupPolicy.mayGenerateWithAI(
            hasSavedToken:true,accountID:"account-id",didConfirmWorkersFree:true))
        precondition(CloudflareSetupPolicy.resolvedAccountID(
            entered:" ",saved:validAccount)==validAccount)
        precondition(CloudflareSetupPolicy.resolvedAccountID(
            entered:"  abc ",saved:validAccount)=="abc")
        precondition(CloudflareSetupPolicy.isValidAccountID(validAccount))
        precondition(!CloudflareSetupPolicy.isValidAccountID("wrong-id"))
        precondition(CloudflareSetupPolicy.connectionHint(
            accountID:validAccount,confirmedFree:true)==nil)
        precondition(CloudflareSetupPolicy.connectionHint(
            accountID:"",confirmedFree:true)?.contains("Account ID")==true)
        precondition(CloudflareSetupPolicy.connectionHint(
            accountID:validAccount,confirmedFree:false)?.contains("Workers Free")==true)
        print("PASS: Cloudflare first-run onboarding, saved-token reuse, optional offline skip and AI readiness")
    }
}
