# Roam Control 0.9.0 Public Beta — Build 29

Roam Control 0.9.0 Beta 1 is an open-source SwiftUI app for testing an iPhone's reported location from a clean Apple Maps interface. It supports fixed locations, simulated walking routes, favourites, history and native on-device pairing through LocalDevVPN.

## Before installing

- Requires iOS 27 or newer.
- Requires Developer Mode and LocalDevVPN.
- This is an unsigned IPA. SideStore signs it with the user's own Apple account.
- Intended only for development, quality assurance and responsible testing on a device the user owns and controls.

Read the [installation guide](Installation.md), [privacy explanation](Privacy.md) and [responsible-use policy](ResponsibleUse.md) before using it.

## Download

The original `RoamControl-0.9.0-build29.ipa` asset has been removed because this release has been superseded by v0.9.1. The Beta 1 source snapshot remains available under its original MIT Licence.

SHA-256:

```text
3ad8d5cb1151dabd8b4c29a065d46501095f07c74c8e92e45d845822dcfe1e7b
```

## Highlights

- Search for a place, enter coordinates or tap the map.
- Start and update a fixed reported location without restarting the connection.
- Preview and simulate Apple Maps walking routes.
- Pause, resume, reverse or redirect an active walk.
- Save favourites and revisit recent locations.
- Recover safely after an interrupted session.
- Choose light, dark or automatic appearance and multiple map styles.
- Optionally share a small, fixed set of anonymous usage counts; sharing is off by default.

## Known distribution constraints

SideStore and free Apple accounts are subject to Apple's app-count and seven-day refresh limits. Pairing and location sessions require a physical iPhone; the simulator supports interface testing only.

This beta is provided without warranty. Please report ordinary bugs with the issue template and security problems through a private GitHub security advisory.

## Licensing note

Roam Control 0.9.0 Beta 1 was released under the MIT Licence and remains available under those terms. Development after Beta 1 uses the licence stated in the repository's current `LICENSE` file.
