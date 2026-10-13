import assert from 'node:assert/strict';
import { test } from 'node:test';
import '../review-client/review-key.js';

const { create } = globalThis.RafeeqReviewKey;
const api = 'https://example.invalid/review';
function storage(seed = {}) {
  const values = new Map(Object.entries(seed));
  return { values, getItem: (k) => values.get(k) ?? null,
    setItem(k, v) { values.set(k, String(v)); }, removeItem(k) { values.delete(k); } };
}

test('register keeps the name and key only after the Worker accepts them', async () => {
  const store = storage();
  const calls = [];
  const key = create({ api, storage: store, fetch: async (url, init) => {
    calls.push([url, JSON.parse(init.body)]);
    return Response.json({ reviewer: 'الشيخ أحمد', token: 'k'.repeat(43) });
  } });
  assert.deepEqual(await key.register('  الشيخ   أحمد '), { ok: true, reviewer: 'الشيخ أحمد' });
  assert.deepEqual(calls, [[api + '/register', { reviewer: 'الشيخ أحمد' }]]);
  assert.equal(store.getItem('reviewer'), 'الشيخ أحمد');
  assert.equal(key.hasKey, true);
});

test('a taken name, a short name and a network failure store nothing', async () => {
  for (const [fetch, name, error] of [
    [async () => new Response('{}', { status: 409 }), 'اسم مأخوذ', 'taken'],
    [async () => assert.fail('short names are not sent'), 'اب', 'short'],
    [async () => { throw new TypeError('offline'); }, 'اسم ما', 'failed'],
    [async () => new Response('{}', { status: 503 }), 'اسم ما', 'failed'],
  ]) {
    const store = storage({ reviewer: 'قديم' });
    const key = create({ api, storage: store, fetch });
    assert.deepEqual(await key.register(name), { ok: false, error });
    assert.equal(store.getItem('reviewer'), 'قديم');
    assert.equal(key.hasKey, false);
  }
});

test('post sends the key and forgets it on 401', async () => {
  const store = storage({ reviewer: 'الشيخ أحمد', reviewer_key_v1: 'k'.repeat(43) });
  let seen;
  let status = 200;
  const key = create({ api, storage: store, fetch: async (url, init) => {
    seen = { url, auth: init.headers.Authorization, body: JSON.parse(init.body) };
    return new Response('{}', { status });
  } });
  await key.post([{ id: 'a', note: 'n' }]);
  assert.deepEqual(seen, { url: api, auth: 'Bearer ' + 'k'.repeat(43),
    body: { reviewer: 'الشيخ أحمد', notes: [{ id: 'a', note: 'n' }] } });
  assert.equal(key.hasKey, true);
  status = 401;
  await key.post([]);
  assert.equal(key.hasKey, false);
  assert.equal(store.getItem('reviewer'), 'الشيخ أحمد');
});
