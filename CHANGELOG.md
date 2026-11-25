# Changelog

Public-facing changes to Roam Control are recorded here.

Detailed internal engineering notes are maintained privately.

See [Release History](Documentation/ReleaseHistory.md) and [Download History](Documentation/DownloadHistory.md) for additional release records.

## 0.9.9 - Build 108

Released 24 November 2026.

### App Store release

- First official Apple App Store release.
- Public IPA distribution temporarily retired on 24 November 2026. Build 105 distribution resumed on 25 November 2026.
- Build 108 was distributed without requiring SideStore, LiveContainer or IPA signing.
- LocalDevVPN and device pairing remain required.

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


## 0.9.9 - Build 105

Released 20 October 2026.

### Highlights

- **Ten interface languages:** English, Hebrew, Arabic, Simplified Chinese, Traditional Chinese, Japanese, Vietnamese, French, German and Spanish, plus System Default.
- **Improved maps and routes:** refined route handling, map interaction and coordinate compatibility.
- **Connection recovery:** improved detection and recovery of interrupted connections when the app is able to run; iOS background restrictions still apply.
- **Custom movement speeds:** configurable speeds for Walking, Cycling and Driving, with refined driving calculations, route estimates and walking-speed display.
- **Interface refinements:** clearer recovery presentation, a redesigned language picker and improved translated UI formatting.

### Languages and accessibility

- Added eight languages to English and Hebrew, with 831 localisable catalogue entries and six app-name/permission resources per new language.
- Added Arabic and Hebrew right-to-left layout handling, including isolation of technical text and pairing codes.
- Added immediate language switching without restarting the app, including correct distinction between Simplified and Traditional Chinese.
- Refined the language picker with English language titles, native-language subtitles and selection indicators.
- Improved plural formatting, translated notices, speed-label sizing and locale-sensitive display of values.
- Translations were tested automatically; feedback on language quality is welcome.

### Maps, movement and routing

- Improved coordinate compatibility and map controls.
- Refined route handling and clearer handling of route failures.
- Added custom movement-speed controls for Walking, Cycling and Driving.
- Refined driving targets and estimated times, and improved live walking-speed presentation.

### Connection and session recovery

- Improved automatic reconnection and recovery flows for interrupted connections and location sessions while iOS permits the app to execute.
- Refined recovery controls and guidance. These improvements do not guarantee automatic recovery when iOS suspends or terminates the app.
- Retained existing pairing, LocalDevVPN and real-location restoration workflows.

### Installation and migration

- Requires iOS 27 or newer, Developer Mode and LocalDevVPN for pairing connectivity. Originally distributed as an unsigned IPA for signing through SideStore or a compatible installation method.
- **Upgrading directly from 0.9.4 or earlier:** Back up favourites, history and supported preferences before moving to the newer `com.roamcontrol` app identifier. Data does not automatically transfer from the old app container; pairing records are not included in app backups and the device must be paired again.
- See [Installation](Documentation/Installation.md), [Migration FAQ](Documentation/Migration095.md) and [Current Release](Documentation/CurrentRelease.md).

### Original sideloaded distribution

