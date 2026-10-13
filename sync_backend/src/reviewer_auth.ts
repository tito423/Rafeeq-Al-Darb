// Reviewers have no account and no list (owner, 2026-10-13): the owner sends
// the link, a reviewer writes his name and starts. A-03 was that anyone could
// then post under ANY name. So the first device to register a name gets a
// random key for it, kept in that browser; writes under the name need the key.
// Only the key's SHA-256 is stored, so the table cannot be replayed.

const TOKEN_BYTES = 32;

function hex(bytes: ArrayBuffer): string {
  return Array.from(new Uint8Array(bytes), (b) => b.toString(16).padStart(2, '0')).join('');
}

export async function hashToken(token: string): Promise<string> {
  return hex(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(token)));
}

export function newToken(): string {
  const bytes = crypto.getRandomValues(new Uint8Array(TOKEN_BYTES));
  return btoa(String.fromCharCode(...bytes)).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

export function bearer(request: Request): string | null {
  const header = request.headers.get('Authorization');
  if (!header?.startsWith('Bearer ')) return null;
  const token = header.slice(7).trim();
  // A real key is 43 base64url characters; reject anything else unhashed.
  return /^[A-Za-z0-9_-]{43}$/.test(token) ? token : null;
}

export const REVIEWER_TABLE = `CREATE TABLE IF NOT EXISTS review_reviewers (
  name TEXT PRIMARY KEY,
  token_hash TEXT NOT NULL UNIQUE,
  created_at INTEGER NOT NULL
)`;

/** The name a key was issued for, or null. */
export async function reviewerFor(db: D1Database, token: string | null): Promise<string | null> {
  if (!token) return null;
  const row = await db.prepare('SELECT name FROM review_reviewers WHERE token_hash = ?')
    .bind(await hashToken(token)).first<{ name: string }>();
  return row?.name ?? null;
}

/** Claims [name] for a new key; null when the name is already someone's. */
export async function register(db: D1Database, name: string): Promise<string | null> {
  const token = newToken();
  const result = await db.prepare(
    'INSERT INTO review_reviewers (name, token_hash, created_at) VALUES (?, ?, ?) ON CONFLICT(name) DO NOTHING'
  ).bind(name, await hashToken(token), Date.now()).run();
  return result.meta.changes === 1 ? token : null;
}
