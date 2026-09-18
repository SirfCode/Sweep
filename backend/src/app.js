import Fastify, { LogController } from 'fastify';
import { createHash, timingSafeEqual } from 'node:crypto';
import { transaction } from './database.js';
import { reportBody, reportsQuery, statsQuery, userParams } from './schema.js';

const digest = value => createHash('sha256').update(value).digest();
function auth(key) {
  const expected = digest(key);
  return async (request, reply) => {
    const supplied = request.headers['x-api-key'];
    if (typeof supplied !== 'string' || !timingSafeEqual(digest(supplied), expected)) {
      return reply.code(401).send({ error: 'Unauthorized' });
    }
  };
}

export function buildApp({ pool, adminKey, uploadKey, logger = false }) {
  if (!adminKey || !uploadKey || adminKey.length < 32 || uploadKey.length < 32 || adminKey === uploadKey) {
    throw new Error('Distinct ADMIN_API_KEY and SEEP_UPLOAD_API_KEY of at least 32 characters are required');
  }
  const app = Fastify({
    logger, logController: new LogController({ disableRequestLogging: true }), bodyLimit: 2 * 1024 * 1024,
    requestTimeout: 30000,
    ajv: { customOptions: { coerceTypes: false, removeAdditional: false } },
  });
  app.addHook('onSend', async (_request, reply, payload) => {
    reply.header('Cache-Control', 'no-store');
    reply.header('X-Content-Type-Options', 'nosniff');
    return payload;
  });
  app.setErrorHandler((error, request, reply) => {
    if (error.validation) return reply.code(400).send({ error: 'Invalid request', details: error.validation.map(v => ({ path: v.instancePath, message: v.message })) });
    if (error.statusCode && error.statusCode < 500) {
      return reply.code(error.statusCode).send({ error: error.statusCode === 413 ? 'Report exceeds 2 MiB limit' : 'Invalid request' });
    }
    request.log.error({ requestId: request.id, code: error.code ?? 'INTERNAL' }, 'Request failed');
    return reply.code(503).send({ error: 'Service unavailable; retry later' });
  });
  app.get('/health', async (_request, reply) => {
    try { await pool.query('SELECT 1'); return { status: 'ok' }; }
    catch { return reply.code(503).send({ status: 'unavailable' }); }
  });

  app.post('/api/seep/reports', { onRequest: auth(uploadKey), schema: { body: reportBody } }, async (request, reply) => {
    const b = request.body;
    const userWon = b.winnerTeam === b.humanTeam;
    if (b.userWon !== undefined && b.userWon !== userWon) {
      return reply.code(400).send({ error: 'userWon must agree with humanTeam and winnerTeam' });
    }
    const result = await transaction(pool, async client => {
      const user = await client.query(`INSERT INTO seep_users(email, display_name) VALUES ($1, $2)
        ON CONFLICT(email) DO UPDATE SET display_name=COALESCE(EXCLUDED.display_name, seep_users.display_name)
        RETURNING id`, [b.user.email.trim().toLowerCase(), b.user.displayName?.trim() || null]);
      const userId = user.rows[0].id;
      const inserted = await client.query(`INSERT INTO seep_game_reports
        (user_id, client_game_id, app_version, platform, deal_count, human_team, winner_team,
         user_won, team0_total, team1_total, summary_json, game_log_json)
        VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12)
        ON CONFLICT(user_id, client_game_id) DO NOTHING RETURNING id, uploaded_at`,
        [userId, b.clientGameId, b.appVersion ?? null, b.platform ?? null, b.dealCount,
          b.humanTeam, b.winnerTeam, userWon, b.team0Total, b.team1Total,
          JSON.stringify(b.summary), b.gameLog == null ? null : JSON.stringify(b.gameLog)]);
      if (inserted.rowCount) {
        await client.query('UPDATE seep_users SET last_report_at=$2 WHERE id=$1', [userId, inserted.rows[0].uploaded_at]);
        return { reportId: inserted.rows[0].id, userId, duplicate: false };
      }
      const existing = await client.query('SELECT id FROM seep_game_reports WHERE user_id=$1 AND client_game_id=$2', [userId, b.clientGameId]);
      return { reportId: existing.rows[0].id, userId, duplicate: true };
    });
    return reply.code(result.duplicate ? 200 : 201).send(result);
  });

  app.get('/api/seep/admin/stats', { onRequest: auth(adminKey), schema: { querystring: statsQuery } }, async (request, reply) => {
    const limit = Number(request.query.limit);
    if (limit > 100) return reply.code(400).send({ error: 'limit must be at most 100' });
    const counts = await pool.query(`SELECT
      (SELECT count(*)::int FROM seep_users) AS "totalUsers",
      count(*)::int AS "totalUploadedGames",
      count(*) FILTER (WHERE uploaded_at >= now() - interval '30 days')::int AS "gamesLast30Days",
      count(DISTINCT user_id) FILTER (WHERE user_won = true)::int AS "usersWithAtLeastOneWin"
      FROM seep_game_reports`);
    const top = await pool.query(`SELECT u.id AS "userId", u.email, u.display_name AS "displayName",
      count(*)::int AS games, count(*) FILTER (WHERE r.user_won = true)::int AS wins,
      (count(*) FILTER (WHERE r.user_won = true))::float8 / count(*) AS "winRate"
      FROM seep_users u JOIN seep_game_reports r ON r.user_id=u.id
      GROUP BY u.id HAVING count(*) >= $1
      ORDER BY "winRate" DESC, games DESC, u.id LIMIT $2`, [Number(request.query.minGames), limit]);
    return { ...counts.rows[0], topUsers: top.rows };
  });

  app.patch('/api/seep/admin/users/:id/analysis', {
    onRequest: auth(adminKey), schema: { params: userParams, body: {
      type: 'object', additionalProperties: false, required: ['analysisEnabled'],
      properties: { analysisEnabled: { type: 'boolean' } },
    } },
  }, async (request, reply) => {
    const result = await pool.query('UPDATE seep_users SET analysis_enabled=$2 WHERE id=$1 RETURNING id, analysis_enabled AS "analysisEnabled"', [request.params.id, request.body.analysisEnabled]);
    return result.rowCount ? result.rows[0] : reply.code(404).send({ error: 'User not found' });
  });

  app.get('/api/seep/admin/users/:id/reports', {
    onRequest: auth(adminKey), schema: { params: userParams, querystring: reportsQuery },
  }, async (request, reply) => {
    const include = request.query.includeGameLog === 'true';
    const limit = Number(request.query.limit ?? (include ? '10' : '25')), offset = Number(request.query.offset);
    if (limit > 100 || offset > 1000000 || (include && limit > 10)) {
      return reply.code(400).send({ error: 'Use limit <=100 (<=10 with logs) and offset <=1000000' });
    }
    return transaction(pool, async client => {
      const user = await client.query('SELECT analysis_enabled FROM seep_users WHERE id=$1 FOR SHARE', [request.params.id]);
      if (!user.rowCount) return reply.code(404).send({ error: 'User not found' });
      if (include && !user.rows[0].analysis_enabled) return reply.code(403).send({ error: 'Enable analysis for this user before requesting game logs' });
      const reports = await client.query(`SELECT id, user_id, client_game_id, app_version, platform,
        uploaded_at, deal_count, human_team, winner_team, user_won, team0_total, team1_total, summary_json
        ${include ? ', game_log_json' : ''}
        FROM seep_game_reports WHERE user_id=$1 ORDER BY uploaded_at DESC, id DESC LIMIT $2 OFFSET $3`,
        [request.params.id, limit + 1, offset]);
      return { reports: reports.rows.slice(0, limit), limit, offset,
        nextOffset: reports.rows.length > limit ? offset + limit : null };
    });
  });
  return app;
}
