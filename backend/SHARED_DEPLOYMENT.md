# Shared Render deployment

Seep shares the existing `whats-for-dinner` Node service and
`whats-for-dinner-postgres` database in Ohio. No new paid plan was added.

- Base URL: https://whats-for-dinner-k4u8.onrender.com
- Upload: POST /api/seep/reports
- Admin routes: /api/seep/admin/...
- Host health: GET /api/health
- Deployment repository: https://github.com/SirfCode/whats-for-dinner
- Integration commit: a61e2fb989a9d9da022bd00064bacbdbc0b0be13

The host's `backend/src/server.js` dispatches `/api/seep` requests to
`backend/seep/src/shared-host.js` before its own authentication handlers.
All other routes keep their existing behavior. Seep uses the existing DATABASE_URL
and separate SEEP_ADMIN_API_KEY / SEEP_UPLOAD_API_KEY variables. Standalone mode
still uses ADMIN_API_KEY. Do not replace the host's DATABASE_URL or other secrets.

Initialization runs additive Seep migrations on the first Seep request. It creates
only seep_users, seep_game_reports, seep_schema_migrations and their indexes.
If initialization fails, Seep returns 503 and retries initialization on a later
request; the host application remains available. Its health route is unchanged.
Future API updates must also be copied into the host repository's backend/seep
module; updating this repository alone does not deploy that shared module.

The first dummy report was accepted with HTTP 201 and verified in the shared DB:

- Email: player@example.com
- Client game ID: e7779024-fbbc-4296-b81e-fd812a253d80
- Report ID: c4dd2f61-5190-4df5-bbc6-d2777bf398df

This sample is retained as requested. Existing What's for Dinner records were not
changed. No database cleanup or destructive tests were run on the shared database.

## Android

Native app builds can enable reporting with SEEP_API_URL, SEEP_UPLOAD_API_KEY,
SEEP_REPORT_EMAIL (defaults to player@example.com), and SEEP_APP_VERSION compile
definitions. The upload key is extractable from the APK; this configuration is
intended for the owner's private testing, not public account authentication.
Use an ignored local JSON file with `--dart-define-from-file=PATH` when building.
Never include the admin key or database URL in that file or APK.

The game saves clientGameId alongside its existing saved state. It queues a report
only after a full-game winner exists. Queue writes precede save replacement, and
offline reports retry on app start/resume and periodically while foregrounded.
Ordinary unconfigured builds and browser play do not upload. The game report
currently contains totals/winner; detailed multi-deal event collection is optional
and not enabled by this integration.

## Superseded resources

The original free `seep-api` in Oregon and free `seep-postgres` are not used by this
deployment. The old seep-api was suspended with your approval. The old database
has not been deleted; deletion requires separate confirmation. Neither was
upgraded to a paid plan. The old free database expires October 19, 2026 (NZ time).
The old root Blueprint has been replaced by a non-active standalone example so it
cannot provision a fresh database on a new deployment. Its old Render Blueprint
may report a missing configuration file until disconnected or removed.
