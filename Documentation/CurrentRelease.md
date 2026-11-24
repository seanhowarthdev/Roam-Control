# Roam Control 0.9.9

Build 108, released on the App Store on 24 November 2026.

This is the first official App Store release of Roam Control. It carries forward the features of Build 105 with updated privacy wording for App Store distribution.

## Highlights

Roam Control 0.9.9 introduces ten interface languages, improved map and route handling, custom Walking/Cycling/Driving speeds, connection recovery refinements and interface improvements.

- **Languages:** English, Hebrew, Arabic, Simplified Chinese, Traditional Chinese, Japanese, Vietnamese, French, German and Spanish, plus System Default. Language changes apply immediately. Arabic and Hebrew support right-to-left layouts.
- **Maps and routes:** improved map controls, coordinate compatibility and handling of routes and route errors.
- **Custom movement speeds:** adjustable movement settings, refined driving behaviour and route estimates, and a live walking-speed display.
- **Connection recovery:** improved detection and recovery while iOS permits execution. Automatic restart cannot be guaranteed while the app is suspended or terminated.
- **Interface:** improved language picker, recovery presentation and localisation of app messages.

For detailed changes, see [CHANGELOG.md](../CHANGELOG.md).

## Before installing

- Requires iOS 27 or newer.
- Developer Mode remains required for device pairing.
- LocalDevVPN remains required for local pairing connectivity.
- SideStore, LiveContainer and IPA signing are no longer required.
- Intended for development, quality assurance and responsible personal testing on an iPhone you own or control.

> [!IMPORTANT]
> **Migrating from a sideloaded version? Back up first.**
>
> 1. Open your existing Roam Control installation.
> 2. Go to **Settings > Backup & Restore** and create a backup.
> 3. Save the backup outside Roam Control, such as in iCloud Drive, and verify that the file is accessible.
> 4. Confirm Roam Control is available in your App Store region.
> 5. Stop any active location simulation using **Stop & Restore**.
> 6. Delete the existing sideloaded Roam Control app. For LiveContainer, remove the Roam Control instance only.
> 7. [Download Roam Control on the App Store](https://apps.apple.com/app/roam-control/id6838265385).
> 8. Restore your backup and complete device pairing again.
>
> **Do not delete your existing installation before safely saving your backup.**
>
> Backups preserve favourites, history and supported preferences. Pairing information is not included.
>
> Backup & Restore is available from version 0.9.4 onwards. If you are using an earlier version, contact support before deleting it if you need to preserve your data.


## Download

[Download Roam Control on the App Store](https://apps.apple.com/app/roam-control/id6838265385)

See the [Installation Guide](Installation.md) for full instructions.

## Continuing features

Fixed locations, Walking/Driving/Cycling routes, manual routes, Joystick movement, GPX import/export, favourites, history, pairing, connection diagnostics and Stop & Restore remain available.

## Support and safety

Read [Installation](Installation.md), [Privacy](Privacy.md) and [Responsible Use](ResponsibleUse.md). Report bugs through GitHub Issues and security concerns through a private security advisory.

Location simulation can affect other apps. Restore the real location before using navigation, emergency, safety or location-sharing features.
