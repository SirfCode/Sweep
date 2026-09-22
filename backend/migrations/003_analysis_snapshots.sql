CREATE TABLE seep_analysis_snapshots (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 user_id uuid NOT NULL REFERENCES seep_users(id) ON DELETE CASCADE,
 client_game_id text NOT NULL,
 client_snapshot_id uuid NOT NULL,
 deal_number integer NOT NULL,
 move_number integer NOT NULL,
 deal_status text NOT NULL CHECK (deal_status IN ('in_progress','completed')),
 saved_at timestamptz NOT NULL,
 uploaded_at timestamptz NOT NULL DEFAULT now(),
 app_version text NOT NULL,
 bot_strategy text NOT NULL,
 snapshot_json jsonb NOT NULL,
 UNIQUE(user_id, client_snapshot_id)
);
CREATE INDEX seep_analysis_snapshots_user_uploaded ON seep_analysis_snapshots(user_id, uploaded_at DESC);
