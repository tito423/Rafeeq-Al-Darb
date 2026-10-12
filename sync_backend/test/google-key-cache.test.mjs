import assert from 'node:assert/strict';
import { build } from 'esbuild';
import { fileURLToPath } from 'node:url';
import { before, test } from 'node:test';
import { exportJWK, generateKeyPair, SignJWT } from 'jose';

const bundle = await build({ entryPoints: [fileURLToPath(new URL('../src/google_token.ts', import.meta.url))],
  bundle: true, write: false, format: 'esm', target: 'es2022' });
const { createGoogleTokenVerifier, GOOGLE_CLIENT_ID } = await import(
  'data:text/javascript;base64,' + Buffer.from(bundle.outputFiles[0].text).toString('base64'));
let first;
let second;
let key1;
let key2;
before(async () => {
  [first, second] = await Promise.all([generateKeyPair('RS256'), generateKeyPair('RS256')]);
  key1 = { ...await exportJWK(first.publicKey), kid: 'cache-key-1', alg: 'RS256', use: 'sig' };
  key2 = { ...await exportJWK(second.publicKey), kid: 'cache-key-2', alg: 'RS256', use: 'sig' };
});

async function sign(pair = first, kid = 'cache-key-1', claims = {}) {
  return new SignJWT({ iss: 'https://accounts.google.com', aud: GOOGLE_CLIENT_ID,
    sub: 'cache-account', exp: Math.floor(Date.now() / 1000) + 3600, ...claims })
    .setProtectedHeader({ alg: 'RS256', kid }).sign(pair.privateKey);
}
function fixture(headers = { 'cache-control': 'max-age=300' }) {
  let time = Date.now();
  let response = () => Response.json({ keys: [key1] }, { headers });
  let calls = 0;
  const verify = createGoogleTokenVerifier({ now: () => time, fetch: async (url, init) => {
    assert.equal(url, 'https://www.googleapis.com/oauth2/v3/certs');
    assert.equal(init.redirect, 'manual');
    assert.ok(init.signal instanceof AbortSignal);
    calls++;
    await Promise.resolve();
    return response();
  } });
  return { verify, calls: () => calls, advance(ms) { time += ms; },
    response(value) { response = value; } };
}

test('A17 coalesces concurrent cold and expired key loads', async () => {
  const f = fixture();
  const token = await sign();
  for (const expected of [1, 2]) {
    const results = await Promise.all(Array.from({ length: 20 }, () => f.verify(token)));
    assert.deepEqual(results, Array(20).fill('cache-account'));
    assert.equal(f.calls(), expected);
    f.advance(300_000);
  }
});

test('A17 Cache-Control and Age expire exactly at the remaining lifetime', async () => {
  const f = fixture({ 'cache-control': 'public, max-age="300"', age: '100' });
  const token = await sign();
  assert.equal(await f.verify(token), 'cache-account');
  f.advance(199_999);
  assert.equal(await f.verify(token), 'cache-account');
  assert.equal(f.calls(), 1);
  f.advance(1);
  assert.equal(await f.verify(token), 'cache-account');
  assert.equal(f.calls(), 2);
});

for (const control of ['no-store, max-age=300', 'no-cache', 'max-age=0']) {
  test(`A17 ${control} does not reuse keys`, async () => {
    const f = fixture({ 'cache-control': control });
    const token = await sign();
    for (let i = 0; i < 2; i++) assert.equal(await f.verify(token), 'cache-account');
    assert.equal(f.calls(), 2);
  });
}

test('A17 caps remote lifetime at ten minutes and defaults missing header to five', async () => {
  for (const [headers, lifetime] of [[{ 'cache-control': 'max-age=86400' }, 600_000], [{}, 300_000]]) {
    const f = fixture(headers);
    const token = await sign();
    assert.equal(await f.verify(token), 'cache-account');
    f.advance(lifetime);
    assert.equal(await f.verify(token), 'cache-account');
    assert.equal(f.calls(), 2);
  }
});

test('A17 rotation refreshes after cooldown and arbitrary kid misses stay bounded', async () => {
  const f = fixture();
  assert.equal(await f.verify(await sign()), 'cache-account');
  f.response(() => Response.json({ keys: [key2] }, { headers: { 'cache-control': 'max-age=300' } }));
  const rotated = await sign(second, 'cache-key-2');
  assert.equal(await f.verify(rotated), null);
  assert.equal(f.calls(), 1);
  f.advance(30_000);
  assert.equal(await f.verify(rotated), 'cache-account');
  assert.equal(f.calls(), 2);
  for (let i = 0; i < 8; i++) assert.equal(await f.verify(await sign(first, `unknown-${i}`)), null);
  assert.equal(f.calls(), 2);
});

test('A17 expired cache and cold outage fail closed with bounded retry', async () => {
  const f = fixture({ 'cache-control': 'max-age=1' });
  const token = await sign();
  assert.equal(await f.verify(token), 'cache-account');
  f.response(() => new Response('unavailable', { status: 503 }));
  assert.equal(await f.verify(token), 'cache-account');
  f.advance(1000);
  assert.equal(await f.verify(token), null);
  assert.equal(await f.verify(token), null);
  assert.equal(f.calls(), 2);
  f.advance(5000);
  assert.equal(await f.verify(token), null);
  assert.equal(f.calls(), 3);
  const cold = fixture();
  cold.response(() => { throw new Error('network down'); });
  assert.equal(await cold.verify(token), null);
  assert.equal(await cold.verify(token), null);
  assert.equal(cold.calls(), 1);
});

test('A17 rejects redirected, oversized and malformed key responses', async () => {
  for (const response of [
    () => new Response(null, { status: 302, headers: { location: 'https://invalid.example' } }),
    () => Response.json({ keys: [key1], padding: 'x'.repeat(65_536) }),
    () => Response.json({ keys: [] }),
    () => new Response('{'),
  ]) {
    const f = fixture(); f.response(response);
    assert.equal(await f.verify(await sign()), null);
  }
});

for (const [label, claims] of [['missing expiry', { exp: undefined }], ['string expiry', { exp: '9999999999' }],
  ['missing sub', { sub: undefined }], ['empty sub', { sub: '' }],
  ['oversized sub', { sub: 'x'.repeat(256) }], ['future nbf', { nbf: Math.floor(Date.now() / 1000) + 500 }]]) {
  test(`A17 rejects ${label} even with a valid signature`, async () => {
    assert.equal(await fixture().verify(await sign(first, 'cache-key-1', claims)), null);
  });
}

test('A17 malformed and unsigned tokens are rejected', async () => {
  const f = fixture();
  for (const token of ['', 'not-a-jwt', 'x'.repeat(16_385),
    Buffer.from('{"alg":"none"}').toString('base64url') + '.' + Buffer.from('{}').toString('base64url') + '.']) {
    assert.equal(await f.verify(token), null);
  }
  assert.equal(f.calls(), 0);
});
