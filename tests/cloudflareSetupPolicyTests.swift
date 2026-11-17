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
        precondition(CloudflareSetupPolicy.mayGenerateWithAI(
            hasSavedToken:true,accountID:"account-id",didConfirmWorkersFree:true))
        print("PASS: Cloudflare first-run onboarding, saved-token reuse, optional offline skip and AI readiness")
    }
}
