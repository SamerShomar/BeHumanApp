# Notifications

## What the app does today

Two events are announced to the team:

| Event | Who is told | Where it links |
| --- | --- | --- |
| A proposal is submitted | Managers and admins (the reviewers) | `/proposals` |
| A financial movement is added | Everyone | `/financial` |

Each event becomes one document in the `notifications` collection. The people
who should see it are decided when it is published and stored in an `audience`
field, so a reader never has to be trusted to filter correctly.

The person who caused the event is never notified about their own action.

**Where it shows up**

- A bell with an unread count in every screen's app bar (on the home screen it
  sits next to the greeting, which has no app bar).
- `/notifications` — the full feed, newest first, unread entries tinted, with
  "mark all read". Admins can delete an entry for everyone.
- A pop-up alert the moment an event arrives while the app is open, wherever
  the user happens to be, with an "open" button.

**Language** — the text is stored as translation keys plus parameters, never as
a finished sentence. A proposal submitted by an Arabic speaker reads in Dutch
on a Dutch reviewer's phone.

**Offline** — the feed is a Firestore query, so it uses the same offline cache
as the rest of the app. Events published while a phone has no connection are
queued and sent when it reconnects.

## Alerts while the app is closed

Everything on the app's side is done. What remains is **one Edge Function
deployed and one secret set**, both of which have to be done from a Supabase
account and cannot be done from inside the app. Until then everything above
still works; the app tries to deliver, the call fails, and nothing else
changes.

### Why it cannot all live in the app

Sending through FCM requires a Firebase **service-account key**. A key shipped
inside an APK can be extracted by anyone who downloads the app, and they could
then push anything to every user of the platform. So the key lives on a server.
The usual server is Cloud Functions for Firebase, which needs the paid Blaze
plan — the same limit that moved file storage to Supabase — so this runs on a
**Supabase Edge Function** on the free tier instead.

### What is already in the repository

| Piece | Where |
| --- | --- |
| The sender | `supabase/functions/send-notification/index.ts` |
| Device registration | `lib/core/services/push_service.dart` — stores each device's FCM token on the user's own profile |
| Hooked into sign-in / sign-out | `lib/core/services/push_registrar.dart`, settings screen |
| The call that triggers a send | `NotificationService._deliver` |
| Endpoint URL | derived from `SUPABASE_URL`, already in `env.json` — no new app config |

The app sends **only the notification's id**. The function reads the text from
Firestore itself, so a caller cannot dictate what an alert says, and it refuses
events older than five minutes so the endpoint cannot be used to replay
notifications at the team.

Each user's chosen language is written to their profile (`locale`) when they
change it in settings, because the server composing the alert has no other way
to know which language to use.

### Turning it on

Needs a computer, not a phone.

1. **Get the service-account key.** Firebase console → ⚙ Project settings →
   *Service accounts* → **Generate new private key**. A `.json` file downloads.
   Treat it like a password; never commit it.

