ALTER TABLE seep_users ADD COLUMN country_code text
    CHECK (country_code IS NULL OR country_code ~ '^[A-Z]{2}$');

ALTER TABLE seep_users ADD COLUMN locale text
    CHECK (locale IS NULL OR locale ~ '^[A-Za-z]{2,3}([-_][A-Za-z0-9]{2,8}){0,2}$');
