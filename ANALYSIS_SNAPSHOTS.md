# Deal analysis snapshots

Enable `seep_users.analysis_enabled` for the desired account. Sign in again or
restart the app online to refresh the cached capability. During a deal, open the
game menu and select **Save deal for analysis**. English and Hindi are supported.

Saving freezes the last committed state, even if a card is currently animating.
It does not end the deal. Each tap creates a new immutable UUID. The local outbox
is separate from completed-game reports and retries on resume and while the app
is open. The confirmation means saved locally and queued, not server receipt.
Uploads require the owning Google account and server-side analysis permission.
Revoked permission retains the snapshot locally; signing in after re-enabling
permission permits retry. Uninstalling/clearing data removes pending snapshots.

The payload contains the current deal's starting snapshot and events, full
current state (including hands), and current-deal bot diagnostics. Diagnostics
record the algorithm's available candidate evaluations, not every internal
search node. Older games with missing journal history are marked incomplete.
These hidden cards and diagnostics are not displayed during gameplay.

## Backend

Apply `backend/migrations/003_analysis_snapshots.sql` using the normal migration
runner and deploy the updated API module to the shared What's for Dinner backend.
The standalone Seep repository is not the active Render service's deployment source.
Deploy the backend before distributing the updated Android build: an old server's
404 response blocks queued snapshots for inspection.

- `POST /api/seep/analysis-snapshots`: Google bearer token, analysis flag required;
  201 new / 200 duplicate. No legacy upload-key access.
- `GET /api/seep/admin/users/:id/analysis-snapshots`: admin key and enabled analysis
  required; newest first, limit up to 10 and offset pagination.
- Table: `seep_analysis_snapshots`. No updates to game counts, wins or last_report_at.
- API response includes snapshotId, userId and reportId (acknowledgement alias for
  the reusable durable uploader). Unique `(user_id, client_snapshot_id)` preserves
  retry idempotency, while client_game_id links to a later completed-game report.
- Payload limit remains 2 MiB; local queue holds at most 50 snapshots. Save failures
  are surfaced rather than dropping previous snapshots.

Refresh privacy disclosures before enabling this in a public release.
