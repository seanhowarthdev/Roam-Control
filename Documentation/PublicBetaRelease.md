# Roam Control 0.9.0 Public Beta — Build 29

Roam Control is an open-source SwiftUI app for testing an iPhone's reported location from a clean Apple Maps interface. It supports fixed locations, simulated walking routes, favourites, history and native on-device pairing through LocalDevVPN.

## Before installing

- Requires iOS 27 or newer.
- Requires Developer Mode and LocalDevVPN.
- This is an unsigned IPA. SideStore signs it with the user's own Apple account.
- Intended only for development, quality assurance and responsible testing on a device the user owns and controls.

Read the [installation guide](Installation.md), [privacy explanation](Privacy.md) and [responsible-use policy](ResponsibleUse.md) before using it.

## Download

Attach `RoamControl-0.9.0-build29.ipa` to this release.

SHA-256:

```text
87cee242c2bd96c935ea6a8dd52bd562696f3fe4e24e566509a3e26638b9593e
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
