# Roam Control Privacy

Roam Control is designed to keep sensitive location and pairing information on the iPhone.

## Information that stays on the iPhone

Roam Control does not send:

- Coordinates, selected places or addresses.
- Search text, favourites or location history.
- Walking routes, route progress or pace.
- Pairing records, pairing PINs or cryptographic material.
- Apple ID, device name or personal details.
- Connection diagnostics or support reports.

Pairing records are stored in the device-only Keychain. App preferences and saved places remain in local app storage.

## Optional anonymous usage statistics

The app offers **Share Anonymous Usage Statistics**. It is off by default. New users see the switch before finishing setup, and nothing is sent unless they affirmatively switch it on. Existing installations keep their previously saved choice when upgrading. The setting can be changed at any time under **Settings → Privacy**.

When sharing is enabled, the app may count:

- A participating installation opening the app or returning it to the foreground.
- Onboarding or pairing being completed.
- A fixed-location or walking session successfully starting.
- A location being updated during an active session.
- The app version and build associated with an event.
- An approximate event time added by TelemetryDeck.

These are activity signals only. They do not contain the location, route or other user content involved in an action.

## Installation counting

The app creates a random identifier for the installation in its local app storage. It sends an irreversible SHA-256 hash so participating installations can be counted approximately without using a name, Apple ID, advertising identifier or hardware identifier. No per-launch session identifier is sent.

Turning sharing off immediately prevents future events and deletes the locally stored identifier. Turning it on again creates a new identifier, so activity before and after the opt-out cannot be linked by Roam Control. Turning sharing off cannot withdraw anonymous events already received by TelemetryDeck. Those events do not contain a location or personal identity.

Statistics therefore describe participating installations, not every download or every person using Roam Control.

## Service and data minimisation

Roam Control sends its fixed event list directly to TelemetryDeck's Ingest API over HTTPS. It does not embed a third-party analytics SDK, which prevents an SDK from automatically adding device metadata. TelemetryDeck states that it does not store IP addresses. It also states that cold-storage event retention is roughly 7–10 years and that an exact deletion schedule is not guaranteed. Its privacy information is available at [telemetrydeck.com/docs/guides/privacy-faq](https://telemetrydeck.com/docs/guides/privacy-faq/).

If the release has no TelemetryDeck App ID and namespace configured, the statistics client sends nothing.

## Changes

Any future change to the information collected must be reflected in this document and in the in-app **What Is Shared** screen before release.
