# Roam Control releases

## 0.9.0 (Build 29)

- Created: 4 September 2026 at 15:36 BST
- Package: `RoamControl-0.9.0-build29.ipa`
- Configuration: optimized Release, stripped arm64 iPhone executable
- Minimum system: iOS 27.0
- Xcode: 27.0 beta (`27A5252f`)
- Distribution: unsigned IPA for SideStore re-signing
- SHA-256: `af48336dd735286783b6d7269776ca95f5f34b97b81f9ed6a1f8679768220f37`
- Change: hardens anonymous statistics for public beta. New installs now start with sharing off, saved choices are preserved, app foreground activity is counted without a per-launch session ID, participation is confirmed only after successful delivery, and failed location updates are not counted. The privacy disclosure now includes approximate event time and retention, the app contains an Apple privacy manifest, and the live TelemetryDeck destination is held outside the public project configuration.

## 0.9.0 (Build 28)

- Created: 4 September 2026 at 14:48 BST
- Package: `RoamControl-0.9.0-build28.ipa`
- Configuration: optimized Release, stripped arm64 iPhone executable
- Minimum system: iOS 27.0
- Xcode: 27.0 beta (`27A5252f`)
- Distribution: unsigned IPA for SideStore re-signing
- SHA-256: `21205149bf4b54df54de5387c97f78957c50fc6e0e6f0933b856a1778494d535`
- Change: adds clearly disclosed optional anonymous usage statistics. New users see the enabled switch before setup completes; existing installations remain disabled until explicitly enabled. The direct TelemetryDeck client sends only fixed activity events, app version/build and a hashed random installation identifier—never locations, searches, routes, saved places, pairing material, personal details or diagnostics.

## 0.9.0 (Build 27)

- Created: 4 September 2026 at 13:25 BST
- Package: `RoamControl-0.9.0-build27.ipa`
- Configuration: optimized Release, arm64 iPhone
- Minimum system: iOS 27.0
- Xcode: 27.0 beta (`27A5252f`)
- Distribution: unsigned IPA for SideStore re-signing
- SHA-256: `44c7b69f280edaca58d77dd41b927bfca7003870cf85433d76ce5f7a94eada32`
- Change: permits both the Xcode bundle identifier and SideStore's team-suffixed bundle identifier for pairing and location background tasks. The build timestamp is now embedded so it remains accurate after SideStore re-signs the app.

## 0.9.0 (Build 26)

- Created: 4 September 2026 at 13:18 BST
- Package: `RoamControl-0.9.0-build26.ipa`
- Configuration: optimized Release, arm64 iPhone
- Minimum system: iOS 27.0
- Xcode: 27.0 beta (`27A5252f`)
- Distribution: unsigned IPA for SideStore re-signing
- SHA-256: `925a8a5cb62e8729a668880d76b6f1ea9327a4536f9260980cadd00d82389f57`
- Change: background-task identifiers now follow the installed IPA's permitted identifiers, allowing pairing and location sessions after SideStore renames and re-signs the app.

## 0.9.0 (Build 25)

- Created: 4 September 2026 at 13:01 BST
- Package: `RoamControl-0.9.0-build25.ipa`
- Configuration: optimized Release, arm64 iPhone
- Minimum system: iOS 27.0
- Xcode: 27.0 beta (`27A5252f`)
- Distribution: unsigned IPA for SideStore re-signing
- SHA-256: `3ef4b5808ea462bf7058232f99d4da157594aebcde7c2217f200d618ef985042`

The IPA passed ZIP integrity and payload-layout checks. Complete the device regression checklist after installing it through SideStore because SideStore's signing identity differs from an Xcode-installed build.
