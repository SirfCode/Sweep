-- Bind parameters; do not interpolate email/IDs supplied by a client.
SELECT count(*) FROM seep_users;
SELECT count(*) FROM seep_game_reports;
SELECT count(*) FROM seep_game_reports
 WHERE uploaded_at >= now() - interval '30 days';
SELECT count(DISTINCT user_id) FROM seep_game_reports WHERE user_won = true;

SELECT u.id, u.email, u.display_name, count(*) AS games,
       count(*) FILTER (WHERE r.user_won = true) AS wins,
       (count(*) FILTER (WHERE r.user_won = true))::float8 / count(*) AS win_rate
FROM seep_users u JOIN seep_game_reports r ON r.user_id = u.id
GROUP BY u.id
HAVING count(*) >= 5
ORDER BY win_rate DESC, games DESC, u.id
LIMIT 20;

-- Example report lookup (metadata only):
SELECT id, client_game_id, uploaded_at, user_won, team0_total, team1_total, summary_json
FROM seep_game_reports WHERE user_id = $1 ORDER BY uploaded_at DESC LIMIT 25;
