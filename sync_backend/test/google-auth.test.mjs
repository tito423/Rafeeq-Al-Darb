import assert from 'node:assert/strict';
import { after, before, test } from 'node:test';
import { createGoogleAuthWorker } from '../test-support/google-auth-worker.mjs';

let worker;
before(async () => { worker = await createGoogleAuthWorker(); });
after(async () => { await worker?.stop(); });

async function get(token) {
  return worker.runtime.dispatchFetch('http://127.0.0.1/sync', {
    headers: { Authorization: `Bearer ${token}` },
  });
}

test('A17 actual Worker verifies signatures locally and fetches JWKS once', async () => {
  const token = await worker.sign();
  const responses = await Promise.all(Array.from({ length: 8 }, () => get(token)));
  for (const response of responses) {
    assert.equal(response.status, 200);
    assert.deepEqual(await response.json(), { state: [], counters: [] });
  }
  assert.equal(worker.calls.tokeninfo, 0, 'A real JWT must never be sent to tokeninfo');
  assert.equal(worker.calls.jwks, 1);
});

test('A17 warm cached keys keep valid sync working during Google HTTP outage', async () => {
  const token = await worker.sign();
  assert.equal((await get(token)).status, 200);
  worker.setOffline(true);
  try { assert.equal((await get(token)).status, 200); }
  finally { worker.setOffline(false); }
});

for (const [label, claims] of [
  ['wrong issuer', { iss: 'https://invalid.example' }],
  ['wrong audience', { aud: 'other-client' }],
  ['expired', { exp: Math.floor(Date.now() / 1000) - 1 }],
]) {
  test(`A17 ${label} is rejected`, async () => {
    assert.equal((await get(await worker.sign(claims))).status, 401);
  });
}

test('A17 signed payload tampering is rejected', async () => {
  const segments = (await worker.sign()).split('.');
  const payload = JSON.parse(Buffer.from(segments[1], 'base64url'));
  payload.sub = 'another-account';
  segments[1] = Buffer.from(JSON.stringify(payload)).toString('base64url');
  assert.equal((await get(segments.join('.'))).status, 401);
});

test('A17 both documented Google issuers remain accepted', async () => {
  assert.equal((await get(await worker.sign({ iss: 'accounts.google.com' }))).status, 200);
});
