<p align="center">
  <img src="Documentation/Images/RoamControl-AppIcon-v2-source.png" width="128" height="128" alt="Roam Control app icon">
</p>

<h1 align="center">Roam Control</h1>

<p align="center">
  Choose, test and move an iPhone's reported location from one clean Apple Maps interface.
</p>

<p align="center">
  <strong>Current release:</strong> 0.9.9 Build 108 · <strong>Requires:</strong> iOS 27+
</p>

<p align="center">
  <img src="https://img.shields.io/badge/iOS-27%2B-blue" alt="iOS 27+">
  <img src="https://img.shields.io/badge/UI-SwiftUI-orange" alt="SwiftUI">
  <img src="https://img.shields.io/badge/Current-0.9.9-lightgrey" alt="Current release 0.9.9">
  <img src="https://img.shields.io/badge/License-Proprietary-lightgrey" alt="Proprietary">
</p>

<p align="center">
  <a href="https://apps.apple.com/app/roam-control/id6838265385">
    <img src="https://img.shields.io/badge/Download_on_the-App_Store-black?style=for-the-badge&logo=apple&logoColor=white" alt="Download on the App Store">
  </a>
</p>

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


## About

Roam Control is an iPhone app for location-based development, quality assurance and responsible personal testing on a device you own and control.

It supports fixed reported locations, Walking, Driving and Cycling routes, Joystick movement, GPX import/export, favourites, history, on-device pairing and guided LocalDevVPN-compatible sessions.

Roam Control is distributed exclusively through the Apple App Store. The application source code is not publicly distributed.

## Screenshots

<p align="center">
  <img src="Documentation/Images/README/roam-welcome.png" width="240" alt="Roam Control welcome screen">
  <img src="Documentation/Images/README/roam-fixed-location.png" width="240" alt="Selecting a fixed location in London">
  <img src="Documentation/Images/README/roam-walking-preview.png" width="240" alt="Walking route preview">
</p>

<p align="center">
  <sub>Welcome · Fixed location · Walking route</sub>
</p>

<p align="center">
  <img src="Documentation/Images/README/roam-manual-route.png" width="240" alt="Building a manual walking route">
  <img src="Documentation/Images/README/roam-connection-health.png" width="240" alt="Connection Health and Manual Diagnostics">
</p>

<p align="center">
  <sub>Manual route drawing · Connection Health</sub>
</p>

## Features

- Search for places, enter coordinates or select a position on the map.
- Start and update a fixed reported location.
- Simulate Apple Maps Walking, Driving and Cycling routes.
- Build manual routes with point-by-point or freehand drawing.
- Import and export GPX routes.
- Move freely with the Joystick without creating a route.
- Pause, resume, reverse or redirect active route sessions.
- Choose Miles/Kilometres and mph/km/h route units.
- Save favourites and revisit recent locations.
- Restore the iPhone's real location when testing is finished.
- Recover from interrupted fixed, route or Joystick sessions.
- Guided LocalDevVPN setup for Wi-Fi and mobile-data use.
- Light, dark and automatic appearance.
- Dynamic Type, VoiceOver and Reduce Motion support.
- Ten interface languages plus System Default, with live switching and right-to-left layouts.
- Custom Walking, Cycling and Driving speeds and improved route estimates.

## Latest Release Updates

**Roam Control 0.9.9 (Build 108)**

Released on the App Store on 24 November 2026.

- [Download Roam Control on the App Store](https://apps.apple.com/app/roam-control/id6838265385)
- [Current release information](Documentation/CurrentRelease.md)
- [Changelog](CHANGELOG.md)

## Install

[Download Roam Control on the App Store](https://apps.apple.com/app/roam-control/id6838265385)

Roam Control is free to download. SideStore, LiveContainer and IPA signing are no longer required for installation.

Only install Roam Control from the official App Store listing. Unofficial mirrors, modified builds and redistributed copies are not authorised.

LocalDevVPN and device pairing remain required for location simulation.

Existing sideloaded users must follow the backup and migration instructions above before installing the App Store version.

Read the [Installation Guide](Documentation/Installation.md) for full instructions.

## Documentation
- [Documentation index](Documentation/README.md)

- [Installation](Documentation/Installation.md)
- [Historical 0.9.5 Migration & SideStore FAQ](Documentation/Migration095.md)
- [User Guide](Documentation/UserGuide.md)
- [Using a Personal VPN](Documentation/PersonalVPN.md)
- [VPN Compatibility](Documentation/VPNCompatibility.md)
- [Advanced: Self-hosted IKEv2 on Linux](Documentation/SelfHostedIKEv2.md)
- [Current Release](Documentation/CurrentRelease.md)
- [Release History](Documentation/ReleaseHistory.md)
- [Download History](Documentation/DownloadHistory.md)
- [Privacy](Documentation/Privacy.md)
- [Responsible Use](Documentation/ResponsibleUse.md)
- [Security Policy](SECURITY.md)

## Privacy

Locations, searches, favourites, history, route content and pairing records remain on the iPhone.

Anonymous Usage Statistics are optional and off by default. Separately, Roam Control 0.9.5 and later sends one anonymous install-count request per installation to estimate aggregate country-level installs. See the [Privacy Policy](Documentation/Privacy.md) for the exact details.

## Responsible use

Roam Control is intended for development and testing on an iPhone you own and control.

Location simulation can affect every app that uses the iPhone's reported position. Restore the real location before using navigation, emergency, safety, transport or location-sharing features.

See [Responsible Use](Documentation/ResponsibleUse.md).

## Support and feedback

Bug reports, feature requests, testing results and technical findings are welcome through GitHub Issues.

Roam Control is maintainer-developed and is not accepting pull requests or unsolicited code contributions.

For casual help, beta discussion and feature ideas, join the Roam Control Discord:

https://discord.gg/fJrNvQ2Vdh

For security-sensitive reports, use GitHub Security Advisories.

## Releases

All current and future public app downloads are provided through the App Store.

[Download Roam Control on the App Store](https://apps.apple.com/app/roam-control/id6838265385)

GitHub releases are retained as historical records of Roam Control's development. Public IPA distribution has ended.

See [Download History](Documentation/DownloadHistory.md) for historical IPA download statistics.

## Licence and copyright

Roam Control is proprietary software.

Copyright © 2026 Sean Howarth. All rights reserved.

Official Roam Control releases may be downloaded and used personally subject to the terms in [LICENSE](LICENSE). Redistribution, modification, repackaging, mirroring and unofficial releases are not permitted without prior written permission.

Historical source code that was previously published under other licences remains governed by the licence applicable to the specific version when it was published. Those historical grants are not revoked by the current distribution model.
