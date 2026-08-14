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

This part is **built but not yet switched on**: it needs one Edge Function
deployed and one secret set, both of which have to be done from a Supabase
account. Until then everything above still works; the app tries to deliver,
the call fails, and nothing else changes.

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

2. **Install the Supabase CLI** and sign in:

   ```bash
   npm install -g supabase
   supabase login
   ```

3. **Link the project** (the ref is in the Supabase dashboard URL, and under
   Project Settings → General):

   ```bash
   supabase link --project-ref <your-project-ref>
   ```

4. **Store the key as a secret** — this is what keeps it off every phone:

   ```bash
   supabase secrets set FIREBASE_SERVICE_ACCOUNT="$(cat /path/to/serviceAccount.json)"
   ```

   On Windows PowerShell:

   ```powershell
   supabase secrets set FIREBASE_SERVICE_ACCOUNT="$(Get-Content -Raw C:\path\to\serviceAccount.json)"
   ```

5. **Deploy:**

   ```bash
   supabase functions deploy send-notification
   ```

6. **Test.** Run the app on two phones with different accounts, submit a
   proposal from one, and close the app on the other. Logs are under
   *Edge Functions → send-notification → Logs* in the Supabase dashboard; a
   successful call returns `{"recipients":N,"delivered":N}`.

### Platform notes

- **Android** works with the `google-services.json` already in the repo. The
  app asks for notification permission on first sign-in, which Android 13 and
  newer require.
- **iOS** additionally needs a paid Apple Developer account, an APNs key
  uploaded to Firebase, and `ios/Runner/GoogleService-Info.plist`, which the
  repo does not have yet. Until then iOS does not build at all.

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
