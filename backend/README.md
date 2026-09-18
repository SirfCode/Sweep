# Seep completed-game reports

Small Node/Fastify API for Render with Render Postgres. Android sends one report
after an entire multi-deal game ends. There are no live-state or per-turn endpoints.
Optional turn history is one JSON document inside the completed report.

## What is ready

- Four authenticated API routes, strict request validation, parameterized SQL.
- Transactional, concurrency-safe retry handling; first report wins.
- SQL migration, migration runner, admin query examples and Render Blueprint.
- Tested Android/native outbox and Flutter integration example.

This is not deployed, and the current game UI does not upload automatically.
Guest play remains offline. The example needs an opt-in/email UI and integration
with the saved-game lifecycle before enabling uploads in the app.

## Run locally

Use Node 22 and Postgres 14 or newer. From `backend`:

```powershell
npm ci
$env:DATABASE_URL = 'postgresql://USER:PASSWORD@localhost:5432/seep'
$env:ADMIN_API_KEY = 'REPLACE-WITH-A-RANDOM-ADMIN-KEY-AT-LEAST-32-CHARACTERS'
$env:SEEP_UPLOAD_API_KEY = 'REPLACE-WITH-A-DIFFERENT-RANDOM-UPLOAD-KEY-32-CHARACTERS'
npm run migrate
npm start
```

Generate each key separately with `node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"`.
Environment files are ignored by Git. `.env.example` is a reference; the server
reads process environment variables, not `.env` automatically. Default port is
10000; `GET /health` checks the database and returns 200 or 503.

## Deploy to Render

1. Commit and push this code and root `render.yaml` to the repository's `master`
   branch (or change the Blueprint branch before using another branch).
2. In Render, create a **Blueprint**, select the repository and `render.yaml`.
3. Supply distinct `ADMIN_API_KEY` and `SEEP_UPLOAD_API_KEY` secrets when prompted.
   `DATABASE_URL` is connected automatically to the database's internal URL.
4. Review the plans, then deploy. The service runs `npm ci --omit=dev` and starts
   with `npm run migrate && npm start`. Verify its HTTPS `/health` endpoint.
5. Configure the Flutter example with the service's HTTPS URL and upload-only key.

