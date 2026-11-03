# Releasing ClipBar

`scripts/release.sh` turns the project into a notarized `ClipBar-<version>.dmg` that opens on any Mac running macOS 26 or later, on Apple Silicon or Intel. It does the following:

1. Builds a universal Release build with hardened runtime.
2. Signs it with Developer ID.
3. Runs `--selftest`.
4. Packs a DMG with an Applications shortcut and signs the DMG.
5. Notarizes it with Apple, staples the ticket, and checks it with Gatekeeper.

## One-time setup

You need a **paid Apple Developer Program** membership ($99/year). A free personal team cannot create Developer ID certificates.

1. **Developer ID certificate.** In Xcode, go to Settings → Accounts, select your team, and open Manage Certificates. Click **+** and choose **Developer ID Application**. Only the team's Account Holder can create it. Check that it is there:

   ```bash
   security find-identity -v -p codesigning
   ```

2. **App-specific password.** Create one at [account.apple.com](https://account.apple.com) under Sign-In and Security → App-Specific Passwords.

3. **Notary credentials in the keychain.** Run the command below in Terminal. It asks for the app-specific password and stores it in the keychain, so the script never sees it.

   ```bash
   xcrun notarytool store-credentials clipbar --apple-id YOUR_APPLE_ID --team-id 33K57T9459
   ```

4. **Team ID.** If the Developer ID certificate belongs to a different team, set `DEVELOPMENT_TEAM` in `project.yml` to that team.

## Every release

1. Bump `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `project.yml`.
2. Run:

   ```bash
   scripts/release.sh
   ```

3. The output is `build/release/ClipBar-<version>.dmg`. Attach it to a GitHub Release:

   ```bash
   gh release create v2.0 build/release/ClipBar-2.0.dmg --title "ClipBar 2.0" --notes "First public build"
   ```

To check the build, signature and DMG without notarizing (signed with Apple Development, works only on this Mac):

```bash
scripts/release.sh --local
```

## Notes

- Hardened runtime is on for every build. Contacts access needs the `com.apple.security.personal-information.addressbook` entitlement, which is already in `ClipBar.entitlements`.
- Paste into other apps posts ⌘V through CGEvent and needs the Accessibility permission. Testers grant it once in System Settings → Privacy & Security → Accessibility.
- Users who install the app for the first time get the usual "downloaded from the internet" prompt. That is expected for notarized apps.
- The Mac App Store is a separate path. It needs App Sandbox, which conflicts with CGEvent paste and opening arbitrary paths.
