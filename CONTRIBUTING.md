# Contributing to Roam Control

Thanks for helping improve Roam Control. Contributions should preserve its narrow purpose: location-based development and testing on an iPhone the user owns and controls.

## Before opening a change

- Search existing issues before creating a duplicate.
- Discuss substantial features in an issue before investing in an implementation.
- Never include pairing records, PINs, certificates, Apple credentials, signing profiles, analytics destinations, exact private locations or diagnostic reports containing personal information.
- Keep optional statistics privacy-preserving, off by default and limited to the documented fixed event set.
- Do not add features intended to bypass access controls, evade enforcement, impersonate another person or misuse a third-party service.

## Development setup

1. Use macOS with Xcode 27 or newer and an iOS 27 SDK.
2. Open `RoamControl.xcodeproj`.
3. Choose your own signing team in Xcode. Do not commit it.
4. Use the simulator for interface work and a physical iPhone for pairing or location-session work.
5. Install and enable LocalDevVPN on the test iPhone.

The prebuilt `RoamPairingFFI.xcframework` allows normal app builds without compiling Rust. If the native bridge changes, follow `Documentation/BuildAndRelease.md` to rebuild both framework slices.

## Pull requests

- Keep each pull request focused.
- Explain the user-visible behaviour and privacy impact.
- Update documentation when a flow or setting changes.
- Complete the relevant rows in `Documentation/RegressionChecklist.md` on a physical iPhone.
- Confirm both Debug and Release configurations compile.
- Do not attach signing material, pairing files or a locally configured `Local.private.xcconfig`.

## Bug reports

Include the Roam Control version/build, iOS version, connection type and reproducible steps. Redact addresses, coordinates, pairing information, Apple IDs, device names and other personal details. Prefer the app's readable diagnostics report over raw internal files.