- IPA: `RoamControl-0.9.9-Build105.ipa`
- SHA-256: `211f1057c70292da468226b39808d8777549c02923c14afc504d9e1d2daba86e`
- [GitHub release](https://github.com/seanhowarthdev/Roam-Control/releases/tag/v0.9.9)

## 0.9.7 - Build 96

Released 8 October 2026.

### Background and mobile-data reliability

- Improved native connection handling for LocalDevVPN.
- Corrected interface selection for device connections when a separate Personal VPN is also active.
- Improved reliability of location sessions during tested background and mobile-data scenarios.
- Verified fixed-location, Walking, Driving and Cycling behaviour, including LocalDevVPN reconnection.

This maintenance update does not introduce new features or change the pairing implementation.

## 0.9.6 - Build 92

Released 4 October 2026.

### File import compatibility

- Improved backup restore and backup import compatibility on some re-signed and paid-certificate installations.
- Improved GPX import compatibility in the same environments.
- Replaced the affected SwiftUI file-import paths with a copy-based document picker.
- This avoids cases where selecting a file could leave the Files picker open without returning the selected document to Roam Control.

### Build metadata

- Build date metadata is now generated automatically during every app build.
- New development or release builds no longer inherit an older manually stored build timestamp.

### Update compatibility

- The GitHub release title includes `Build 92` so the older Roam Control 0.9.4 updater can recognise 0.9.6 and show its update prompt.
- Roam Control 0.9.5 and later use semantic-version update detection.

All user-facing features introduced in 0.9.5 remain part of 0.9.6 and are documented below.

## 0.9.5 - Build 91

Released 3 October 2026.

> [!IMPORTANT]
> **Upgrading from Roam Control 0.9.4? Back up before installing 0.9.5.**
>
> Roam Control 0.9.5 uses a new app identifier, so your existing 0.9.4 app data will **not automatically carry across**.
>
> Before installing 0.9.5, open Roam Control 0.9.4 and create a backup from **Settings > Backup & Restore** if you want to preserve your favourites, history and supported settings.
>
> After installing 0.9.5, choose **Restore Backup** during the migration flow.
>
> Pairing information is not included in backups, so this iPhone will need to be paired again.
>
> **If you install 0.9.5 without creating a backup first, Roam Control cannot automatically recover those items from the old app.**


### A major new interface

- Roam Control has had a substantial visual redesign using the new glass-style interface throughout the app.
- The main map, search controls, location cards, connection/status controls, route planning, active movement sessions, mobile-data guidance, recovery screens, onboarding and pairing all received the new presentation.
- Settings has been reorganised into clearer grouped sections for Appearance, Units, Location Compatibility, Device, Privacy, Data, About, Updates, Feedback and Reset.
- Connection Health, Backup & Restore, Privacy Details and About Roam Control have all been substantially redesigned rather than simply restyled.
- Update notifications and the special 0.9.5 migration warning now use dedicated in-app glass panels instead of ordinary system alerts.
- About Roam Control now doubles as a much more comprehensive in-app guide to choosing locations, map controls, location sessions, routes, pairing, recovery and support.

### Walking, Driving and Cycling

- Route simulation is no longer walking-only. Roam Control now supports **Walking, Driving and Cycling** modes.
- Apple Maps routing uses the appropriate transport type for each mode.
- Route controls, status, progress, speed, remaining distance/time, pause/resume, Stop & Restore and route-back behaviour have been generalised across the new movement modes.
- Driving uses a new motion model with acceleration, cruising, deceleration, braking toward the destination, slower behaviour around manoeuvres and realistic pauses at selected route manoeuvres.
- Cycling uses route-aware automatic speed behaviour and slows for approaching manoeuvres.
- Manual and Freehand routes work with the selected movement mode, including bend detection so driving/cycling behaviour can react to manually created routes.
- Route-back actions adapt appropriately, including Walk Route Back, Drive Route Back and Ride Route Back.

### Joystick movement

- Added a completely new **Joystick** mode for free manual movement without creating a route.
- Open the joystick directly from the map and drag the control to move the simulated location in any direction.
- Movement speed responds progressively to joystick input rather than behaving as a simple on/off control.
- The joystick can begin from an already active simulated location or establish a new session.
- Manual joystick movement does not fill normal location history with every intermediate position.
- Joystick sessions participate in Stop & Restore and recovery handling.
- Speed is shown using the user's selected mph or km/h units.

### Smoother simulated movement and map following

- Route and joystick location writes now update around five times per second rather than the previous one-second route cadence.
- Map presentation interpolates those updates at roughly display-frame cadence, making the simulated marker visibly smoother.
- Added proper **follow simulated location** behaviour.
- Starting movement can automatically centre and follow the simulated position.
- Dragging the map temporarily breaks follow mode so the map can be explored manually.
- Pinch zooming can retain follow mode instead of immediately fighting the user's gesture.
- The location control can be used to resume following the simulated position.
- Existing zoom, heading and pitch are preserved where appropriate instead of constantly resetting the camera.
- Walking, driving, cycling and joystick sessions use sensible initial follow distances.
- Route framing and map padding have been reworked to leave better space around route endpoints and on-screen controls.

### GPX routes

- Added **GPX import**.
- GPX tracks and routes can be loaded directly into Roam Control and used with the selected movement mode.
- Imported coordinates are validated and cleaned before use.
- Multiple separate track segments are rejected rather than silently joining unrelated tracks.
- Added **GPX export** for prepared routes.
- Exported files use standard GPX 1.1 track data and can be saved/shared using the normal iOS document interface.
- Import/export failures now provide proper user-facing errors.

### Miles, kilometres and speed units

- Added a route-unit preference with **Miles** and **Kilometres**.
- The initial default follows the device's region.
- Imperial distance displays yards below 0.25 miles and miles above it.
- Metric distance displays metres below 1 km and kilometres above it.
- Speeds display in mph or km/h.
- Joystick speed respects this preference.
- Route-unit preference is included in Roam Control backups.

### The 0.9.5 migration

- Roam Control moves from the old `com.sean.roamcontrol` app identifier to **`com.roamcontrol`**.
- Because that identifier change prevents iOS from automatically carrying the old app container across, 0.9.5 has a dedicated migration flow.
- 0.9.4 users are warned to create a backup before moving to 0.9.5.
- The 0.9.5 first-run flow can restore an existing 0.9.4 backup or set up Roam Control as a new installation.
- Favourites, history and included app preferences can be restored.
- Pairing deliberately does not transfer in the backup, so the iPhone is paired again after migration.
- The migration flow makes the privacy/anonymous-statistics choice clear before pairing.
- The update prompt for this migration specifically offers Create Backup, Continue Without Backup and Not Now.

### Backup & Restore

- Backup & Restore has a substantially redesigned interface.
- It now makes the distinction between included and excluded information much clearer.
- Included data covers favourites, history and selected preferences.
- Pairing records, active/interrupted sessions and anonymous-statistics identity remain excluded.
- Backup restore validates the new route-unit preference as well as the existing stored preferences.
- Warnings around backups containing saved place names and coordinates are clearer.

### Pairing reliability and recovery

- Pairing now opens a new **Get Settings ready** sheet before starting the timed pairing session.
- It walks the user through opening Settings > Privacy & Security > Developer Mode and leaving that screen ready before the pairing timer begins.
- Failed pairing now provides a direct **Try Pairing Again** action.
- Pairing expiry handling is phase-aware instead of always returning a generic timeout message.
- Expiry while waiting for Settings, displaying the PIN, saving the pairing or preparing the session now gives appropriate recovery guidance.
- Pairing expiry is recorded explicitly as `pairingExpired`, improving diagnostics and telemetry.
- Pairing setup itself received the new UI treatment and clearer Replace Pairing File, Remove Pairing, Import Existing File and LocalDevVPN actions.

### LiveContainer

- LiveContainer installation is documented as a supported setup.
- The guide explains that **Fix Local Notifications** should be enabled for Roam Control before its first launch so pairing notifications return to the correct app instance.
- The documentation explains why LiveContainer pairing notifications may display sandbox/LiveContainer-style details while remaining functional.
- SideStore behaviour is unaffected.

### Session recovery

- Interrupted-session recovery has been generalised from walking routes to Walking, Driving and Cycling routes.
- Recovery remembers the route movement type and offers the correct Resume Walking, Resume Driving or Resume Cycling behaviour.
- Route recovery regenerates the remaining route from the last saved point.
- Joystick movement periodically saves its current reported position so a force-close still has a useful recovery point.
- Recovery wording and icons reflect the actual session type rather than assuming every route is a walk.

### Connection Health and diagnostics

- Connection Health has been extensively reorganised and redesigned.
- Pairing, LocalDevVPN and location-session state are presented more clearly.
- Added clearer restoration status and guidance explaining that other apps may briefly show a stale simulated location while iOS reacquires the real position.
- Current location and connection-check information have cleaner dedicated sections.
- The connection check remains non-destructive and does not start, change or stop a simulated location.
- Support and Share Diagnostics have clearer explanations.
- The diagnostics review explicitly shows what will and will not be shared before upload.
- Support codes and their retention information are presented more clearly.
- Personal VPN coexistence/conflict guidance has been moved into an explicit Other VPNs section.
- Pairing help and the LocalDevVPN App Store link are easier to reach.

### Privacy and anonymous statistics

- The Privacy Details screen has been comprehensively redesigned.
- Optional Anonymous Usage Statistics remain **off by default**.
- The app clearly lists the limited event information that can be shared and the categories that are never shared.
- Privacy wording now distinguishes normal anonymous usage statistics from the separate install-country counter.
- The privacy manifest has been updated accordingly.

### Anonymous install-country count

- Added a separate anonymous one-per-install country counter to understand Roam Control's geographic reach.
- This is independent of the optional Anonymous Usage Statistics toggle.
- The app sends a bodyless authenticated HTTPS request. It does not send an installation ID, coordinates, city, region, country, version, activity data or user content in that request body.
- The server derives only an approximate country from the connection IP.
- Raw IP addresses are not retained for this feature and the endpoint is excluded from Roam Control's normal web-server access log.
- Only aggregate country totals are stored.
- VPN/proxy users may be counted against their exit country.
- Failed reports retry on a later foreground activation.
- Once a report succeeds, that installation does not report again.
- Reset Roam Control preserves the successful-report flag, while reinstalling the app may count as another installation.

### Telemetry refinements

- Added separate anonymous session-start events for Driving and Cycling when Anonymous Usage Statistics are enabled.
- Known harmless sideload scheduler-registration noise is no longer promoted into anonymous failure/recovery telemetry.
- Recoverable telemetry deduplication is tracked independently by failure signature instead of only remembering the most recent recoverable failure.
- Scheduler/configuration status participates in that deduplication so genuinely different failures are not collapsed together.

### Release and update handling

- Fixed the update checker so current versions are compared primarily by semantic version and a public release no longer requires an internal build number.
- The internal build number is now optional release metadata instead of part of normal public version presentation.
- Release dismissal/identity now follows semantic version rather than the version/build pair.
- Restored the packaged build timestamp so About/diagnostics can report the precise build creation time.
- **For this release only**, the GitHub title includes `Build 91` so the older 0.9.4 updater can recognise 0.9.5 and show its update prompt.


## 0.9.4 - Build 74

Released 26 September 2026.

### Backup & Restore

- Added Backup & Restore in Settings.
- Backups include favourites, history, appearance, map style and location compatibility preferences.
- Pairing records, analytics consent and identity, active-session recovery state and diagnostics are deliberately excluded.
- Added migration preparation for Roam Control 0.9.5, including reminders to create a fresh backup before moving to the new app identifier.

### Walking routes and map controls

- Added freehand route drawing alongside point-by-point manual route creation.
- Added Points and Freehand route-drawing modes.
- Added one-finger freehand drawing with two-finger map pan, zoom and rotation.
- Added stroke-based Undo for freehand routes.
- Redesigned walking and route-planning controls into a more compact, responsive layout.
- Added collapsible location and Route Planning cards.
- Kept Pause, Resume and Stop & Restore readily accessible during active walking sessions.
- Added clearer Start and End route markers.
- Refined walking progress presentation and route-preview behaviour.
- Preserved normal map pin selection outside freehand drawing mode.

### Location compatibility

- Added automatic Mainland China coordinate correction for searched and selected locations.
- Added Off, Automatic and Force Correction location compatibility modes.
- Applied compatibility correction only to the final simulated device location so the map marker remains at the location the user selected.
- Kept manually entered coordinates unchanged by automatic correction.
- Improved location compatibility and correction handling around fixed and walking sessions.

### Sessions and restoration

- Refined Stop & Restore behaviour and messaging.
- Improved guidance while iOS reacquires the real device location after simulation ends.
- Improved active-session and recovery presentation without changing the underlying location-session workflow.

### Updates and VPN guidance

- Stable update checks now ignore GitHub draft and prerelease releases.
- Updated Connection Health guidance to reflect tested coexistence with compatible Personal VPNs.
- Clarified that VPN apps using the Device VPN connection can conflict with LocalDevVPN.
- Improved troubleshooting guidance for temporarily pausing another VPN while keeping LocalDevVPN enabled.

### Release and packaging

- Restored an immutable packaged build timestamp so SideStore re-signing does not change the displayed build date and time.
- Added release-package validation to reduce the risk of publishing a stale or incorrectly configured build.

## 0.9.3 - Build 63

### New

- Added manual route drawing for locations where Apple walking directions are unavailable.
- Added support for planning routes from an active simulated location.
- Added support for intermediate waypoints while keeping an existing selected destination fixed as the route endpoint.
- Added Manual Diagnostics in Connection Health, allowing users to submit a privacy-conscious troubleshooting snapshot and receive a short support code.
- Added automatic and manual release update checking.

### Pairing and recovery

- Added a pairing-expiry notification so users are alerted when the six-digit pairing flow has taken too long and needs to be restarted.
- Improved guidance when pairing expires or does not complete successfully.
- Added clearer recovery actions when pairing or reconnecting fails.
- Improved pairing status and failure information in Connection Health.

### Location, timezone and session behaviour

- Improved timezone handling during location simulation.
- Improved timezone restoration when simulation ends and the device returns to its real location.
- Improved Stop & Restore messaging so it is clearer when Roam Control has stopped simulation and iOS is reacquiring the real location.
- Replaced older user-facing “spoofing” terminology with clearer “location simulation” wording.
- Refined restoration and background-session status messaging.
- Clarified guidance for continuing an active location session over mobile data.

### Route planning and map behaviour

- Improved route planning while a simulated-location session is already active.
- Refined route preview, manual route drawing and map framing.
- Improved map recenter behaviour so it follows the relevant real or simulated location for the current session.
- Refined floating map-control placement across route-planning, route-preview and manual-drawing states.

### Known issue

- A region-specific location-selection issue can still cause searched or selected locations to appear several hundred metres away from the intended position in some configurations. Investigation is ongoing.

### Diagnostics and updates

- Expanded Connection Health with clearer pairing, session, scheduler and location-write information.
- Improved troubleshooting information for failed location writes and ended device sessions.
- Improved update notifications so dismissing one build does not prevent a newer release from being surfaced later.
- Refined the “New version available” experience and manual update checking.

### General

- Refined wording and recovery guidance across pairing, Connection Health, route planning and session restoration.

## 0.9.2 - Build 61

Promoted to the main public release on 16 September 2026.

### Improved

- Improved pairing reliability on SideStore-resigned installations.
- Improved fixed and walking-session stability.
- Improved interrupted-session recovery.
- Improved connection guidance and diagnostics.
- Continued privacy-preserving optional usage statistics.

## 0.9.1 - Build 47

Released 10 September 2026.

### Improved

- Clearer Stop & Restore behaviour.
- Improved interrupted-session recovery.
- Improved background-session reliability.
- Richer place-search results.
- Reorderable favourites.

### Added

- Copy Diagnostics.
- GitHub bug and feature-request links.
- Manual update checking.
- Privacy-preserving failure telemetry.

## 0.9.0 Beta 1 - Build 29

Released 4 September 2026.

First public beta.

### Added

- Fixed reported locations.
- Map and coordinate selection.
- Walking-route simulation.
- Favourites and history.
- On-device pairing.
- Guided LocalDevVPN setup.
- Interrupted-session recovery.
- Explicit real-location restoration.
- Accessibility and appearance options.
- Optional anonymous usage statistics.
