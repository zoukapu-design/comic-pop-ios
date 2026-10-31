# COMIC POP! TestFlight setup

The Apple App ID and App Store Connect app record are already created.

The signed build uses Codemagic-managed Code Signing Identities (as of Oct 31, 2026), not manually copied certificate/API secrets.

- Add an App Store Connect API key (role: App Manager) to **Personal Account > Integrations > Developer Portal**. Do not commit or share the .p8 file.
- Manage an Apple Distribution certificate under Code signing identities > iOS certificates. Use reference name `comicpop_distribution`. Prefer reusing an existing certificate if appropriate.
- Create and upload/fetch an App Store provisioning profile for the exact Bundle ID and matching certificate. Use reference name `comicpop_appstore_profile`.
- Codemagic app Environment variables: group `ios_config`, variable `BUNDLE_ID` equal to the actually registered identifier.
- Build workflow `ios-signed-ipa` on main. This creates signed IPA artifacts but does not publish.
- Enable TestFlight publishing only after the signed IPA passes.

The unsigned simulator workflow remains unchanged.

See [Japanese guide](TESTFLIGHT_SETUP_JA.md). Official docs: https://docs.codemagic.io/yaml-code-signing/signing-ios/
