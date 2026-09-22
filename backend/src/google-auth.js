import { OAuth2Client } from 'google-auth-library';

export function googleVerifier(audience, client = new OAuth2Client()) {
  return async token => {
    if (!audience) throw new Error('Google sign-in is not configured');
    const ticket = await client.verifyIdToken({ idToken: token, audience });
    const p = ticket.getPayload();
    // The library verifies Google's signature, audience, issuer and expiry.
    if (!p?.sub || p.email_verified !== true || !p.email ||
        !['accounts.google.com', 'https://accounts.google.com'].includes(p.iss) ||
        p.aud !== audience || !p.exp || p.exp <= Date.now() / 1000) {
      throw new Error('Invalid Google identity');
    }
    return { sub: p.sub, email: p.email.toLowerCase(), name: p.name ?? null };
  };
}

export async function googleUser(client, identity) {
  // Stable Google subject is the identity; email is only a verified attribute.
  const existing = await client.query('SELECT id FROM seep_users WHERE google_sub=$1 FOR UPDATE', [identity.sub]);
  if (existing.rowCount) {
    const result = await client.query(`UPDATE seep_users SET email=$2, display_name=$3
      WHERE id=$1 RETURNING id, email, display_name AS "displayName", google_sub AS "googleSubject", analysis_enabled AS "analysisEnabled"`,
    [existing.rows[0].id, identity.email, identity.name]);
    return result.rows[0];
  }
  const result = await client.query(`INSERT INTO seep_users(email, display_name, google_sub)
    VALUES ($1,$2,$3) ON CONFLICT(email) DO UPDATE
    SET google_sub=EXCLUDED.google_sub, display_name=EXCLUDED.display_name
    WHERE seep_users.google_sub IS NULL OR seep_users.google_sub=EXCLUDED.google_sub
    RETURNING id, email, display_name AS "displayName", google_sub AS "googleSubject", analysis_enabled AS "analysisEnabled"`,
  [identity.email, identity.name, identity.sub]);
  if (!result.rowCount) {
    const error = new Error('Account conflict'); error.statusCode = 409; throw error;
  }
  return result.rows[0];
}
