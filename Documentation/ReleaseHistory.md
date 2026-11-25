# Roam Control Release History

This page records the public evolution of Roam Control at a user-facing level.

Public app distribution moved to the Apple App Store on 24 November 2026. Following its removal, independent distribution of Build 105 resumed on 25 November 2026. Earlier GitHub releases remain available for historical reference.

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

## 0.9.9 - Build 108

First official App Store release.

Released 24 November 2026.

- Approved by Apple on its first App Review submission.
- Originally distributed through the Apple App Store.
- No sideloading, IPA signing or periodic signing refreshes required.
- Removed from App Store availability on 25 November 2026 following re-evaluation. Migration is suspended.


## 0.9.9 - Build 105

Final public sideloaded release.

Released 20 October 2026.

- Added eight interface languages to English and Hebrew, bringing the total to ten plus System Default, with live switching, right-to-left layouts and Chinese script-aware language selection.
- Improved map controls, coordinate compatibility and route handling.
- Introduced custom Walking, Cycling and Driving speeds, with refined driving calculations, route estimates and live walking-speed display.
- Improved connection recovery flows, within iOS background-execution limitations.
- Refined language selection, recovery presentation and translated app messages.
- Continued support for existing fixed locations, routes, Joystick, backups, diagnostics and Stop & Restore.


## 0.9.7 - Build 96

Previous stable public release.

Released 8 October 2026.

- Improved background location-session connection reliability.
- Improved mobile-data operation with LocalDevVPN.
- Corrected native interface binding when LocalDevVPN and a Personal VPN operate simultaneously.
- No new user-facing features or pairing changes.

## 0.9.6 - Build 92

Previous stable public release.

Released 4 October 2026.

- Carries forward all user-facing changes introduced in 0.9.5.
- Improved backup restore and backup import compatibility in affected signing environments.
- Improved GPX import compatibility in affected signing environments.
- Reworked file importing around a copy-based document picker.
- Build timestamps are now generated automatically for each actual build.
- The GitHub release title retains `Build 92` so Roam Control 0.9.4 can recognise and offer the update.

## 0.9.5 - Build 91

Previous stable public release.

Released 3 October 2026.

- Major visual redesign across Roam Control.
- Added Driving and Cycling route modes.
- Added Joystick free movement.
- Added smoother simulated movement and improved map following.
- Added GPX route import and export.
- Added Miles/Kilometres route units and mph/km/h display.
- Added the dedicated 0.9.4 migration and backup/restore flow.
- Improved pairing readiness, expiry recovery and interrupted-session recovery.
- Redesigned Connection Health, Backup & Restore and Privacy Details.
- Added the anonymous country-level install count with updated privacy disclosure.
- Fixed future semantic-version update handling.

## 0.9.4 - Build 74

Historical stable release previously retained for migration.

Released 26 September 2026.

- Added Backup & Restore.
- Added freehand route drawing and redesigned walking-route controls.
- Added Mainland China coordinate compatibility.
- Improved walking, session recovery and Stop & Restore behaviour.
- Improved update checking and Personal VPN guidance.
- Added preparation for the one-time app migration planned for 0.9.5.
- Restored an immutable packaged build timestamp for SideStore installations.

## 0.9.3 - Build 63

Released 22 September 2026.

- Added manual route drawing and expanded walking-route planning.
- Added Manual Diagnostics with short support codes.
- Added automatic and manual update checking.
- Improved pairing-expiry handling, recovery and Connection Health.
- Improved timezone, restoration and active-session behaviour.

## 0.9.2 - Build 61

- Improved pairing reliability on SideStore-resigned installations.
- Continued stability work around fixed and walking location sessions.
- Improved recovery, diagnostics and connection guidance.
- Continued privacy-preserving optional usage statistics.
- Promoted from Preview to the main 0.9.2 release on 16 September 2026.

## 0.9.2 Preview builds

Builds 53 through 60 were development and preview releases used to improve pairing, background reliability, recovery, diagnostics, telemetry consent handling and SideStore compatibility.

These releases are retained in the GitHub release history for reference but are no longer offered as downloads.

## 0.9.1 - Build 47

Released 10 September 2026.

- Improved location restoration and interrupted-session recovery.
- Improved background reliability.
- Added Copy Diagnostics.
- Added update checking and richer issue-reporting support.
- Improved favourites and place-search behaviour.

## 0.9.0 Beta 1 - Build 29

Released 4 September 2026.

First public beta of Roam Control.

- Fixed reported locations.
- Walking routes with pace and route controls.
- Favourites and history.
- On-device pairing.
- Guided LocalDevVPN setup.
- Real-location restoration.
- Accessibility and appearance options.

Historical licensing terms for previously published source snapshots remain governed by the licence under which those snapshots were originally released.
