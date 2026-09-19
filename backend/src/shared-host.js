import { buildApp } from './app.js';
import { createPool } from './database.js';
import { migrate } from './migrate.js';

// Mounted by an existing Node HTTP server before its other API/auth handlers.
// Only Seep routes are handled here. The host keeps its port and health route.
let ready;
async function initialize() {
  const pool = createPool();
  let app;
  try {
    app = buildApp({ pool, adminKey: process.env.SEEP_ADMIN_API_KEY,
      uploadKey: process.env.SEEP_UPLOAD_API_KEY });
    await migrate(pool);
    await app.ready();
    return { app, pool };
  } catch (error) {
    if (app) await app.close();
    await pool.end();
    throw error;
  }
}

export async function handleSeepRequest(req, res, pathname) {
  if (pathname !== '/api/seep' && !pathname.startsWith('/api/seep/')) return false;
  try {
    ready ??= initialize().catch(error => { ready = undefined; throw error; });
    const { app } = await ready;
    app.routing(req, res);
  } catch {
    // A Seep configuration problem must not stop the existing application.
    res.writeHead(503, { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' });
    res.end(JSON.stringify({ error: 'Seep reporting unavailable; retry later' }));
  }
  return true;
}

export async function closeSeep() {
  if (!ready) return;
  const { app, pool } = await ready;
  await app.close();
  await pool.end();
  ready = undefined;
}
