import { readFile, readdir } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { pathToFileURL } from 'node:url';
import { createPool } from './database.js';

export async function migrate(pool) {
  const client = await pool.connect();
  try {
    // Serialize migration runners from overlapping service starts.
    await client.query('SELECT pg_advisory_lock(731042001)');
    await client.query(`CREATE TABLE IF NOT EXISTS seep_schema_migrations (
      name text PRIMARY KEY, checksum text NOT NULL,
      applied_at timestamptz NOT NULL DEFAULT now())`);
    const directory = new URL('../migrations/', import.meta.url);
    for (const name of (await readdir(directory)).filter(n => n.endsWith('.sql')).sort()) {
      const sql = (await readFile(new URL(name, directory), 'utf8')).replaceAll('\r\n', '\n');
      const checksum = createHash('sha256').update(sql).digest('hex');
      const existing = await client.query('SELECT checksum FROM seep_schema_migrations WHERE name=$1', [name]);
      if (existing.rowCount) {
        if (existing.rows[0].checksum !== checksum) throw new Error(`Applied migration changed: ${name}`);
        continue;
      }
      await client.query('BEGIN');
      try {
        await client.query(sql);
        await client.query('INSERT INTO seep_schema_migrations(name, checksum) VALUES ($1, $2)', [name, checksum]);
        await client.query('COMMIT');
      } catch (error) {
        await client.query('ROLLBACK');
        throw error;
      }
    }
  } finally {
    await client.query('SELECT pg_advisory_unlock(731042001)').catch(() => {});
    client.release();
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const pool = createPool();
  try { await migrate(pool); console.log('Seep migrations applied'); }
  catch { console.error('Seep migration failed; check database access and migration checksums'); process.exitCode = 1; }
  finally { await pool.end(); }
}
