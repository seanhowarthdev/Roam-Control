<p align="center">
  <img src="Design/RoamControl-AppIcon-v2-source.png" width="128" height="128" alt="Roam Control app icon">
</p>

<h1 align="center">Roam Control</h1>

<p align="center">
  Choose, test and move an iPhone's reported location from one clean Apple Maps interface.
</p>

<p align="center">
  <strong>Public beta:</strong> 0.9.0 (Build 29) · <strong>Requires:</strong> iOS 27+
</p>

Roam Control is an open-source SwiftUI app for location-based development, quality assurance and responsible personal testing on an iPhone you own and control. It supports fixed locations, walking routes, favourites, history, native on-device pairing and LocalDevVPN-compatible sessions.

## Screenshots

<p align="center">
  <img src="Documentation/Images/README/welcome.png" width="240" alt="Roam Control welcome screen">
  <img src="Documentation/Images/README/fixed-location.png" width="240" alt="Selecting a fixed location in London">
  <img src="Documentation/Images/README/walking-active.png" width="240" alt="Active simulated walking route">
</p>

<p align="center">
  <sub>Welcome · Fixed location · Walking route</sub>
</p>

<p align="center">
  <img src="Documentation/Images/README/privacy.png" width="240" alt="Privacy-first anonymous statistics choice">
  <img src="Documentation/Images/README/settings.png" width="240" alt="Roam Control settings">
</p>

<p align="center">
  <sub>Private by design · Settings</sub>
</p>

## Highlights

- Search places live with MapKit, enter coordinates or tap the map.
- Start a fixed reported location and update it without reconnecting.
- Preview an Apple Maps walking route before starting.
- Pause, resume, reverse or redirect an active walk.
- Save named favourites and revisit recent locations.
- Restore the real location explicitly when testing is finished.
- Recover safely after an interrupted fixed or walking session.
- Follow separate, guided LocalDevVPN flows for Wi-Fi and mobile data.
- Choose automatic, light or dark appearance and standard, satellite or hybrid maps.
- Use Dynamic Type, VoiceOver and Reduce Motion.

## Install the public beta

Roam Control is not distributed through the App Store or TestFlight. Download the IPA attached to the matching GitHub Release and sign it with SideStore using your own Apple account.

You will need:

- An iPhone running iOS 27 or newer.
- Developer Mode enabled.
- [LocalDevVPN](https://apps.apple.com/app/localdevvpn/id6755608044).
- SideStore, or Xcode on a Mac.

Read the complete [installation guide](Documentation/Installation.md) before installing. Free Apple accounts remain subject to Apple's app-count and seven-day refresh limits.

## First-time setup

1. Install and open Roam Control.
2. Complete the four-page introduction.
3. Tap **Pair This iPhone** on Device Setup.
4. Open **Settings → Privacy & Security → Developer Mode → Pair with Roam Control**.
5. Enter the six-digit code shown in Roam Control.
6. Install and connect LocalDevVPN.
7. Choose a location or walking route.

The pairing record is stored in the iPhone Keychain and is never uploaded.

## Privacy

Locations, coordinates, searches, favourites, history, walking routes and pairing records stay on the iPhone.

Anonymous usage statistics are optional and off by default. When enabled, a narrow first-party sender reports only a fixed set of activity events, the app version/build and a hashed random installation identifier. It never sends locations, searches, routes, pairing data, device names or diagnostics. No third-party analytics SDK is embedded.

The public project has no live analytics destination or Apple signing team. A checkout therefore sends no statistics unless the builder deliberately supplies a private local configuration.

Read [Privacy](Documentation/Privacy.md) for the exact event and retention disclosure.

## Responsible use

Roam Control is intended for development and testing on a device you own and control. Location simulation can affect every app using the iPhone's reported position. Restore the real location before using navigation, emergency, safety, transport or location-sharing features.

Do not use Roam Control to mislead another person, falsify evidence, access something you are not entitled to use, evade safeguards or breach a third-party service's rules. See [Responsible Use](Documentation/ResponsibleUse.md).

## Build from source

1. Clone the repository and open `RoamControl.xcodeproj` in Xcode 27 or newer.
2. Select the Roam Control target.
3. Choose your own Apple development team under **Signing & Capabilities**.
4. Select a connected iPhone and press **Run**.

The iPhone simulator is useful for interface work but cannot complete the physical pairing handshake or start a location session.

Normal builds use the included `Frameworks/RoamPairingFFI.xcframework`. The framework contains arm64 iPhone and Apple Silicon simulator slices. Rebuild it only after changing `Native/RoamPairingFFI`; instructions are in the [build and release guide](Documentation/BuildAndRelease.md).

## How it works

Roam Control generates or imports an RPPairing record for the same iPhone and stores it in the device-only Keychain. When a location starts, it discovers that iPhone's remote-pairing service through LocalDevVPN, verifies the device identity and opens the encrypted developer session used to set or clear a simulated location.

The native engine is a narrow Rust-to-Swift bridge around the MIT-licensed [`idevice`](https://github.com/jkcoxson/idevice) library, pinned to an exact revision. No Locus source is included or copied.

## Documentation

- [Installation](Documentation/Installation.md)
- [User guide](Documentation/UserGuide.md)
- [Privacy](Documentation/Privacy.md)
- [Responsible use](Documentation/ResponsibleUse.md)
- [Build and release guide](Documentation/BuildAndRelease.md)
- [Regression checklist](Documentation/RegressionChecklist.md)
- [Beta 1 release notes](Documentation/PublicBetaRelease.md)
- [Security policy](SECURITY.md)
- [Third-party notices](THIRD_PARTY_NOTICES.md)

## Contributing

Bug reports and focused improvements are welcome. Read [CONTRIBUTING.md](CONTRIBUTING.md) before opening an issue or pull request, and never upload pairing records, signing material, credentials or private location information.

## Licence

Roam Control's own source is available under the [MIT Licence](LICENSE). Bundled dependencies retain their own licences; see [Third-party notices](THIRD_PARTY_NOTICES.md).
