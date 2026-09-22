import { before, after, beforeEach, test } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { createPool } from '../src/database.js';
import { migrate } from '../src/migrate.js';
import { buildApp } from '../src/app.js';

// Required deliberately: never run destructive cleanup against DATABASE_URL.
if (!process.env.TEST_DATABASE_URL) throw new Error('Set TEST_DATABASE_URL to a disposable PostgreSQL database');
const pool = createPool(process.env.TEST_DATABASE_URL);
const adminKey = 'admin-test-key-'.repeat(4), uploadKey = 'upload-test-key-'.repeat(4);
const identities = new Map();
const app = buildApp({ pool, adminKey, uploadKey, allowLegacyUploads: true,
  verifyGoogle: async token => {
    if (!identities.has(token)) throw new Error('Invalid token');
    return identities.get(token);
  } });
const report = (overrides = {}) => ({
  user: { email: 'player@example.com', displayName: 'Player Name' },
  clientGameId: randomUUID(), appVersion: '0.10.0+10', platform: 'android',
  dealCount: 3, humanTeam: 0, winnerTeam: 0, userWon: true, team0Total: 152, team1Total: 91,
  summary: { deals: 3, totals: [152, 91], seeps: [4, 1] },
  gameLog: { v: 1, seed: 123, deals: [{ events: [['score', [74, 21]]] }] }, ...overrides,
});
function tokenFor(email, sub = email, name = null) {
  const token = randomUUID(); identities.set(token, {email: email.trim().toLowerCase(), sub, name}); return token;
}
const upload = body => app.inject({ method: 'POST', url: '/api/seep/reports',
  headers: { authorization: `Bearer ${tokenFor(body.user?.email ?? 'player@example.com', body.user?.email?.trim().toLowerCase(), body.user?.displayName ?? null)}` }, payload: body });
const admin = (url, method = 'GET', payload) => app.inject({ url, method, payload, headers: { 'x-api-key': adminKey } });

before(async () => { await migrate(pool); await migrate(pool); await app.ready(); });
beforeEach(async () => { identities.clear(); await pool.query('TRUNCATE seep_game_reports, seep_users CASCADE'); });
after(async () => { await app.close(); await pool.end(); });

test('schema uses only seep_ tables and has the required indexes', async () => {
  const tables = await pool.query("SELECT tablename FROM pg_tables WHERE schemaname='public'");
  assert.deepEqual(tables.rows.map(r => r.tablename).sort(), ['seep_analysis_snapshots', 'seep_game_reports', 'seep_schema_migrations', 'seep_users']);
  const indexes = await pool.query("SELECT indexdef FROM pg_indexes WHERE tablename IN ('seep_users','seep_game_reports')");
  assert(indexes.rows.some(r => r.indexdef.includes('(user_id, uploaded_at DESC)')));
  assert(indexes.rows.some(r => r.indexdef.includes('(user_id, user_won)')));
  assert(indexes.rows.some(r => r.indexdef.includes('WHERE (analysis_enabled = true)')));
});

test('insert, canonical email upsert, immutable duplicate and last_report_at', async () => {
  const body = report({ user: { email: ' Player@Example.com ', displayName: 'First' } });
  const first = await upload(body);
  assert.equal(first.statusCode, 201);
  const ids = first.json();
  const beforeRetry = (await pool.query('SELECT * FROM seep_users')).rows[0];
  const duplicate = await upload({ ...body, team0Total: 999, gameLog: { changed: true } });
  assert.equal(duplicate.statusCode, 200);
  assert.equal(duplicate.json().reportId, ids.reportId);
  const rows = await pool.query('SELECT * FROM seep_game_reports');
  assert.equal(rows.rowCount, 1);
  assert.equal(rows.rows[0].team0_total, 152);
  assert.deepEqual(rows.rows[0].game_log_json, body.gameLog);
  const user = (await pool.query('SELECT * FROM seep_users')).rows[0];
  assert.equal(user.email, 'player@example.com');
  assert.equal(user.analysis_enabled, false);
  assert.equal(+user.last_report_at, +beforeRetry.last_report_at);
  const second = await upload(report({ user: { email: 'player@example.com', displayName: 'New name' } }));
  assert.equal(second.json().userId, ids.userId);
  assert.equal((await pool.query('SELECT display_name FROM seep_users')).rows[0].display_name, 'New name');
});

test('simultaneous retries produce exactly one report', async () => {
  const body = report();
  const results = await Promise.all(Array.from({ length: 8 }, () => upload(body)));
  assert.equal(results.filter(r => r.statusCode === 201).length, 1);
  assert.equal(results.filter(r => r.statusCode === 200).length, 7);
  assert.equal(new Set(results.map(r => r.json().reportId)).size, 1);
  assert.equal((await pool.query('SELECT * FROM seep_game_reports')).rowCount, 1);
});

