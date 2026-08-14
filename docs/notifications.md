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

## What it does not do, and why

An alert **does not arrive when the app is closed**. That is the one thing this
design cannot do, and it is not an oversight.

A real push notification has to be sent by a server. The credentials that
authorise sending (an FCM service-account key) cannot ship inside the app —
anyone who unpacked the APK could then send notifications to every user. The
standard place to put that server is **Cloud Functions for Firebase, which
requires the paid Blaze plan** — the same limit that pushed file storage over
to Supabase.

## Adding real background push later

Everything below is optional and none of it changes the behaviour described
above; it adds delivery while the app is closed.

1. **Sender.** A Supabase Edge Function (free tier) holding the FCM
   service-account key, triggered by the app right after a successful write —
   the same two places that call `NotificationService` today.
2. **Receiver.** Add `firebase_messaging` to the app, request the notification
   permission (required on Android 13+), and store each device's FCM token on
   the user's profile so the function knows where to send.
3. **Android** works with the Firebase config already in the repo.
4. **iOS** additionally needs a paid Apple Developer account, an APNs key
   uploaded to Firebase, and `ios/Runner/GoogleService-Info.plist`, which the
   repo does not have yet.

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
