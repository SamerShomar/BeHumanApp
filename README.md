# be_human_app

Be Human Foundation Management Platform — a Flutter app with role-based
navigation (member / manager / admin) on top of Firebase Auth and Firestore.

## Getting Started

```bash
flutter pub get
flutter run
```

## Firebase setup

The app calls `Firebase.initializeApp()` with no explicit options, so each
platform reads its own configuration file:

- **Android** — `android/app/google-services.json` (already in the repo).
- **iOS** — `ios/Runner/GoogleService-Info.plist`. **This file is missing**, so
  iOS builds will fail at startup until it is added. Download it from the
  Firebase console (project `be-human-5023e`) after registering an iOS app, or
  run `flutterfire configure` to generate it along with `lib/firebase_options.dart`.

## Data protection

**Already encrypted, nothing to configure:** every Firebase and Supabase call
travels over TLS, and both services encrypt at rest on their servers. The app
never sends anything in the clear over the network.

The exposure that remains is the **device**. These measures address it:

| Measure | Where | Effect |
| --- | --- | --- |
| Offline cache disabled | `SecuritySettings.allowOfflineCache` | Firestore's local cache is an unencrypted SQLite file; with it off, no proposal or transaction is written to disk |
| Cache cleared on sign-out | `AuthService.signOut` | Nothing readable is left behind for the next holder of the device |
| Login required on every launch | `SecuritySettings.requireLoginOnLaunch` | Firebase Auth keeps the session on disk; without this, reopening the app skips the login screen entirely |
| Auto sign-out after 10 min idle | `InactivityGuard` | An unlocked phone with the app open is otherwise full access |
| `FLAG_SECURE` | `MainActivity.kt` | Blocks screenshots and screen recording, and blanks the recents-switcher thumbnail |
| 5-minute signed URLs | `FileStorageService` | A copied PDF link cannot outlive the session |
| Access rules | `firestore.rules` | Server-side enforcement — the real boundary, independent of the client |

**Trade-off to be aware of:** with the offline cache disabled the app needs a
live connection for every read and will not work offline. That is deliberate
for financial and beneficiary records. If uninterrupted offline use matters
more than a seized device staying unreadable, set `allowOfflineCache` to `true`
in `lib/core/security/security_settings.dart` — and understand what it means.

**Not implemented — and why.** Client-side end-to-end encryption (encrypting
fields before they reach Firestore) was considered and rejected. The key would
have to ship inside the app, so anyone with the APK could decrypt; it would
break server-side ordering and the rules that check `submittedBy`; and a lost
key would mean permanently unreadable records. Real end-to-end encryption needs
per-user keys and key exchange, which is a much larger system than this. For a
small team whose realistic threat is a lost or seized device, the measures above
give far more actual protection.

**Recommended next step:** enable
[Firebase App Check](https://firebase.google.com/docs/app-check) with Play
Integrity. It stops a stolen `google-services.json` from being used to talk to
your backend from outside the real app. It is free and configured entirely in
the Firebase console.

## Firestore security rules

`firestore.rules` is the access model — without it deployed, a project left in
test mode exposes every proposal and financial record to anyone on the
internet, and a project in production mode denies everything.

Deploy it:

```bash
npm install -g firebase-tools   # once
firebase login
firebase deploy --only firestore:rules --project be-human-5023e
```

Or paste the file's contents into Firebase console → Firestore Database →
Rules → Publish.

What it enforces:

| Collection | Read | Write |
| --- | --- | --- |
| `users` | any signed-in user with a profile | admin only, except a user editing their own profile without changing `role` or `team` |
| `proposals` | any signed-in user with a profile | create by the submitter (stamped with their own uid); status changes by manager/admin |
| `transactions` | any signed-in user with a profile | manager/admin only |

Everything else is denied. A signed-in user with no `users` document can read
nothing, which matches `AuthService.signIn` rejecting that case.

## File storage (proposal PDFs)

Firebase Storage requires the paid Blaze plan, so PDFs are stored in
**Supabase Storage** instead. Firebase Auth and Firestore are unchanged — only
the file bytes live elsewhere.

A Firestore document is capped at 1 MiB, so the PDF cannot be embedded in it.
The bytes go to a private Supabase bucket and the document keeps only the
object path in `pdfPath`; the app mints a short-lived signed URL when a file is
opened.

### Setup

1. Create a project at [supabase.com](https://supabase.com) (no card required).
2. **Storage → New bucket** named `proposals`, left **Private**.
3. **Settings → API** — copy the *Project URL* and the *anon public* key.

### Running

Copy the template and fill in the two values from **Project Settings → API**:

```bash
cp env.example.json env.json
```

```json
{
  "SUPABASE_URL": "https://your-project-ref.supabase.co",
  "SUPABASE_ANON_KEY": "eyJhbGci..."
}
```

Then run:

```bash
flutter run --dart-define-from-file=env.json
flutter build apk --dart-define-from-file=env.json
```

`env.json` is gitignored, so the keys stay out of the repository.

To avoid typing the flag at all:

- **VS Code** — press F5. `.vscode/launch.json` already passes it.
- **Android Studio** — Run → Edit Configurations → *Additional run args*:
  `--dart-define-from-file=env.json`

To use a different bucket name, add `"SUPABASE_PROPOSALS_BUCKET": "<name>"` to
the same file.

Without these flags the app still builds and runs; uploading a proposal reports
that storage is not configured rather than failing obscurely.

> The **anon** key is meant to ship inside client apps and only grants what the
> bucket's policies allow. The **service_role** key is a full admin credential
> and must never be placed in the app or this repository.

### Bucket policies

The anon key alone lets any holder call the storage API, so restrict the bucket
in **Storage → Policies**. At minimum, scope `INSERT` and `SELECT` to the
`proposals` bucket. Since sign-in is handled by Firebase rather than Supabase
Auth, these policies cannot identify the user; treat the bucket as
app-scoped rather than per-user, and keep it private so files are reachable
only through generated signed URLs.

## User accounts

Accounts are **not** created by the app. Create them in the Firebase console
(Authentication → Users), then add a matching document in the `users`
collection keyed by the user's UID:

```json
{
  "uid": "<firebase-auth-uid>",
  "email": "person@behuman.org",
  "name": "Full Name",
  "role": "member",
  "team": "gaza",
  "isActive": true,
  "createdAt": "2026-01-01T00:00:00.000Z"
}
```

`photoPath` is added by the app when a user sets a profile picture and holds
the avatar's object path (`avatars/<uid>`), not a URL — the bucket is private,
so a viewable link is generated on demand and expires. Avatars live in the same
bucket as the documents, so the policies above already cover them.

`role` is one of `member`, `manager`, `admin`, and `team` is one of `gaza`,
`netherlands` — the bare enum names the generated serializer reads and writes. A user without a
`users` document cannot sign in — `AuthService.signIn` rejects the login.

Never commit passwords to this repository. Users change their own password from
Settings → Change Password, which re-authenticates against Firebase.

## Code generation

`AppUser` uses `freezed` and `json_serializable`. After editing it, regenerate:

```bash
dart run build_runner build --delete-conflicting-outputs
```

## Tests

```bash
flutter analyze
flutter test
```
