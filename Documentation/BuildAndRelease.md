# Build and Release Guide

This guide covers Roam Control's development builds and the planned IPA workflow.

## Current release identity

- Marketing version: `0.9.0`
- Current build: `29`
- Bundle identifier: `com.sean.roamcontrol`
- Minimum deployment target: iOS 27
- Supported device family: iPhone

The version and build are shown in **Settings** inside the app. The built date and time come from the timestamp embedded for that packaged build.

## Version and build rules

Roam Control uses two separate numbers:

- The **version** describes the public release. Development stays on `0.9.0` until the first stable release, which will become `1.0.0`.
- The **build** identifies one exact install. Increase it once for every build installed on a test iPhone or packaged as an IPA.

Ordinary compile checks do not consume a build number. Build numbers must never move backwards for a later install or upload.

Both values are stored in the target build settings:

- `MARKETING_VERSION`
- `CURRENT_PROJECT_VERSION`

Keep the Debug and Release configurations identical.

## Build in Xcode

1. Open `RoamControl.xcodeproj`.
2. Select the **RoamControl** scheme.
3. Select the connected iPhone.
4. Open **Signing & Capabilities** and confirm the development team.
5. Press **Run**.

The simulator can validate most interface states, but it cannot perform the real RPPairing handshake or start a location session.

## Native pairing engine

The prebuilt `Frameworks/RoamPairingFFI.xcframework` should be committed with both arm64 iPhone and arm64 Apple Silicon simulator slices.

Only rebuild it after changing `Native/RoamPairingFFI`. The rebuild requires Rust targets for:

- `aarch64-apple-ios`
- `aarch64-apple-ios-sim`

Run `scripts/build-pairing-engine.sh` from the project directory. Confirm the app still builds for both a physical iPhone and the simulator afterwards.

## Archive preparation

Before creating an archive:

1. Finish the regression checklist.
2. Increase `CURRENT_PROJECT_VERSION` for the archive.
3. Confirm the public version.
4. Use the Release configuration.
5. Confirm the app icon and display name.
6. Set and verify the build timestamp.
7. For a public build, set the TelemetryDeck App ID and namespace and confirm no secret token is present.
8. Confirm `RoamPairingFFI.xcframework` is embedded and signed.
9. Build once for a physical iPhone.

Then select **Any iOS Device (arm64)** and choose **Product → Archive**. Xcode opens Organizer after a successful archive.

## IPA and SideStore

Roam Control's SideStore IPA is built from an optimized, unsigned Release archive. SideStore applies the user's personal development certificate during installation. The native pairing engine is statically linked into the app binary, so it does not need a separate framework or extension.

For personal SideStore installation:

1. Use the verified IPA from `Releases`, or create a new one from a Release archive.
2. Move the IPA to Files or another location SideStore can access.
3. Open SideStore, choose the IPA and allow SideStore to sign/install it with the configured Apple ID.
4. Keep Developer Mode enabled.
5. Complete Roam Control's pairing on the installed copy if its signing identity gives it a new Keychain container.

SideStore re-signing and Apple's free-account limits can affect expiry, app identifiers and available entitlements. The final IPA must therefore be tested as a SideStore install rather than assuming an Xcode-installed build is equivalent. With a free Apple Account, SideStore normally refreshes the signed installation within Apple's seven-day development period.

Do not treat an Xcode Debug `.app` folder renamed to `.ipa` as a release package. Use the verified Release archive/package workflow.

## Privacy statistics configuration

Optional statistics are sent directly to TelemetryDeck's Ingest API. Roam Control does not embed its SDK and permits only the event names and app/build values defined in `UsageAnalyticsService.swift`.

Two build settings configure a public release:

- `ROAMCONTROL_TELEMETRY_APP_ID`
- `ROAMCONTROL_TELEMETRY_NAMESPACE`

These are ingestion identifiers, not an account password or API token. They are blank in the tracked `Configuration/Local.xcconfig`. Copy `Configuration/Local.private.xcconfig.example` to the ignored `Configuration/Local.private.xcconfig` and set both values only for a configured local or release build. The same private file can hold the local `DEVELOPMENT_TEAM`. Without both TelemetryDeck values, the client sends nothing. Keeping the live destination and signing identity outside the public project prevents forks from accidentally adding data to Roam Control's dashboard or inheriting the repository owner's Apple team.

Before packaging a configured build, inspect the event structure, confirm the privacy disclosure still matches it, and run the privacy rows in the regression checklist. Never add coordinates, place text, searches, saved locations, routes, pairing material, device names, user-supplied text or diagnostic content to an event.

## Release records

For each distributed build, record:

- Version and build number.
- Date and time created.
- Xcode and iOS versions used.
- Signing method.
- Device used for testing.
- Regression checklist result.
- Known issues.

This makes a problem report traceable to the exact binary shown in Roam Control's Settings screen.
