import assert from 'node:assert/strict';
import { test } from 'node:test';
import '../review-client/auth.js';
const { create, messages } = globalThis.RafeeqReviewAuth;
const api = 'https://rafeeq-sync-backend.int-vip00.workers.dev/review';
const clientId = '227986327850-ha6gea87kueaeg2a3582ecpu3s0nbnh1.apps.googleusercontent.com';
const profile = (sub, reviewer) => ({ sub, reviewer, role: 'reviewer' });
function storage(seed = {}) {
  const values = new Map(Object.entries(seed));
  return { values, getItem: (key) => values.get(key) ?? null,
    setItem(key, value) { values.set(key, String(value)); } };
}
function client(store, fetch, extra = {}) { return create({ api, clientId, storage: store, fetch, ...extra }); }

test('A03 client retains exact legacy notes and migrates only matching canonical name', async () => {
  const original = JSON.stringify({ own: { c: 'Local ownership regression', ok: true, e: 'Unmodified excerpt' } });
  const store = storage({ review: original, reviewer: 'canonical-one' });
  const session = client(store, async () => Response.json(profile('subject-one', 'canonical-one')));
  await session.authorize('test-only-credential');
  assert.equal(store.getItem('review'), original);
  assert.equal(store.getItem('reviewer'), 'canonical-one');
  assert.deepEqual(session.notes, JSON.parse(original));
  assert.equal(store.getItem('review_account_v1:subject-one'), original);
  for (const value of store.values.values()) assert.ok(!value.includes('test-only-credential'));
});

test('A03 different account never adopts or deletes another account or legacy notes', async () => {
  const original = JSON.stringify({ original: { c: 'Keep this legacy note', ok: true } });
  const store = storage({ review: original, reviewer: 'canonical-one' });
  let next = profile('subject-two', 'canonical-two');
  const session = client(store, async () => Response.json(next));
  await session.authorize('second-test-token');
  assert.deepEqual(session.notes, {});
  assert.equal(session.hasDifferentLegacy(), true);
  assert.equal(session.legacyExport(), original);
  session.save({ second: { c: 'Other account note' } });
  next = profile('subject-one', 'canonical-one');
  await session.authorize('first-test-token');
  assert.deepEqual(session.notes, JSON.parse(original));
  assert.deepEqual(JSON.parse(store.getItem('review_account_v1:subject-two')), { second: { c: 'Other account note' } });
  assert.equal(store.getItem('review'), original);
});

test('A03 bearer header is sent only to the review API and never persisted', async () => {
  const store = storage();
  let calls = 0;
  const session = client(store, async (url, init) => {
    calls++;
    if (url.endsWith('/me')) {
      assert.equal(init.headers.Authorization, 'Bearer memory-only-test-token');
      return Response.json(profile('subject', 'canonical'));
    }
    assert.equal(init.headers.get('Authorization'), 'Bearer memory-only-test-token');
    return Response.json({ saved: 1 });
  });
  await session.authorize('memory-only-test-token');
  await session.request(api, { method: 'POST', body: '{}' });
  await assert.rejects(session.request('https://invalid.example/review'));
  assert.equal(calls, 2);
  assert.ok(!JSON.stringify([...store.values]).includes('memory-only-test-token'));
});

test('A03 reopened and offline client preserves scoped notes without pretending to be signed in', async () => {
  const store = storage();
  const session = client(store, async () => Response.json(profile('subject', 'canonical')));
  await session.authorize('test-token');
  session.save({ note: { c: 'Offline saved note' } });
  let network = 0;
  const reopened = client(store, async () => { network++; throw new Error('offline'); });
  assert.equal(reopened.signedIn, false);
  assert.deepEqual(reopened.notes, { note: { c: 'Offline saved note' } });
  await assert.rejects(reopened.request(api), (error) => error.status === 401);
  assert.equal(network, 0);
});

test('A03 401/403 preserve notes and require reauthentication, 429 honors Retry-After', async () => {
  for (const status of [401, 403, 429, 503]) {
    const store = storage(); let required = 0;
    const session = client(store, async (url) => url.endsWith('/me') ?
      Response.json(profile('subject', 'canonical')) :
      new Response('{}', { status, headers: { 'retry-after': '60' } }), { onRequired() { required++; } });
    await session.authorize('test-token');
    session.save({ note: { c: 'Unsent preserved note' } });
    await assert.rejects(session.request(api, { method: 'POST', body: '{}' }),
      (error) => error.status === status && error.retryMs === 60_000);
    assert.equal(required, status === 401 || status === 403 ? 1 : 0);
    assert.deepEqual(JSON.parse(store.getItem('review_account_v1:subject')), { note: { c: 'Unsent preserved note' } });
  }
});

test('A03 denied identity and failed scoped storage never erase the original backup', async () => {
  const original = JSON.stringify({ note: { c: 'Preserve before login' } });
  const store = storage({ review: original, reviewer: 'canonical' });
  const denied = client(store, async () => new Response('{}', { status: 403 }));
  await assert.rejects(denied.authorize('test-token'));
  assert.equal(denied.signedIn, false);
  assert.equal(store.getItem('review'), original);
  const full = client({ ...store, setItem() { throw new Error('storage full'); } },
    async () => Response.json(profile('subject', 'canonical')));
  await assert.rejects(full.authorize('test-token'));
  assert.equal(full.signedIn, false);
  assert.equal(store.getItem('review'), original);
});

test('A03 late login reply and late old-account 401 cannot replace a newer identity', async () => {
  let resolveOld;
  const oldResponse = new Promise((resolve) => { resolveOld = resolve; });
  let calls = 0;
  const session = client(storage(), async (url) => {
    if (!url.endsWith('/me')) return oldResponse;
    calls++;
    return Response.json(profile(`subject-${calls}`, `canonical-${calls}`));
  });
  await session.authorize('first-test-token');
  const oldRequest = session.request(api);
  await session.authorize('second-test-token');
  resolveOld(new Response('{}', { status: 401 }));
  await assert.rejects(oldRequest);
  assert.equal(session.signedIn, true);
  assert.equal(session.profile.sub, 'subject-2');
  let resolveLogin;
  const pending = new Promise((resolve) => { resolveLogin = resolve; });
  let count = 0;
  const second = client(storage(), async () => ++count === 1 ? pending : Response.json(profile('new', 'new-name')));
  const oldLogin = second.authorize('old-test-token');
  await second.authorize('new-test-token');
  resolveLogin(Response.json(profile('old', 'old-name')));
  await assert.rejects(oldLogin);
  assert.equal(second.profile.sub, 'new');
});

test('A03 all new review auth strings have identical nonempty keys in seven locales', () => {
  assert.deepEqual(Object.keys(messages).sort(), ['ar', 'en', 'es', 'fr', 'pt', 'ru', 'ur']);
  for (const values of Object.values(messages)) {
    assert.deepEqual(Object.keys(values).sort(), Object.keys(messages.ar).sort());
    for (const value of Object.values(values)) assert.equal(typeof value === 'string' && value.trim().length > 0, true);
  }
});
