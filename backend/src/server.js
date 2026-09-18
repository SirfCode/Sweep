import { createPool } from './database.js';
import { buildApp } from './app.js';

const pool = createPool();
const app = buildApp({ pool, adminKey: process.env.ADMIN_API_KEY, uploadKey: process.env.SEEP_UPLOAD_API_KEY,
  logger: { level: 'info', redact: ['req.headers', 'req.body', 'res.headers'] } });
let closing = false;
async function shutdown() {
  if (closing) return;
  closing = true;
  await app.close();
  await pool.end();
}
for (const signal of ['SIGTERM', 'SIGINT']) process.once(signal, () => {
  shutdown().catch(() => { process.exitCode = 1; });
});
try { await app.listen({ host: process.env.HOST ?? '0.0.0.0', port: Number(process.env.PORT ?? 10000) }); }
catch { console.error('Seep API failed to start'); await pool.end(); process.exitCode = 1; }
