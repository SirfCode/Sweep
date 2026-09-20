# Google sign-in (Android)

Players can continue as guests or choose **Sign in with Google** on the home
screen. Guest games stay on the device. Signed-in players upload one report after
a full game finishes; gameplay remains offline. Guests use the v0.5.0 strategy;
signed-in players use the current strategy (internally Low; displayed as Easy).
Medium and Hard are
disabled. Successful login replaces an unfinished guest game with a fresh Low
game. Failed login preserves it. Offline cached accounts retain Low access.

## Google Cloud configuration

- Android package: `com.nzkosh.seep`
- Android client: `863353284554-lq8tj2uruu80uuluurrc59iep4vgbc30.apps.googleusercontent.com`
- Web/backend client: `863353284554-ph5l416ufjj2s7g0l3om594ldq2qmnvq.apps.googleusercontent.com`
- Testing APK signing SHA-1: `F5:A3:83:34:33:DA:73:46:1A:0F:AE:77:1D:3D:3E:6D:D6:A2:01:9C`

Both clients must belong to the same Google Cloud project. The Android client is
matched by package/certificate; the SDK receives the Web client as serverClientId.
No client secret or google-services.json is required for this flow. Client IDs
are public identifiers. If consent is in Testing mode, add the testing Gmail
accounts as test users. Register the production/Play signing certificate before
distributing a production build. This APK currently uses the local debug signing
certificate even when built in release mode.

The package changed from com.example.sweep, so this installs as a separate app
from older APKs and does not inherit their local saves.

## Backend

Use the existing shared Render service and database. Set:

```
SEEP_GOOGLE_CLIENT_ID=863353284554-ph5l416ufjj2s7g0l3om594ldq2qmnvq.apps.googleusercontent.com
SEEP_ALLOW_LEGACY_UPLOADS=false
```

Keep existing DATABASE_URL, SEEP_ADMIN_API_KEY and SEEP_UPLOAD_API_KEY settings.
The upload key remains a configuration requirement for optional legacy testing;
it is not included in the new APK. Admin endpoints still require their separate
key. Migration 002 adds a unique Google subject to seep_users without changing
existing application tables.

`POST /api/seep/auth/google` accepts `Authorization: Bearer <Google ID token>`
and returns `{user: {id, email, displayName, googleSubject}}`. Google signature,
audience, issuer, expiry and verified email are checked server-side. Identity
comes from the verified token; the OAuth client secret is never used.

`POST /api/seep/reports` uses the same Bearer header. Report email/Google subject
must match the authenticated player. Display name comes from Google. Repeated
clientGameId values for that user return the original report without duplication.
Legacy key-only uploads are rejected by default. Explicitly enabling legacy mode
allows only the dummy player@example.com identity, not arbitrary user emails.

## Offline and session behavior

Only the verified profile is cached in preferences. Tokens stay in memory; the
Google SDK restores an account when possible. Cached profiles allow offline
completion/queuing but cannot authorize uploads. Expired sessions require a fresh
token. Sign-out clears the session; unsent reports stay queued for their original
account and cannot upload under another account. A successful sign-in retries
authentication-blocked reports. Uninstalling removes local saves and the outbox.

Reports currently include totals/winner, not a complete multi-deal replay.
Authentication proves identity, not the correctness of client-submitted scores.
Web and Windows gameplay continue as guests; Google login here targets Android.

## Build and verify

```
flutter build apk --release
```

Do not use the old private-testing dart-define file containing the shared key.
The default API URL and public client ID are in lib/auth/google_session.dart.
SEEP_API_URL may override the endpoint, but Google token transmission requires
HTTPS. Never embed admin keys, database URLs, or OAuth client secrets.

Install build/app/outputs/flutter-apk/app-release.apk on the registered device.
Choose Google sign-in, select a test account, and confirm its email appears.
Finish a full game; check its report through the admin API. Also test finishing
offline, reconnecting, signing out and switching accounts. A real device Google
consent/sign-in round trip is required in addition to automated tests.

Implementation: lib/auth/google_session.dart, lib/reporting/app_reporting.dart,
backend/src/google-auth.js. Automated tests verify forged/expired tokens,
identity mismatch, idempotency, account-specific queues and retry behavior.

## Troubleshooting

The app logs only stable `seep_sign_in_failed` codes (HTTP status, missing token,
network, timeout or invalid profile). The server logs `seep_google_login` status
and sanitized `seep_google_rejected` / `seep_google_error` categories. Tokens,
Google error text, response bodies and account details must never be logged.

A real phone login was confirmed after reinstalling the diagnostic APK: the live
backend returned 200 and created one Google-linked user. The earlier generic
failure was not captured, so its root cause remains unconfirmed. A completed-game
upload from that signed-in phone still requires finishing a full game.
