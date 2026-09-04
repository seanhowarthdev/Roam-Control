# Installation

Roam Control is not distributed through the App Store or TestFlight. Public beta builds are supplied as unsigned IPA files for users to sign with their own Apple account.

## Requirements

- An iPhone running iOS 27 or newer.
- Developer Mode enabled under **Settings → Privacy & Security**.
- [LocalDevVPN](https://apps.apple.com/app/localdevvpn/id6755608044) installed on the iPhone.
- SideStore, or Xcode on a Mac with an Apple development team.

## Install with SideStore

1. Download the IPA attached to the matching GitHub Release. Do not download an IPA from an untrusted mirror.
2. In SideStore, tap **+** and choose the downloaded IPA.
3. Allow SideStore to sign and install Roam Control with your Apple account.
4. Open Roam Control and complete its introduction and device-pairing flow.
5. Open LocalDevVPN and enable its local tunnel before starting a location.

Free Apple accounts normally require sideloaded apps to be refreshed within seven days and limit the number of simultaneously active apps/App IDs. These are Apple signing limits, not Roam Control subscriptions.

When updating, install the newer IPA over the existing copy. Deleting the app first also deletes its local settings and may require pairing again.

## Build with Xcode

1. Clone the repository and open `RoamControl.xcodeproj`.
2. Select the Roam Control target and choose your own team under **Signing & Capabilities**.
3. Select a connected iPhone and press **Run**.

The tracked build configuration has no Apple team or TelemetryDeck destination. Xcode may save your selected team locally. Do not commit signing material or `Configuration/Local.private.xcconfig`.

The simulator can test the interface but cannot complete the physical iPhone pairing handshake or start a real location session.

## Verify a release

Each GitHub Release should publish the IPA's SHA-256 checksum. On a Mac, compare it with:

```sh
shasum -a 256 RoamControl-0.9.0-build29.ipa
```

For Build 29, the expected checksum is:

```text
af48336dd735286783b6d7269776ca95f5f34b97b81f9ed6a1f8679768220f37
```

See the [user guide](UserGuide.md) for pairing and everyday operation.
