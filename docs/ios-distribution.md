# iOS build and distribution

## Current preparation

Recall has an iOS target with bundle ID `io.github.peter7004.recall`, minimum
iOS 15.0, and version/build values from `pubspec.yaml`. The ID must be registered
in your Apple developer account before distribution; it is not registered yet.
The shared Flutter dictionary, local storage, backups, and flashcards are unchanged.
Android APK releases and the public web app remain independent.

Windows cannot build native iOS applications locally. You do not need to install
an iOS SDK on this PC or own a Mac for the hosted validation workflow: GitHub
provides macOS and Xcode. A Mac with Xcode remains useful for interactive native
debugging and direct device testing.

## Run cloud validation

1. Open the public [Recall2 Actions page](https://github.com/Peter7004/Recall2/actions/workflows/build-ios.yml).
2. Choose **Validate iOS build**, then **Run workflow** on `main`.
3. After success, open the run and download its `Recall-iOS-validation` artifact.

The manual workflow uses the standard `macos-15` runner, Xcode 26.3, and Flutter
3.47.6. It runs analysis and tests, creates an unsigned release `.xcarchive`,
verifies its identity/version/permissions/logo and SDK, then builds and launches
a debug app on an available iPhone Simulator. Reports and a home-screen screenshot
are uploaded alongside a checksummed archive ZIP. Artifacts expire after 14 days;
rerun the workflow to create another. No Apple account or signing secrets are used.
Standard hosted runners are free for this public repository under GitHub's current
policy; private-repository usage and larger runners have different billing rules.

**This artifact is not an installable iPhone app.** `--no-codesign` deliberately
skips IPA export. Renaming the ZIP to `.ipa` will not make it installable. Simulator
launch validation is not App Store validation and does not cover physical-device
camera/gallery, file import/export, upgrades, or all interactive workflows.

## When ready for TestFlight

1. Enroll in the [Apple Developer Program](https://developer.apple.com/programs/) using your own Apple Account. The standard membership is USD 99 per year or the local equivalent; Apple handles enrollment and payment.
2. Register the explicit bundle ID `io.github.peter7004.recall` and create the iOS app record in [App Store Connect](https://appstoreconnect.apple.com/). If this ID is unavailable, change it before the first distributed build, then keep it stable.
3. Prepare your Apple Team ID, an Apple Distribution certificate with its private key, and an App Store provisioning profile for that ID. An App Store Connect API key can support cloud upload. Keep these in private repository secrets, never the public source, artifacts, or logs. The Android signing key cannot sign an iOS app.
4. Configure and verify a signed macOS build/export/upload workflow in the private distribution repository. Build with `flutter build ipa` and your signing/export settings, then upload the signed IPA to App Store Connect. The current public workflow intentionally cannot do this.
5. Complete export-compliance, app privacy, beta metadata, and any required review. Replace the native Flutter placeholder launcher icon with approved Recall artwork before distribution. The existing branded in-app startup screen is separate from the launcher icon. Inspect plugin privacy manifests and test camera, gallery, CSV/JSON files, data persistence, and backup restore on a real iPhone.
6. Add TestFlight testers after Apple's processing/review. Each new upload needs a higher build number. Keep the bundle ID and application record stable for updates; do not uninstall an app containing unbacked-up words.

Enrollment, signing credentials, actual IPA export, Apple processing, and
TestFlight/App Store publication are not completed by the unsigned workflow.
No login backend or database is required merely to distribute the app on iOS.

## References

- [Flutter iOS deployment](https://docs.flutter.dev/deployment/ios)
- [Apple build uploads](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/)
- [GitHub hosted runners](https://docs.github.com/en/actions/reference/runners/github-hosted-runners)
- [macOS 15 ARM64 image and installed Xcode versions](https://github.com/actions/runner-images/blob/main/images/macos/macos-15-arm64-Readme.md)
