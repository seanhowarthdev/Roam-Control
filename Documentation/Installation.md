# Installation

Roam Control 0.9.9 (Build 105) is available for independent sideloading.

[Download Roam Control 0.9.9 (Build 105)](https://github.com/seanhowarthdev/Roam-Control/releases/tag/v0.9.9)

> [!IMPORTANT]
> **Distribution update - 25 November 2026**
>
> Roam Control was released on the App Store on 24 November 2026. Following a subsequent re-evaluation by Apple, App Store and TestFlight availability have been disabled.
>
> The previously released Roam Control 0.9.9 (Build 105) IPA is available again for independent sideloading through [GitHub Releases](https://github.com/seanhowarthdev/Roam-Control/releases/tag/v0.9.9). This is an existing release, not a new update.
>
> Apple has been contacted and clarification is pending.
>
> **Do not unnecessarily delete or uninstall your existing Roam Control installation.** Migration to the App Store remains suspended. Build 105 is available for independent sideloading.
>
> Existing users are encouraged to create a backup through **Settings > Backup & Restore**, where supported, and save it safely outside the app.
>
> Roam Control has not been discontinued. Further updates regarding availability will be published here.

## Requirements

- An iPhone running iOS 27 or newer.
- Developer Mode enabled under **Settings → Privacy & Security**.
- [LocalDevVPN](https://apps.apple.com/app/localdevvpn/id6755608044) installed on the iPhone.
- SideStore for a standalone install, or LiveContainer for a contained install.

## Existing installations

Keep your existing working installation, including App Store installations.

Do not attempt to downgrade Build 108 to Build 105 over an existing installation. Migration to the App Store remains suspended.

Where supported, create a backup through **Settings > Backup & Restore**, save it outside the app and verify that it is accessible.

## Install with SideStore

1. Download the Build 105 IPA from the [official GitHub Release](https://github.com/seanhowarthdev/Roam-Control/releases/tag/v0.9.9). Do not download an IPA from an untrusted mirror.
2. In SideStore, tap **+** and choose the downloaded IPA.
3. Allow SideStore to sign and install Roam Control with your Apple account.
4. Open Roam Control and complete its introduction and device-pairing flow.
5. Open LocalDevVPN and enable its local tunnel before starting a location.

With a free Apple Account, SideStore documents two separate signing limits: up to 3 active apps at one time, including SideStore, and up to 10 App IDs registered within a 7-day period. These are Apple signing limits, not Roam Control subscriptions.

For ordinary updates that keep the same app identifier, install the newer IPA over the existing copy rather than deleting the app first.

**Roam Control 0.9.5 is a one-time exception for users coming from 0.9.4.** Version 0.9.5 uses the new `com.roamcontrol` app identifier, so existing 0.9.4 app data does not automatically carry across. Before installing 0.9.5, create a backup in **Settings > Backup & Restore** if you want to preserve favourites, history and supported settings. Restore that backup during the 0.9.5 migration flow. Pairing must be completed again.

For questions about the old and new App IDs, active app slots, App ID expiry and restoring 0.9.4 data, see the [0.9.5 Migration & SideStore FAQ](Migration095.md).


## Install with LiveContainer

Roam Control can also run through LiveContainer.

1. Download the Build 105 IPA from the [official GitHub Release](https://github.com/seanhowarthdev/Roam-Control/releases/tag/v0.9.9).
2. Import Roam Control into LiveContainer.
3. **Before launching Roam Control for the first time**, enable LiveContainer's local-notification compatibility option for that Roam Control instance:

   **LiveContainer → Apps → long-press Roam Control → App Settings → Fix Local Notifications → On**

4. Launch Roam Control and continue through first-time setup and pairing normally.
5. Open LocalDevVPN and enable its local tunnel before starting a location.

With **Fix Local Notifications** enabled, the pairing notification is delivered through LiveContainer. Tapping it returns to the correct Roam Control instance so pairing can continue normally.

Because LiveContainer relays the notification, it may show LiveContainer, sandbox or container-style details rather than looking exactly like a notification from a standalone Roam Control install. This is specific to the LiveContainer environment. SideStore installs are unaffected.

## Verify a release

The restored Build 105 IPA has been verified against the original archived release. On a Mac, calculate the checksum of the IPA you downloaded:

```sh
shasum -a 256 RoamControl-0.9.9-Build105.ipa
```

The expected SHA-256 checksum is:

```text
211f1057c70292da468226b39808d8777549c02923c14afc504d9e1d2daba86e
```

Verify that the checksum matches before installing.

See the [user guide](UserGuide.md) for pairing and everyday operation.
