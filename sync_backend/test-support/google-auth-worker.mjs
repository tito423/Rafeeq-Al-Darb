import assert from 'node:assert/strict';
import { build } from 'esbuild';
import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { Miniflare, convertV4MiniflareOptions } from 'miniflare';
import { exportJWK, generateKeyPair, SignJWT, jwtVerify } from 'jose';

export const clientId = '227986327850-ha6gea87kueaeg2a3582ecpu3s0nbnh1.apps.googleusercontent.com';

// Test-only generated signing keys. No production key or token is read.
export async function createGoogleAuthWorker() {
  const pair = await generateKeyPair('RS256');
  const jwk = { ...await exportJWK(pair.publicKey), kid: 'A17-test-key', alg: 'RS256', use: 'sig' };
  const calls = { jwks: 0, tokeninfo: 0 };
  let offline = false;
  const bundle = await build({ entryPoints: [fileURLToPath(new URL('../src/index.ts', import.meta.url))],
    bundle: true, write: false, format: 'esm', target: 'es2022' });
  const runtime = new Miniflare(convertV4MiniflareOptions({
    script: bundle.outputFiles[0].text, modules: true,
    compatibilityDate: '2024-09-09', d1Databases: ['DB'],
    outboundService: async (request) => {
      const url = new URL(request.url);
      if (url.origin === 'https://www.googleapis.com' && url.pathname === '/oauth2/v3/certs') {
        calls.jwks++;
        assert.equal(url.search, '');
        return offline ? new Response('offline', { status: 503 }) :
          Response.json({ keys: [jwk] }, { headers: { 'cache-control': 'public, max-age=3600' } });
      }
      // Baseline transport emulates tokeninfo by ACTUALLY checking the test
      // signature and claims. It does not declare arbitrary JWTs valid.
      assert.equal(url.origin, 'https://oauth2.googleapis.com');
      assert.equal(url.pathname, '/tokeninfo');
      calls.tokeninfo++;
      if (offline) return new Response('offline', { status: 503 });
      try {
        const { payload } = await jwtVerify(url.searchParams.get('id_token'), pair.publicKey, {
          algorithms: ['RS256'], audience: clientId,
          issuer: ['accounts.google.com', 'https://accounts.google.com'],
          requiredClaims: ['sub', 'exp'],
        });
        return Response.json({ ...payload, exp: String(payload.exp) });
      } catch { return new Response('invalid', { status: 400 }); }
    },
  }));
  const database = await runtime.getD1Database('DB');
  const schema = await readFile(new URL('../schema.sql', import.meta.url), 'utf8');
  for (const statement of schema.split(';').filter((part) => part.trim())) {
    await database.prepare(statement).run();
  }
  const sign = async (claims = {}, header = {}) => new SignJWT({
    iss: 'https://accounts.google.com', sub: 'audit-A06-local', aud: clientId,
    exp: Math.floor(Date.now() / 1000) + 3600, ...claims,
  }).setProtectedHeader({ alg: 'RS256', kid: jwk.kid, ...header }).sign(pair.privateKey);
  return { runtime, database, sign, calls, setOffline(value) { offline = value; },
    stop: () => runtime.dispose() };
}
