# Changelog

All notable public changes to Roam Control are recorded here.

## [Unreleased]

## [0.9.1] - 2026-09-10

First beta polish release, corresponding to app version 0.9.1 Build 47.

### Improved

- Made location restoration clearer: confirmation, visible restoration progress and a clean return to the ready state.
- Improved interrupted-session recovery and removed unnecessary resume controls after a successful stop and restore.
- Kept active location sessions reliable in the background while allowing the Dynamic Island presentation to stay compact.
- Restored richer, faster place-search results, including useful address detail.
- Added drag-to-reorder for favourites while keeping history in chronological order.
- Made the selected map location reliably recenter when returning to it.

### Added

- Added **Copy Diagnostics** under Settings → Connection Health. The copied report deliberately excludes locations, searches, pairing records, PINs, device names and error text.
- Added Settings links for GitHub bug reports and feature requests, plus structured GitHub issue forms.
- Added a manual **Check for Updates** control in Settings that checks only the public GitHub release.
- Added privacy-preserving telemetry for handled pairing, preparation, restoration, start and LocalDevVPN failures.

## [0.9.0-beta.1] - 2026-09-04

First public beta, corresponding to app version 0.9.0 Build 29.

### Added

- Fixed reported locations selected by search, coordinates or map pin.
- Live MapKit search, favourites, history and renamed saved places.
- Walking-route preview, pace control, pause/resume, reverse and redirect.
- Native on-device pairing with secure Keychain storage.
- Guided LocalDevVPN flows for Wi-Fi and mobile data.
- Interrupted-session recovery and explicit real-location restoration.
- Light, dark and automatic appearance; map styles; Dynamic Type, VoiceOver and Reduce Motion support.
- Optional, off-by-default anonymous usage statistics with an in-app disclosure and Apple privacy manifest.

### Privacy and release hardening

- Removed per-launch analytics session identifiers.
- Preserved existing consent choices while defaulting new installations to sharing off.
- Prevented failed location updates from being counted as successful.
- Moved the release analytics destination and Apple development-team identifier out of tracked project settings.

[Unreleased]: https://github.com/seanhowarthdev/Roam-Control/compare/v0.9.1...HEAD
[0.9.1]: https://github.com/seanhowarthdev/Roam-Control/compare/v0.9.0-beta.1...v0.9.1
[0.9.0-beta.1]: https://github.com/seanhowarthdev/Roam-Control/releases/tag/v0.9.0-beta.1
