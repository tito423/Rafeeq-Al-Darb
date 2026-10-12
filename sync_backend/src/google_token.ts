import { createLocalJWKSet, errors, jwtVerify, type JWTVerifyGetKey, type JSONWebKeySet } from 'jose';
import { readBoundedJson } from './request_body';

export const GOOGLE_CLIENT_ID = '227986327850-ha6gea87kueaeg2a3582ecpu3s0nbnh1.apps.googleusercontent.com';
const JWKS_URL = 'https://www.googleapis.com/oauth2/v3/certs';
const MAX_KEY_AGE_MS = 600_000;
const REFRESH_COOLDOWN_MS = 30_000;

function cacheLifetime(response: Response): number {
  const control = response.headers.get('cache-control') ?? '';
  if (/(?:^|,)\s*(?:no-store|no-cache)(?:\s|,|$)/i.test(control)) return 0;
  const match = /(?:^|,)\s*max-age\s*=\s*"?(\d+)/i.exec(control);
  const maxAge = match ? Number(match[1]) : 300;
  const age = Number(response.headers.get('age') ?? '0');
  if (!Number.isFinite(maxAge) || !Number.isFinite(age) || age < 0) return 0;
  return Math.min(MAX_KEY_AGE_MS, Math.max(0, maxAge - age) * 1000);
}

// Per-isolate cache. Optional transport/clock serve deterministic tests;
// production uses Google's fixed HTTPS URL and the actual clock.
export function createGoogleTokenVerifier(options: {
  fetch?: typeof fetch; now?: () => number;
} = {}): (token: string) => Promise<string | null> {
  const fetchKeys = options.fetch ?? globalThis.fetch.bind(globalThis);
  const now = options.now ?? Date.now;
  let local: ReturnType<typeof createLocalJWKSet> | undefined;
  let expiresAt = 0;
  let refreshedAt = -Infinity;
  let retryAt = 0;
  let pending: Promise<void> | undefined;

  async function refresh(): Promise<void> {
    if (pending) return pending;
    if (now() < retryAt) throw new Error('JWKS temporarily unavailable');
    pending = (async () => {
      const response = await fetchKeys(JWKS_URL, {
        signal: AbortSignal.timeout(5000), redirect: 'manual',
      });
      if (!response.ok) {
        await response.body?.cancel();
        throw new Error('JWKS request failed');
      }
      const body = await readBoundedJson(response, 65_536) as JSONWebKeySet;
      if (!body || !Array.isArray(body.keys) || !body.keys.length || body.keys.length > 100) {
        throw new Error('Invalid JWKS');
      }
      const next = createLocalJWKSet(body);
      local = next;
      refreshedAt = now();
      expiresAt = refreshedAt + cacheLifetime(response);
      retryAt = 0;
    })().catch((error) => {
      retryAt = now() + 5000;
      throw error;
    }).finally(() => { pending = undefined; });
    return pending;
  }

  const getKey: JWTVerifyGetKey = async (header, token) => {
    if (!local || now() >= expiresAt) await refresh();
    try {
      return await local!(header, token);
    } catch (error) {
      // Rotation must not let arbitrary kid values trigger endless fetches.
      if (!(error instanceof errors.JWKSNoMatchingKey) ||
          now() - refreshedAt < REFRESH_COOLDOWN_MS) throw error;
      await refresh();
      return local!(header, token);
    }
  };

  return async (token) => {
    try {
      if (token.length > 16_384) return null;
      const { payload } = await jwtVerify(token, getKey, {
        algorithms: ['RS256'], issuer: ['accounts.google.com', 'https://accounts.google.com'],
        audience: GOOGLE_CLIENT_ID, requiredClaims: ['sub', 'exp'],
        currentDate: new Date(now()),
      });
      if (payload.aud !== GOOGLE_CLIENT_ID || typeof payload.sub !== 'string' ||
          !payload.sub.length || payload.sub.length > 255 ||
          !Number.isSafeInteger(payload.exp)) return null;
      return payload.sub;
    } catch { return null; }
  };
}

export const verifyGoogleToken = createGoogleTokenVerifier();