The Blueprint creates a free web service and free Postgres in Oregon for testing.
**Render's free Postgres expires after 30 days; choose a paid database before
keeping real player reports.** Free web services can sleep; timeouts are safe to
retry. See [Render free-service limits](https://render.com/docs/free) and
[Blueprint reference](https://render.com/docs/blueprint-spec).
`ipAllowList: []` disables external database access; the API uses Render's private
connection. The Android application never needs database credentials.

Startup migrations use an advisory lock and checksums. Applied SQL files must
not be edited: add a new numbered migration instead. Migrations are transactional;
failure prevents startup. The extra tracking table is `seep_schema_migrations`.
All application tables start with `seep_`. SQL is in `migrations/001_seep_reports.sql`.

## API

Send JSON and `X-API-Key: <appropriate key>`. Authentication is checked before
processing request bodies. Uploads are limited to 2 MiB. Unknown top-level fields
and wrong JSON types are rejected; summary and gameLog allow arbitrary objects.

### POST /api/seep/reports

Use the **upload key**. See `examples/completed-report.json` for a compact example.
Required: user.email, clientGameId, dealCount, winnerTeam, team0Total, team1Total.
humanTeam defaults to 0; userWon is derived (if supplied it must agree).
summary defaults to `{}`; gameLog is optional. Team values are 0 or 1; scores
must be nonnegative integers. An unfinished game with no winner is rejected.

```json
{"reportId":"server-uuid","userId":"server-uuid","duplicate":false}
```

201 means inserted, 200 means already received (`duplicate: true`). Email is
trimmed/lowercased; a supplied nonempty display name updates the existing user.
The transaction inserts the user/report and updates last_report_at together.
Retries with the same normalized email and clientGameId return the original IDs
without overwriting scores/logs or advancing last_report_at. Concurrent retries
are safe. A modified payload under an existing ID is still a duplicate, not an edit.
Keep the email and ID in the queued snapshot; do not replace them on retry.

PowerShell example (from `backend`, against your local service):

```powershell
$headers = @{ 'X-API-Key' = $env:SEEP_UPLOAD_API_KEY }
Invoke-RestMethod -Method Post -Uri http://localhost:10000/api/seep/reports `
  -Headers $headers -ContentType application/json `
  -Body (Get-Content -Raw examples/completed-report.json)
```

### GET /api/seep/admin/stats?limit=10&minGames=1

Use the **admin key**. Returns totalUsers, totalUploadedGames, gamesLast30Days,
usersWithAtLeastOneWin and topUsers. Each top user has userId, email, displayName,
games, wins and winRate (fraction 0–1). Sorted by win rate, then number of games.
limit is at most 100. Use `minGames=5` or higher to avoid single-game leaders.
SQL examples are in `sql/admin_examples.sql`.

### PATCH /api/seep/admin/users/:id/analysis

Use the admin key and `{"analysisEnabled":true}` (or false).
Returns `{id, analysisEnabled}`; an unknown user returns 404.

### GET /api/seep/admin/users/:id/reports

Use the admin key. Newest first; returns `{reports, limit, offset, nextOffset}`.
Report field names match the SQL schema. Default limit 25, maximum 100.
Pass `offset`/`limit` for pagination. `nextOffset: null` ends the list.

Logs are excluded unless `includeGameLog=true`; this also requires that user's
analysis flag to be enabled. With logs, the default and maximum limit are 10.
The flag controls **API access to logs**, not collection: a supplied gameLog is
stored regardless of the flag. Disabling analysis does not delete stored logs.
Omit gameLog when the player has not agreed to detailed collection.

401 = missing/wrong key; 400 = invalid input; 404 = unknown user; 403 = analysis
not enabled for log retrieval; 413 = oversized report; 503 = transient service
failure. Errors and routine logs do not contain report bodies or credentials.

## Flutter integration

See `../examples/completed_game_upload.dart`, `../lib/reporting/completed_report.dart`
and `../lib/reporting/report_queue.dart`. The `http`, `path_provider` and `uuid`
dependencies and Android INTERNET permission are included.

1. After opt-in/email collection, open one `ReportingExample` for the app session.
2. When creating a new full game, generate `ReportingExample.newGameId()` once.
   Persist this ID **in the same save envelope as the game's state**, then start
   play. Restore that ID on resume; do not create one per deal or per retry.
   For a legacy save, generate and save its ID once before attempting reporting.
3. When `game.winner != null` and the results phase is reached, await:

```dart
await reporting.gameFinished(
  game,
  clientGameId: savedGameId,
  email: optedInEmail,
  displayName: playerName,
  appVersion: '0.10.0+10', // Use your build's actual version.
);
```

4. Only clear/replace that finished save after enqueue succeeds. On storage
   failure retain it and show a retry option. The queue writes before HTTP starts.
5. Dispose the example when its owning session ends. It retries on launch/resume
   and once per minute while foregrounded. It does not run a background service.

Configure a build with `--dart-define=SEEP_API_URL=https://YOUR-SERVICE.onrender.com`
and `--dart-define=SEEP_UPLOAD_API_KEY=YOUR-UPLOAD-KEY`. These are extractable from
the app; never substitute the admin key or database URL.

The outbox is a file in native application support storage, flushed to a temporary
file then replaced. It survives app restarts; uninstall/clearing app data removes
it. Use one queue instance in one isolate. It is not a browser storage adapter.
The existing web game remains unaffected because it does not import the example.

Requests time out after 60 seconds. Network errors, malformed acknowledgements
and server failures retain the exact report. Retries use exponential backoff with
jitter, capped at six hours; numeric Retry-After is honored within those bounds.
Both valid 200 and 201 acknowledgements remove the report. 401/403 pause attempts
for an hour; repair configuration before retrying. 400/404/413/415/422 keep a
blocked entry for inspection rather than retrying forever. Surface lastError and
lastResult in your eventual settings UI. Blocked-entry editing/recovery UI is not
included. The queue caps at 50 reports and never silently evicts unsent reports.

The builder intentionally supplies totals and winner only. The game currently
retains diagnostics for just the current/previous deal, so it cannot reconstruct
a complete multi-deal log or cumulative seep counts from those diagnostics.
If detailed analysis is wanted, collect compact hands/table/events and per-deal
scores locally for the full game, persist them with the save, and pass that object
as fullGameLog at completion. Do not label the existing truncated diagnostics a
complete game log, and do not upload a live save after every move.

## Security scope

The separate shared upload key meets the requested simple integration but is not
player authentication: anyone who extracts it can submit someone else's email
or fabricated scores. Admin routes remain separately protected. Before public
account-based reporting/rankings, verify identity with an auth provider and derive
user identity from its validated token. The schema/queries do not verify game
replays or prevent cheating. Rate limiting and user data retention/deletion policy
should be added for a public reporting service. There is no permissive CORS setup;
the native Android example does not require it.

## Tests

Backend tests use a real, disposable Postgres database. They truncate `seep_users`
and reports; **never point TEST_DATABASE_URL at a database containing real data**.

```powershell
$env:TEST_DATABASE_URL = 'postgresql://USER:PASSWORD@localhost:5432/seep_test'
npm test
# From repository root:
flutter test test/report_queue_test.dart
flutter analyze
```

Coverage includes migration re-runs, indexes, concurrent idempotency, rollback,
auth separation, request validation, stats, analysis access, pagination, cascade
deletion, offline restart/retry, concurrent enqueue, timeouts and storage failures.
