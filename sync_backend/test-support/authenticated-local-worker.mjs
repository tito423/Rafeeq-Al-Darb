import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';
import { exportJWK, generateKeyPair, SignJWT } from 'jose';
import { clientId } from './google-auth-worker.mjs';
import { startLocalWorker } from './local-worker.mjs';

// Only the Google key transport is controlled. The actual Worker enforces
// signatures, grants and D1 behavior; no auth bypass is added to production.
export async function startAuthenticatedLocalWorker(names, { adminNames = [] } = {}) {
  const pair = await generateKeyPair('RS256');
  const key = { ...await exportJWK(pair.publicKey), kid: 'A03-local-test', alg: 'RS256', use: 'sig' };
  const tokens = new Map();
  const reviewers = [];
  for (const name of names) {
    const sub = `audit-role:${name}`;
    reviewers.push({ sub, name, role: adminNames.includes(name) ? 'admin' : 'reviewer' });
    tokens.set(name, await new SignJWT({ sub, iss: 'https://accounts.google.com', aud: clientId,
      exp: Math.floor(Date.now() / 1000) + 3600 }).setProtectedHeader({ alg: 'RS256', kid: key.kid }).sign(pair.privateKey));
  }
  const worker = await startLocalWorker({ entrypoint: fileURLToPath(
    new URL('./authenticated-worker.ts', import.meta.url)) });
  try {
    const response = await fetch(worker.base + '/_test/setup', { method: 'POST',
      body: JSON.stringify({ keys: { keys: [key] }, reviewers }) });
    assert.equal(response.status, 200);
    return { ...worker, headersFor(name) {
      assert.ok(tokens.has(name), 'Missing explicit test reviewer grant');
      return { Authorization: `Bearer ${tokens.get(name)}` };
    } };
  } catch (error) { await worker.stop(); throw error; }
}
