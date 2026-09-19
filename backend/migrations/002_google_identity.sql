ALTER TABLE seep_users ADD COLUMN google_sub text;
CREATE UNIQUE INDEX seep_users_google_sub_idx ON seep_users(google_sub)
    WHERE google_sub IS NOT NULL;
