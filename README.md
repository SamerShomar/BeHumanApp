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

## User accounts

Accounts are **not** created by the app. Create them in the Firebase console
(Authentication → Users), then add a matching document in the `users`
collection keyed by the user's UID:

```json
{
  "uid": "<firebase-auth-uid>",
  "email": "person@behuman.org",
  "name": "Full Name",
  "role": "UserRole.member",
  "team": "UserTeam.gaza",
  "isActive": true,
  "createdAt": "2026-01-01T00:00:00.000Z"
}
```

`role` is one of `UserRole.member`, `UserRole.manager`, `UserRole.admin`, and
`team` is one of `UserTeam.gaza`, `UserTeam.netherlands`. A user without a
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
