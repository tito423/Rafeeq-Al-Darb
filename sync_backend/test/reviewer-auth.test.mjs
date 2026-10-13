import assert from 'node:assert/strict';
import { after, before, test } from 'node:test';
import { createGoogleAuthWorker } from '../test-support/google-auth-worker.mjs';

// Owner, 2026-10-13: no reviewer list and no account. A reviewer opens the
// link, writes a name and starts. A-03 stays fixed by the name's key.
let worker;
before(async () => { worker = await createGoogleAuthWorker(); });
after(async () => { await worker?.stop(); });

async function request(path, { key, body, method } = {}) {
  return worker.runtime.dispatchFetch('http://127.0.0.1' + path, {
    method: method ?? (body === undefined ? 'GET' : 'POST'),
    headers: { ...(key ? { Authorization: `Bearer ${key}` } : {}), 'content-type': 'application/json' },
    ...(body === undefined ? {} : { body: JSON.stringify(body) }),
  });
}
const register = (reviewer) => request('/review/register', { body: { reviewer } });
const notes = (id, reviewer) => ({ ...(reviewer ? { reviewer } : {}), notes: [{ id, note: 'Local review test' }] });
const rows = async (id) => (await worker.database.prepare(
  'SELECT reviewer FROM review_notes WHERE item_id = ?').bind(id).all()).results;

let first;
test('A03 the first device to write a name gets a random key for it', async () => {
  const response = await register('  الشيخ   أحمد  ');
  assert.equal(response.status, 200);
  const body = await response.json();
  assert.equal(body.reviewer, 'الشيخ أحمد');
  assert.match(body.token, /^[A-Za-z0-9_-]{43}$/);
  first = body.token;
});

test('A03 the same name, however spaced, cannot be claimed again', async () => {
  for (const name of ['الشيخ أحمد', ' الشيخ  أحمد ']) {
    const response = await register(name);
    assert.equal(response.status, 409);
    assert.deepEqual(await response.json(), { error: 'name taken' });
  }
});

test('A03 a name needs three characters', async () => {
  assert.equal((await register('اب')).status, 400);
  assert.equal((await request('/review/register', { body: {} })).status, 400);
});

test('A03 only the key hash is stored', async () => {
  const stored = await worker.database.prepare('SELECT token_hash FROM review_reviewers').all();
  assert.equal(stored.results.length, 1);
  assert.notEqual(stored.results[0].token_hash, first);
  assert.match(stored.results[0].token_hash, /^[0-9a-f]{64}$/);
});

test('A03 writing needs a valid key and nothing is saved without one', async () => {
  assert.equal((await request('/review', { body: notes('no-key', 'الشيخ أحمد') })).status, 401);
  assert.equal((await request('/review', { key: 'x'.repeat(43), body: notes('bad-key', 'الشيخ أحمد') })).status, 401);
  assert.equal((await request('/review', { key: 'short', body: notes('malformed-key') })).status, 401);
  for (const id of ['no-key', 'bad-key', 'malformed-key']) assert.deepEqual(await rows(id), []);
});

test('A03 a key writes only under its own name', async () => {
  const own = await request('/review', { key: first, body: notes('own', 'الشيخ أحمد') });
  assert.equal(own.status, 200);
  assert.equal((await own.json()).saved, 1);
  assert.deepEqual(await rows('own'), [{ reviewer: 'الشيخ أحمد' }]);
  const other = await register('مراجع آخر');
  assert.equal(other.status, 200);
  const impersonated = await request('/review', { key: first, body: notes('impersonated', 'مراجع آخر') });
  assert.equal(impersonated.status, 403);
  assert.deepEqual(await rows('impersonated'), []);
  // Without a name in the body the key's own name is used.
  assert.equal((await request('/review', { key: first, body: notes('nameless') })).status, 200);
  assert.deepEqual(await rows('nameless'), [{ reviewer: 'الشيخ أحمد' }]);
});

test('A03 /review/me names the key, and refuses without one', async () => {
  const me = await request('/review/me', { key: first });
  assert.equal(me.status, 200);
  assert.deepEqual(await me.json(), { reviewer: 'الشيخ أحمد' });
  assert.equal((await request('/review/me')).status, 401);
});

test('A03 reading stays open, as the site always was', async () => {
  const list = await request('/review/reviewers');
  assert.equal(list.status, 200);
  assert.ok((await list.json()).reviewers.some((row) => row.reviewer === 'الشيخ أحمد'));
  const mine = await request('/review?reviewer=' + encodeURIComponent('الشيخ أحمد'));
  assert.equal(mine.status, 200);
  assert.equal((await mine.json()).notes.length, 2);
});

test('A03 ordinary sync still requires a verified Google token', async () => {
  assert.equal((await request('/sync')).status, 401);
  const token = await worker.sign();
  const response = await worker.runtime.dispatchFetch('http://127.0.0.1/sync', {
    headers: { Authorization: `Bearer ${token}` } });
  assert.equal(response.status, 200);
  // A review key is not a sync credential.
  assert.equal((await request('/sync', { key: first })).status, 401);
});

test('A03 preflight allows the Authorization header', async () => {
  const response = await request('/review', { method: 'OPTIONS' });
  assert.equal(response.status, 204);
  assert.match(response.headers.get('access-control-allow-headers'), /authorization/i);
});

test('A03 unknown POST path under /review is not a write', async () => {
  assert.equal((await request('/review/other', { key: first, body: notes('stray') })).status, 404);
  assert.deepEqual(await rows('stray'), []);
});