2. **Install the Supabase CLI.** Not with `npm install -g supabase` — the CLI
   refuses to install as a global npm module and says so. Use the package
   manager for the platform:

   **Windows** (PowerShell). Scoop first, if it is not already there:

   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   Invoke-RestMethod get.scoop.sh | Invoke-Expression
   scoop bucket add supabase https://github.com/supabase/scoop-bucket.git
   scoop install supabase
   ```

   **macOS / Linux:**

   ```bash
   brew install supabase/tap/supabase
   ```

   Neither of those needs Node.js. If you would rather install nothing at all
   and you do have Node, `npx supabase@latest <command>` works everywhere a
   plain `supabase` does — write `npx supabase@latest login` in place of
   `supabase login` below, and so on for every command.

   Then sign in. It opens a browser:

   ```
   supabase login
   ```

3. **Link the project.** Run this **from the project folder** — the one
   holding `pubspec.yaml` — because it reads `supabase/config.toml`, which is
   in this repository. The ref is in the Supabase dashboard URL, and under
   Project Settings → General:

   ```
   supabase link --project-ref PROJECT_REF_HERE
   ```

   Replace the whole word, and **do not wrap it in angle brackets**.
   PowerShell reads `<` as a redirection operator and refuses the line with
   "The '<' operator is reserved for future use" before the command ever runs.
   The same goes for every placeholder below.

4. **Store the key as a secret** — this is what keeps it off every phone:

   ```bash
   supabase secrets set FIREBASE_SERVICE_ACCOUNT="$(cat /full/path/to/serviceAccount.json)"
   ```

   On Windows PowerShell:

   ```powershell
   supabase secrets set FIREBASE_SERVICE_ACCOUNT="$(Get-Content -Raw C:\full\path\to\serviceAccount.json)"
   ```

   The path is the real location of the file you downloaded from Firebase —
   `C:\Users\Samer\Downloads\be-human-5023e-firebase-adminsdk-xxxxx.json` or
   wherever it landed. In File Explorer, shift-right-click the file and choose
   **Copy as path** to get it exactly, quotes included.

5. **Deploy** — also from the project folder:

   ```
   supabase functions deploy send-notification
   ```

6. **Test.** Run the app on two phones with different accounts, submit a
   proposal from one, and close the app on the other. Logs are under
   *Edge Functions → send-notification → Logs* in the Supabase dashboard; a
   successful call returns `{"recipients":N,"delivered":N}`.

### What happens when an alert is tapped

The sender puts the destination in the message payload, and the app navigates
there — `/proposals` for a proposal, `/financial` for a movement — whether it
was in the background or not running at all.

Only routes the app actually has are honoured. The payload arrives from outside
the app, and handing the router an arbitrary string lands the user on the error
screen; an unrecognised route is dropped and the app simply opens.

### Platform notes

- **Android** works with the `google-services.json` already in the repo.
  Three things had to be in place for an alert to appear, and now are:
  - `POST_NOTIFICATIONS` is declared in the manifest. Android 13 and newer
    will not show the permission dialog at all without it — the request
    returns "denied" without ever asking, and nothing is ever delivered.
  - a dedicated status-bar icon (`res/drawable/ic_notification.xml`). Android
    builds that icon from its alpha channel alone, so a full-colour launcher
    icon arrives as a solid white square.
  - a tint colour matching the brand, so an alert looks like it came from
    this app.
- **iOS** additionally needs a paid Apple Developer account, an APNs key
  uploaded to Firebase, and `ios/Runner/GoogleService-Info.plist`, which the
  repo does not have yet. Until then iOS does not build at all.

### If nothing arrives

Work down this list — it is ordered by how often each one is the cause.

| Symptom | Cause |
| --- | --- |
| `{"error":"FIREBASE_SERVICE_ACCOUNT is not set"}` in the logs | step 4 was skipped, or run before `supabase link` |
| `{"recipients":0}` | nobody has a device token yet: each person must sign in **once** on the new build and accept the permission prompt |
| `{"recipients":N,"delivered":0}` | the service-account key is for a different Firebase project than the app |
| Nothing in the logs at all | the app is not calling out — check `SUPABASE_URL` is passed at build time, since the endpoint is derived from it |
| Works on one phone, not another | notifications are off for the app in Android settings, or that person never accepted the prompt |

A notification is never sent to the person who caused it. Testing with one
account on two phones will therefore look like a failure — use two accounts.

## Firestore rules

`firestore.rules` already covers the collection. Redeploy after pulling:

```
firebase deploy --only firestore:rules
```

The rules enforce three things the app cannot be trusted to enforce alone:

- a notification must carry its author's own uid, so nobody can post an
  announcement in someone else's name;
- the only permitted edit is adding **your own** uid to `readBy` — no other
  field may change, and you cannot mark something read on another user's
  behalf;
- only an admin may delete.
