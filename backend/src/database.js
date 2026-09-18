import pg from 'pg';

export function createPool(connectionString = process.env.DATABASE_URL) {
  if (!connectionString) throw new Error('DATABASE_URL is required');
  const pool = new pg.Pool({
    connectionString,
    max: 5,
    connectionTimeoutMillis: 5000,
    idleTimeoutMillis: 30000,
    statement_timeout: 15000,
    idle_in_transaction_session_timeout: 15000,
  });
  // No connection strings, request bodies, or emails in operational logs.
  pool.on('error', () => console.error('Database pool connection failed'));
  return pool;
}

export async function transaction(pool, action) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const result = await action(client);
    await client.query('COMMIT');
    return result;
  } catch (error) {
    await client.query('ROLLBACK').catch(() => {});
    throw error;
  } finally {
    client.release();
  }
}