test('human win log is stored even when user analysis is disabled', async () => {
  const body = report();
  assert.equal((await upload(body)).statusCode, 201);
  const user = (await pool.query('SELECT analysis_enabled FROM seep_users')).rows[0];
  assert.equal(user.analysis_enabled, false);
  const stored = (await pool.query('SELECT game_log_json FROM seep_game_reports')).rows[0];
  assert.deepEqual(stored.game_log_json, body.gameLog);
});

test('same client id is scoped to user; deletion cascades', async () => {
  const body = report();
  const first = (await upload(body)).json();
  const second = await upload({ ...body, user: { email: 'other@example.com' } });
  assert.equal(second.statusCode, 201);
  assert.notEqual(second.json().userId, first.userId);
  await pool.query('DELETE FROM seep_users WHERE id=$1', [first.userId]);
  assert.equal((await pool.query('SELECT * FROM seep_game_reports')).rowCount, 1);
});

test('missing/wrong keys and cross-role keys are rejected before writes', async () => {
  for (const key of [undefined, adminKey, 'wrong']) {
    const response = await app.inject({ method: 'POST', url: '/api/seep/reports', payload: report(), headers: key ? { 'x-api-key': key } : {} });
    assert.equal(response.statusCode, 401);
  }
  assert.equal((await app.inject({ url: '/api/seep/admin/stats', headers: { 'x-api-key': uploadKey } })).statusCode, 401);
  assert.equal((await pool.query('SELECT * FROM seep_users')).rowCount, 0);
});

test('invalid/incomplete bodies and contradictory results are rejected', async () => {
  for (const change of [{ winnerTeam: null }, { dealCount: 0 }, { humanTeam: 2 },
    { userWon: false }, { userWon: 'true' }, { team0Total: -1 }, { summary: [] },
    { user: { email: 'bad-email' } }, { user: { email: 'a@b.com', analysisEnabled: true } },
    { liveState: {} }]) {
    assert.equal((await upload(report(change))).statusCode, 400, JSON.stringify(change));
  }
  assert.equal((await upload(report({ gameLog: { text: 'x'.repeat(2 * 1024 * 1024) } }))).statusCode, 413);
  assert.equal((await pool.query('SELECT * FROM seep_users')).rowCount, 0);
});

test('failed report insertion rolls back user and last_report_at changes', async () => {
  await pool.query(`CREATE FUNCTION seep_test_fail() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN RAISE EXCEPTION 'test failure'; END; $$`);
  await pool.query('CREATE TRIGGER seep_test_failure BEFORE INSERT ON seep_game_reports FOR EACH ROW EXECUTE FUNCTION seep_test_fail()');
  try {
    assert.equal((await upload(report())).statusCode, 503);
    assert.equal((await pool.query('SELECT * FROM seep_users')).rowCount, 0);
  } finally {
    await pool.query('DROP TRIGGER seep_test_failure ON seep_game_reports');
    await pool.query('DROP FUNCTION seep_test_fail()');
  }
});

test('stats count full games and recent uploads, rank wins with minimum games', async () => {
  const first = (await upload(report())).json();
  await upload(report({ winnerTeam: 1, userWon: false }));
  const other = (await upload(report({ user: { email: 'other@example.com' } }))).json();
  await pool.query("UPDATE seep_game_reports SET uploaded_at=now()-interval '31 days' WHERE id=$1", [other.reportId]);
  const response = await admin('/api/seep/admin/stats');
  assert.equal(response.statusCode, 200);
  const stats = response.json();
  assert.equal(stats.totalUsers, 2); assert.equal(stats.totalUploadedGames, 3);
  assert.equal(stats.gamesLast30Days, 2); assert.equal(stats.usersWithAtLeastOneWin, 2);
  assert.equal(stats.topUsers[0].userId, other.userId);
  assert.equal(stats.topUsers[0].winRate, 1);
  const filtered = (await admin('/api/seep/admin/stats?minGames=2')).json();
  assert.equal(filtered.topUsers.length, 1); assert.equal(filtered.topUsers[0].userId, first.userId);
  assert.equal(filtered.topUsers[0].winRate, .5);
});

test('analysis gates optional logs; reports are newest first and paginated', async () => {
  const older = (await upload(report())).json();
  await pool.query("UPDATE seep_game_reports SET uploaded_at=now()-interval '1 day' WHERE id=$1", [older.reportId]);
  const latest = (await upload(report())).json();
  const url = `/api/seep/admin/users/${older.userId}`;
  const page = (await admin(`${url}/reports?limit=1`)).json();
  assert.equal(page.reports[0].id, latest.reportId); assert.equal(page.nextOffset, 1);
  assert(!Object.hasOwn(page.reports[0], 'game_log_json'));
  assert.equal((await admin(`${url}/reports?includeGameLog=true&limit=10`)).statusCode, 403);
  assert.equal((await admin(`${url}/analysis`, 'PATCH', { analysisEnabled: 'true' })).statusCode, 400);
  assert.equal((await admin(`${url}/analysis`, 'PATCH', { analysisEnabled: true })).json().analysisEnabled, true);
  assert.equal((await admin(`${url}/reports?includeGameLog=true&limit=10`)).json().reports[0].game_log_json.v, 1);
  await admin(`${url}/analysis`, 'PATCH', { analysisEnabled: false });
  assert.equal((await admin(`${url}/reports?includeGameLog=true&limit=10`)).statusCode, 403);
  assert.equal((await admin(`/api/seep/admin/users/${randomUUID()}/reports`)).statusCode, 404);
  assert.equal((await admin('/api/seep/admin/users/not-a-uuid/reports')).statusCode, 400);
});

