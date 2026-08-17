# Putting the app on an iPhone

## Two separate requirements, often confused

Getting this app onto an iPhone needs two things that people tend to treat as
one. They are not:

1. **A Mac**, to compile it. Apple allows iOS builds on macOS only.
2. **An Apple account**, to *sign* it. Unsigned apps do not install on phones —
   this is enforced by iOS itself, not by any tool.

**Codemagic solves the first and not the second.** It builds on its own Macs,
so no Mac is needed here. But signing still runs through Apple, and Codemagic
signs with an App Store Connect API key, which **Apple issues only to paid
Developer Program accounts ($99/year)**. A free Apple ID can sign only through
Xcode on a Mac — which is the situation Codemagic exists to avoid.

So, honestly:

| What you have | What you get |
| --- | --- |
| Codemagic, no Apple account | an unsigned .ipa — sideloadable for 7 days, not shareable |
| Codemagic + $99 program | TestFlight: the team installs it from a link, no cables |
| A Mac + free Apple ID | installable, stops working every 7 days |
| A Mac + $99 program | same as Codemagic + $99 |

The build-check-only case is still worth running first. Nobody has ever
compiled the iOS side of this project, so it is where the Podfile, the
deployment target and the Firebase setup get their first real test — and it
costs nothing to find out before spending $99.

Codemagic's free tier gives 500 build minutes a month on macOS, which is
plenty for a project this size.

If you would rather have the Mac itself: **MacinCloud** or **MacStadium** rent
one for roughly $20–30 a month over remote desktop, and then the "A Mac"
rows above apply instead.

## Setting up Codemagic

`codemagic.yaml` in the repository root already defines three workflows:

| Workflow | What it does | Needs |
| --- | --- | --- |
| `ios-unsigned` | builds an **unsigned .ipa**; proves the setup works | nothing but the Firebase file |
| `ios-testflight` | builds and sends to TestFlight | the $99 program |
| `android-apk` | builds the Android APK | nothing extra |

### 1. Connect the repository

1. Sign up at `codemagic.io` with the GitHub account
2. **Add application** → GitHub → **BeHumanApp**
3. It will find `codemagic.yaml` on its own and list the three workflows

### 2. Add the keys

Two environment groups, under **Environment variables** in the app settings.
Tick **Secure** on every one of them.

Group **`supabase`** — the same two values as your local `env.json`:

| Variable | Value |
| --- | --- |
| `SUPABASE_URL` | `https://<your-ref>.supabase.co` |
| `SUPABASE_ANON_KEY` | the anon *public* key |

Never add the Supabase `service_role` key to this group. It is a full admin
credential, and anything in these groups is compiled into an app that gets
handed to people.

Group **`firebase-ios`** — the Firebase config file, which is not in the
repository:

| Variable | Value |
| --- | --- |
| `GOOGLE_SERVICE_INFO_PLIST` | the file, base64-encoded |

To produce that value, after downloading the file from Firebase (see the next
section for how):

```bash
# macOS / Linux
base64 -i GoogleService-Info.plist | tr -d '\n'
```

```powershell
# Windows PowerShell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("GoogleService-Info.plist"))
```

Paste the result as the variable's value. The build decodes it back into
`ios/Runner/GoogleService-Info.plist` and checks it parses before going on, so
a truncated paste fails the build with a clear reason instead of crashing on
someone's phone later.

### 3. Run `ios-unsigned` to get an .ipa

Press **Start new build**, pick the branch, pick `iOS — unsigned ipa`. It runs
the analyzer and the full test suite first, then compiles and packages.

The artifact is **`be-human-unsigned.ipa`**, downloadable from the build page.

If it goes green, the iOS side of this project is sound and the only thing
between you and phones is the Apple account.

### Getting that .ipa onto a phone

An unsigned .ipa will not install on iOS — the system refuses it. It has to be
signed by somebody, and there are only two ways.

**Sideload it (free, seven days).** Tools like **Sideloadly** or **AltStore**
run on Windows, take an unsigned .ipa, sign it with an ordinary free Apple ID,
and install it over a cable. What you get:

- works on your own phone, no Mac, no $99
- **stops opening after 7 days** and has to be re-installed the same way
- three apps at a time per Apple ID
- every person needs their own PC session with the phone plugged in

Fine for you to try the app. Not a way to give it to the Gaza and Netherlands
teams — nobody is going to re-plug a phone into a laptop every week.

**TestFlight ($99/year).** The `ios-testflight` workflow below builds a signed
build and uploads it. Everyone installs from a link in Apple's TestFlight app,
it lasts 90 days per build, and updates arrive on their own. This is the only
arrangement that works for a team.

| | Sideload | TestFlight |
| --- | --- | --- |
| Cost | free | $99/year |
| Lasts | 7 days | 90 days, auto-updating |
| Install | cable + PC, per phone | a link |
| Notifications | no — needs a paid push certificate | yes |

Note the last row: **push notifications do not work on a sideloaded build.**
Apple issues APNs keys to paid accounts only, so a free-signed app installs and
runs but never receives an alert.

### 4. When you have the $99 program

1. `appstoreconnect.apple.com` → **Users and Access** → **Integrations** →
   **App Store Connect API** → **+** → role **App Manager** → download the
   `.p8`. **It downloads once only.** Note the Issuer ID and Key ID.
2. In Codemagic: **Teams** → **Integrations** → **App Store Connect** → add
   the key, and name it exactly **`codemagic-api-key`** — `codemagic.yaml`
   refers to it by that name.
3. Register the app on App Store Connect with bundle ID
   `com.behuman.beHumanApp`.
4. Run the `ios-testflight` workflow. Everyone who should get the app is added
   under **TestFlight → Internal Testing**; they install Apple's TestFlight app
   and the build appears there.

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

   **On Codemagic** that is all — base64 it into the `GOOGLE_SERVICE_INFO_PLIST`
   variable as described above and the build writes it into place.

   **On a Mac**, it has to be added *through Xcode* so the file is included in
   the build: open `ios/Runner.xcworkspace`, drag the file onto the `Runner`
   folder in the left sidebar, and make sure **"Copy items if needed"** and the
   **Runner** target are both ticked. Dropping it in the folder with Finder
   alone is the most common reason the app still crashes afterwards.

## Building it on a Mac

Only relevant if you have one — otherwise use the Codemagic route above.

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
   `com.yourname.behuman` — **and register that same string in Firebase in
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

1. **Turn the capability on.** On Codemagic this is part of the provisioning
   profile: enable **Push Notifications** on the App ID at
   `developer.apple.com` → Certificates, Identifiers & Profiles →
   **Identifiers** → `com.behuman.beHumanApp`. On a Mac, Xcode →
   **Signing & Capabilities** → **+ Capability** → **Push Notifications**,
   which also writes the entitlements file — which is why that file is not
   committed here by hand.
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
