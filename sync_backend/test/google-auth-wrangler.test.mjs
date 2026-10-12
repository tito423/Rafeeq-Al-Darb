import assert from 'node:assert/strict';
import { after, before, test } from 'node:test';
import { fileURLToPath } from 'node:url';
import { exportJWK, generateKeyPair, SignJWT } from 'jose';
import { startLocalWorker } from '../test-support/local-worker.mjs';
import { clientId } from '../test-support/google-auth-worker.mjs';

let worker;
let token;
before(async () => {
  const pair = await generateKeyPair('RS256');
  const key = { ...await exportJWK(pair.publicKey), kid: 'wrangler-test-only', alg: 'RS256', use: 'sig' };
  token = await new SignJWT({ sub: 'wrangler-local-account', aud: clientId,
    iss: 'https://accounts.google.com', exp: Math.floor(Date.now() / 1000) + 3600 })
    .setProtectedHeader({ alg: 'RS256', kid: key.kid }).sign(pair.privateKey);
  worker = await startLocalWorker({ entrypoint: fileURLToPath(
    new URL('../test-support/google-token-worker.ts', import.meta.url)) });
  const response = await fetch(worker.base + '/test-control', { method: 'POST',
    body: JSON.stringify({ keys: { keys: [key] } }) });
  assert.equal(response.status, 200);
});
after(async () => { await worker?.stop(); });

test('A17 Wrangler dev executes actual JOSE signature verification and warm outage cache', async () => {
  const verify = async (value) => fetch(worker.base + '/verify', { method: 'POST', body: value });
  for (let attempt = 0; attempt < 2; attempt++) {
    const response = await verify(token);
    assert.equal(response.status, 200);
    assert.deepEqual(await response.json(), { subject: 'wrangler-local-account', keyRequests: 1 });
  }
  assert.equal((await fetch(worker.base + '/test-control', { method: 'POST',
    body: JSON.stringify({ offline: true }) })).status, 200);
  assert.equal((await verify(token)).status, 200);
  const parts = token.split('.');
  parts[1] = Buffer.from(JSON.stringify({ sub: 'tampered' })).toString('base64url');
  assert.equal((await verify(parts.join('.'))).status, 401);
});
