CREATE TABLE seep_users (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    email text NOT NULL UNIQUE,
    display_name text,
    analysis_enabled boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now(),
    last_report_at timestamptz
);

CREATE TABLE seep_game_reports (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES seep_users(id) ON DELETE CASCADE,
    client_game_id text NOT NULL,
    app_version text,
    platform text,
    uploaded_at timestamptz NOT NULL DEFAULT now(),
    deal_count integer CHECK (deal_count > 0),
    human_team smallint NOT NULL DEFAULT 0 CHECK (human_team IN (0, 1)),
    winner_team smallint CHECK (winner_team IN (0, 1)),
    user_won boolean,
    team0_total integer CHECK (team0_total >= 0),
    team1_total integer CHECK (team1_total >= 0),
    summary_json jsonb NOT NULL DEFAULT '{}'::jsonb,
    game_log_json jsonb,
    UNIQUE (user_id, client_game_id)
);

CREATE INDEX seep_game_reports_user_uploaded_idx
    ON seep_game_reports (user_id, uploaded_at DESC);
CREATE INDEX seep_game_reports_user_won_idx
    ON seep_game_reports (user_id, user_won);
CREATE INDEX seep_users_analysis_enabled_idx
    ON seep_users (analysis_enabled) WHERE analysis_enabled = true;