test('Google login persists verified identity; email changes keep the same account', async () => {
  const login = token => app.inject({method:'POST', url:'/api/seep/auth/google', headers:{authorization:`Bearer ${token}`}});
  const first = await login(tokenFor('first@gmail.com', 'google-123', 'Google Name'));
  assert.equal(first.statusCode, 200);
  const second = await login(tokenFor('new@gmail.com', 'google-123', 'Updated Name'));
  assert.equal(second.json().user.id, first.json().user.id);
  assert.equal(second.json().user.googleSubject, 'google-123');
  assert.equal(second.json().user.email, 'new@gmail.com');
  assert.equal((await pool.query('SELECT count(*)::int AS n FROM seep_users')).rows[0].n, 1);
});

test('forged email/subject and invalid bearer cannot impersonate another user', async () => {
  const token = tokenFor('owner@gmail.com', 'owner-sub', 'Verified Name');
  const send = body => app.inject({method:'POST', url:'/api/seep/reports', headers:{authorization:`Bearer ${token}`},payload:body});
  assert.equal((await send(report())).statusCode, 403);
  assert.equal((await send(report({user:{email:'owner@gmail.com',googleSubject:'other-sub'}}))).statusCode, 403);
  const valid = await send(report({user:{email:'owner@gmail.com',googleSubject:'owner-sub',displayName:'Forged Name'}}));
  assert.equal(valid.statusCode, 201);
  assert.equal((await pool.query('SELECT display_name FROM seep_users')).rows[0].display_name,'Verified Name');
  const invalid = await app.inject({method:'POST',url:'/api/seep/reports',payload:report(),
    headers:{authorization:'Bearer invalid', 'x-api-key':uploadKey}});
  assert.equal(invalid.statusCode,401);
  assert.equal((await app.inject({method:'POST',url:'/api/seep/auth/google',headers:{'x-api-key':uploadKey}})).statusCode,401);
});

test('legacy access is restricted to dummy account and disabled by default', async () => {
  assert.equal((await app.inject({method:'POST',url:'/api/seep/reports',headers:{'x-api-key':uploadKey},payload:report({user:{email:'real@gmail.com'}})})).statusCode,403);
  const secure = buildApp({pool, adminKey, uploadKey});
  try {
    assert.equal((await secure.inject({method:'POST',url:'/api/seep/reports',headers:{'x-api-key':uploadKey},payload:report()})).statusCode,401);
  } finally {await secure.close();}
});

test('analysis snapshots enforce eligibility, remain immutable and never count as games', async () => {
  const token=tokenFor('analyst@example.com');
  const headers={authorization:`Bearer ${token}`};
  const login=await app.inject({method:'POST',url:'/api/seep/auth/google',headers});
  const user=login.json().user;
  assert.equal(user.analysisEnabled,false);
  const payload={user:{email:user.email,googleSubject:user.googleSubject},clientGameId:'same-game',clientSnapshotId:randomUUID(),dealNumber:1,moveNumber:3,dealStatus:'in_progress',savedAt:new Date().toISOString(),appVersion:'test',botStrategy:'current',snapshot:{deal:{events:[]},state:{},decisions:[]}};
  const save=body=>app.inject({method:'POST',url:'/api/seep/analysis-snapshots',headers,payload:body});
  assert.equal((await save(payload)).statusCode,403);
  await admin(`/api/seep/admin/users/${user.id}/analysis`,'PATCH',{analysisEnabled:true});
  assert.equal((await app.inject({method:'POST',url:'/api/seep/auth/google',headers})).json().user.analysisEnabled,true);
  assert.equal((await save({...payload,user:{...payload.user,googleSubject:'other'}})).statusCode,403);
  assert.equal((await save({...payload,moveNumber:49})).statusCode,400);
  assert.equal((await save(payload)).statusCode,201);
  assert.equal((await save({...payload,moveNumber:4})).statusCode,200);
  assert.equal((await save({...payload,clientSnapshotId:randomUUID(),moveNumber:4})).statusCode,201);
  const snapshots=(await admin(`/api/seep/admin/users/${user.id}/analysis-snapshots`)).json().snapshots;
  assert.equal(snapshots.length,2);
  assert.equal(snapshots[1].move_number,3);
  assert.equal((await pool.query('SELECT count(*)::int AS n FROM seep_game_reports')).rows[0].n,0);
  await admin(`/api/seep/admin/users/${user.id}/analysis`,'PATCH',{analysisEnabled:false});
  assert.equal((await save({...payload,clientSnapshotId:randomUUID()})).statusCode,403);
});
