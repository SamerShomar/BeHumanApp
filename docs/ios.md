# Putting the app on an iPhone

## The one requirement that has no way around it

**A Mac.** Apple only allows an iOS app to be compiled and signed on macOS with
Xcode. This is Apple's restriction, not the project's — there is no Windows or
Linux path, and no setting that changes it.

If there is no Mac available, the two real options are:

- **A rented Mac in the cloud** — MacinCloud or MacStadium, roughly $20–30 a
  month, used through remote desktop.
- **A build service** — Codemagic has a free tier for Flutter and builds iOS
  without you touching a Mac at all. It still needs an Apple account for
  signing.

## Which Apple account

| | Free Apple ID | Apple Developer Program ($99/year) |
| --- | --- | --- |
| Install on your own iPhone | yes | yes |
| **App stops working after** | **7 days** | 1 year |
| Devices at once | 3 | 100 |
| Send to the team remotely (TestFlight) | no | yes |
| Needs the phone plugged into the Mac | every 7 days | first time only |

For trying it yourself, free is enough. For the Gaza and Netherlands teams to
actually use it, the $99 program is the only workable answer — re-plugging
everyone's phone into a Mac every week is not a plan.

## Before Xcode: the file the app cannot start without

The iOS app is not registered with Firebase yet, and without its config file
the app **crashes the instant it opens** — Firebase cannot start.

1. Open `console.firebase.google.com` → project **be-human-5023e**
2. ⚙ **Project settings** → under *Your apps*, **Add app** → **iOS**
3. Bundle ID — type it exactly, it must match the Xcode project:

   ```
   com.behuman.beHumanApp
   ```

   (Note it differs from the Android one, `com.behuman.behuman_app`. That is
   fine — they are two separate apps under one project. What matters is that
   this string matches character for character, capital letters included.)
4. Download **`GoogleService-Info.plist`**
5. Put it at:

   ```
   ios/Runner/GoogleService-Info.plist
   ```

   It has to be added *through Xcode* so the file is included in the build:
   open `ios/Runner.xcworkspace`, drag the file onto the `Runner` folder in
   the left sidebar, and make sure **"Copy items if needed"** and the
   **Runner** target are both ticked. Dropping it in the folder with Finder
   alone is the most common reason the app still crashes afterwards.

## Building it

From the project folder on the Mac:

```bash
flutter pub get
cd ios && pod install && cd ..
open ios/Runner.xcworkspace
```

In Xcode:

1. Select **Runner** in the sidebar → the **Runner** target → **Signing &
   Capabilities**
2. Tick **Automatically manage signing**
3. **Team** — pick your Apple ID (add it under Xcode → Settings → Accounts if
   it is not listed)
4. If it complains the bundle ID is taken, change it to something unique —
   `com.<yourname>.behuman` — **and register that same string in Firebase in
   step 3 above**, then download the plist again
5. Plug the iPhone in, unlock it, trust the computer, and pick it from the
   device menu at the top
6. Press ▶

The first launch on the phone will refuse with "Untrusted Developer". On the
iPhone: **Settings → General → VPN & Device Management** → your Apple ID →
**Trust**.

## Notifications on iOS

Everything so far gets the app running. Notifications need three more things,
and **all of them require the paid $99 program** — Apple does not issue push
certificates to free accounts.

1. **Turn the capability on.** Xcode → **Signing & Capabilities** →
   **+ Capability** → **Push Notifications**. This also creates the
   entitlements file and wires it up, which is why it is not done by hand here.
2. **Create an APNs key.** `developer.apple.com` → Certificates, Identifiers &
   Profiles → **Keys** → **+** → tick **Apple Push Notifications service** →
   download the `.p8`. **It can only be downloaded once.** Note the Key ID, and
   your Team ID from the top-right of the page.
3. **Give it to Firebase.** Firebase console → ⚙ Project settings → **Cloud
   Messaging** → under the iOS app, **APNs Authentication Key** → upload the
   `.p8` with its Key ID and Team ID.

Then follow `docs/notifications.md` for the Edge Function, which is shared
with Android and only needs doing once.

## What is already handled in the repo

These were done here so they do not become mysteries later:

- `ios/Podfile` — sets the iOS 13 minimum. Firebase 11 will not build below
  it, and CocoaPods reports that failure against some unrelated pod.
- `Info.plist` — camera and photo-library reasons. iOS **terminates the app**
  rather than refusing when one of these is missing, and the avatar picker,
  the transfer notice and the archive all reach for both.
- `Info.plist` — `remote-notification` background mode, without which iOS
  delivers notifications only while the app is already open.
- `Info.plist` — the three shipped languages, so iOS shows its own permission
  prompts in the reader's language rather than always English.

## What still cannot be verified from here

This project is developed on Linux, so nothing iOS-specific has been compiled
or run — only written to match what the SDKs require. The first `pod install`
on a Mac is the first real test of it.
