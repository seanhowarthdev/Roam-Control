# Changelog

All notable public changes to Roam Control are recorded here.

## [Unreleased]

0.9.2 Beta 3, corresponding to app version 0.9.2 Build 53.

### Fixed

- Build 53: guard submission before scheduling and cancel obsolete completions; keep pairing busy during secure storage and guard its completion; report terminal failure once per attempt, including teardown after cancellation.

- Build 53: retain fixed scheduler rejection reasons in pairing/session telemetry and copied diagnostics; reject late pairing launch callbacks and clean up cancelled pre-worker requests.
- Build 53: bound the native stop-simulation response wait, propagate clear errors through cancellation, and distinguish stop acknowledgement from unverified real-location reacquisition. Rebuilt both native slices.
- Build 53: retain local session failure stage/disposition, correct premature real-location-restored wording, and add cautious other-VPN comparison guidance without detection or sensitive network telemetry.

- Separated recoverable scheduler/tunnel interruptions into Connection.RecoveryNeeded, reserving Failure.Observed for terminal operation failures. Added a fixed disposition field so corrected data can be filtered separately from historical observations. Included in Build 52; earlier IPAs are unchanged.

- Added one bounded automatic discovery retry after enabling LocalDevVPN before showing manual connection help; foreground wait and cancellation are bounded. Owner-device automatic recovery verified on Build 53; affected-user verification remains open.

- Prevented cancelled discovery and connection-check timers from failing a replacement attempt.
- Fixed a pairing-session lifetime race when cancelling near native completion.
- Ignored obsolete or cancelled background-task submission failures.
- Suppressed repeated identical failure notifications during worker teardown to avoid duplicate failure counts.

### Improved

- Connection Health now verifies TCP reachability of the matched pairing service, and explains that secure session verification happens during session startup.
- Added fixed failure-stage and operation categories to optional telemetry, including recoverable native startup failures and background-task submission failures.
- Added connection-help, manual retry and successful-after-retry events to show recoverable connection friction.
- Updated the anonymous-statistics disclosure and user guide. No locations, searches, pairing records, credentials, PINs, device names or raw error text are transmitted.
- Removed macOS metadata files from test IPA packaging after an installation signature-verification failure; metadata was a suspected contributor, not a confirmed root cause.

### Validation and remaining work

- Debug/Release builds, native restoration tests, classification checks and IPA verification passed.
- Owner-device Build 53 testing passed repeated pairing cancellation and subsequent pairing, Wi-Fi automatic recovery, 5G startup/guidance, and quick stop/restore on both networks. Recoverable scheduler classification matched the active session diagnostics.
- First pairing attempt timed out; suspected manual-step delay is unconfirmed. Immediate retry succeeded.
- The Build 52 restoration delay was not reproduced. Affected-user pairing/session reports and other-VPN interference remain open; no universal fix is claimed.
- Walking-session foreground/background continuity and Stop & Restore also passed owner-device smoke testing on Build 53.

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
