# Roam Control 0.9.5 Migration & SideStore FAQ

This page documents the app-identity migration introduced in Roam Control 0.9.5. The same migration considerations apply when upgrading from 0.9.4 to Build 105. Do not remove an existing installation without first creating and verifying a backup. Build 105 is now available again.

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


For current distribution status and guidance for existing installations, see the [Installation Guide](Installation.md).

Roam Control 0.9.5 includes a one-time app-identity migration for users upgrading from 0.9.4.

Roam Control 0.9.4 used the app identifier `com.sean.roamcontrol`. Roam Control 0.9.5 and later use the permanent identifier `com.roamcontrol`.

Because these are different app identifiers, Apple signing and SideStore treat them as separate app identities.

## Why do I see two Roam Control App IDs?

During the migration you may temporarily see both:

- `com.sean.roamcontrol` - Roam Control 0.9.4
- `com.roamcontrol` - Roam Control 0.9.5 and later

This is expected.

The change to `com.roamcontrol` is a one-time migration. Future Roam Control updates will continue using the same identifier and will not create a new Roam Control App ID for each release.

## Does 0.9.5 use another active app slot?

If standalone copies of both Roam Control 0.9.4 and 0.9.5 are installed at the same time, they are separate apps and can each occupy an active app slot.

For free Apple Accounts, SideStore currently documents two separate limits:

- Up to 3 active sideloaded apps at one time, including SideStore itself.
- Up to 10 App IDs registered within a 7-day period.

These are Apple signing limits, not Roam Control subscriptions or limits imposed by Roam Control.

See the [SideStore FAQ](https://docs.sidestore.io/docs/faq) for SideStore's current description of these limits.

## What should I do if I do not have a free active app slot?

Before removing Roam Control 0.9.4:

1. Open Roam Control 0.9.4.
2. Go to **Settings > Backup & Restore**.
3. Create a backup and make sure you have kept the exported backup safely.
4. Remove the old 0.9.4 app if you need to free an active app slot.
5. Install Roam Control 0.9.5.
6. Choose **Restore Backup** during the migration flow.
7. Pair the iPhone again.

Removing the old app can free its active app slot, but its old App ID may remain visible temporarily until that App ID expires.

## Why is the old App ID still there after removing 0.9.4?

SideStore does not allow App IDs to be manually deleted.

If the old app has been removed, its App ID will expire rather than being renewed. SideStore shows App ID expiry information in its app/App ID management interface.

See the [SideStore error documentation](https://docs.sidestore.io/docs/troubleshooting/error-codes) for the current App ID rules.

## Does the old App ID disappear immediately?

No.

Removing Roam Control 0.9.4 can free the active app slot, but the old registered App ID has its own expiry period. It may therefore remain visible for a while after the app itself has been removed.

This is separate from the active-app limit.

## What does the Roam Control backup restore?

The 0.9.4 backup can carry supported Roam Control data into 0.9.5, including favourites, history and supported preferences.

Pairing information is deliberately not included in Roam Control backups.

After restoring the backup in 0.9.5, the iPhone must therefore be paired again.

## Should I delete 0.9.4 before installing 0.9.5?

If you have a free active app slot, the safest approach is to create the 0.9.4 backup first and keep the old installation until you have successfully installed 0.9.5 and restored the backup.

If you do not have a free active app slot, create and safely keep the backup first, then remove 0.9.4 before installing 0.9.5.

Do not remove 0.9.4 before creating the backup if you need its favourites, history or supported settings.

## I already installed 0.9.5 without creating a backup. What can I do?

If Roam Control 0.9.4 is still installed and its data is still intact, open 0.9.4 and create a backup before removing it. You can then restore that backup into 0.9.5.

If the old 0.9.4 app and its data have already been removed and no backup was created, Roam Control 0.9.5 cannot automatically recover that old app-container data.

## Why was the identifier changed?

Roam Control 0.9.5 moved to the permanent `com.roamcontrol` identifier.

The migration cost is therefore limited to the transition from 0.9.4 to 0.9.5. Normal future updates using `com.roamcontrol` should install as updates to the same Roam Control app identity rather than creating another Roam Control App ID.

## Is this going to happen again with 0.9.6 or 1.0?

No identifier change is planned for normal future Roam Control releases.

Roam Control 0.9.5 and later use `com.roamcontrol` as the app identifier, so ordinary future updates will retain the same app identity.

For the normal installation process, see the [Installation Guide](Installation.md).
