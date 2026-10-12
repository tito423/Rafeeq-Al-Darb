import assert from 'node:assert/strict';
import { after, before, test } from 'node:test';
import { createGoogleAuthWorker } from '../test-support/google-auth-worker.mjs';

let worker;
let reviewerToken;
let adminToken;
const roles = [
  { sub: 'reviewer-one', name: 'A03-reviewer-one', role: 'reviewer' },
  { sub: 'reviewer-two', name: 'A03-reviewer-two', role: 'reviewer' },
  { sub: 'review-admin', name: 'A03-admin', role: 'admin' },
];
before(async () => {
  worker = await createGoogleAuthWorker({ reviewers: roles });
  reviewerToken = await worker.sign({ sub: 'reviewer-one' });
  adminToken = await worker.sign({ sub: 'review-admin' });
});
after(async () => { await worker?.stop(); });

async function request(path, token, body) {
  return worker.runtime.dispatchFetch('http://127.0.0.1' + path, {
    method: body === undefined ? 'GET' : 'POST',
    headers: { ...(token ? { Authorization: `Bearer ${token}` } : {}), 'content-type': 'application/json' },
    ...(body === undefined ? {} : { body: JSON.stringify(body) }),
  });
}
const note = (reviewer, id) => ({ reviewer, notes: [{ id, note: 'Local authenticated review test' }] });

test('A03 every review read/write route requires authentication before D1', async () => {
  for (const [path, body] of [['/review?reviewer=A03-reviewer-one', undefined],
    ['/review/reviewers', undefined], ['/review', note('A03-reviewer-one', 'anonymous')]]) {
    const response = await request(path, undefined, body);
    assert.equal(response.status, 401);
    assert.equal(response.headers.get('access-control-allow-origin'), '*');
  }
  const tables = await worker.database.prepare("SELECT name FROM sqlite_master WHERE name = 'review_notes'").all();
  assert.deepEqual(tables.results, []);
});

test('A03 valid Google subject without a reviewer grant is denied', async () => {
  assert.equal((await request('/review/reviewers', await worker.sign({ sub: 'ungranted-subject' }))).status, 403);
});

test('A03 authorized identity supplies stable configured name and role', async () => {
  const response = await request('/review/me', reviewerToken);
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), { sub: 'reviewer-one', reviewer: 'A03-reviewer-one', role: 'reviewer' });
});

test('A03 reviewer can write own name but cannot impersonate another', async () => {
  const valid = await request('/review', reviewerToken, note('A03-reviewer-one', 'own'));
  assert.equal(valid.status, 200);
  assert.equal((await valid.json()).saved, 1);
  assert.equal((await request('/review', reviewerToken, note('A03-reviewer-two', 'impersonated'))).status, 403);
  const bad = await worker.database.prepare('SELECT item_id FROM review_notes WHERE item_id = ?').bind('impersonated').all();
  assert.deepEqual(bad.results, []);
});

test('A03 reviewer reads only own notes while admin can read authorized overview', async () => {
  assert.equal((await request('/review?reviewer=A03-reviewer-one', reviewerToken)).status, 200);
  assert.equal((await request('/review?reviewer=A03-reviewer-two', reviewerToken)).status, 403);
  const personal = await request('/review/reviewers', reviewerToken);
  assert.equal(personal.status, 200);
  assert.deepEqual((await personal.json()).reviewers.map((row) => row.reviewer), ['A03-reviewer-one']);
  assert.equal((await request('/review?reviewer=A03-reviewer-one', adminToken)).status, 200);
  assert.equal((await request('/review/reviewers', adminToken)).status, 200);
});

test('A03 missing grant configuration denies reviews but leaves ordinary sync authorized', async () => {
  const unconfigured = await createGoogleAuthWorker();
  try {
    const token = await unconfigured.sign();
    const headers = { Authorization: `Bearer ${token}` };
    assert.equal((await unconfigured.runtime.dispatchFetch('http://127.0.0.1/review/reviewers', { headers })).status, 403);
    assert.equal((await unconfigured.runtime.dispatchFetch('http://127.0.0.1/sync', { headers })).status, 200);
  } finally { await unconfigured.stop(); }
});

test('A03 authenticated CORS preflight allows Authorization without consuming identity', async () => {
  const response = await worker.runtime.dispatchFetch('http://127.0.0.1/review', { method: 'OPTIONS' });
  assert.equal(response.status, 204);
  assert.match(response.headers.get('access-control-allow-headers'), /authorization/i);
});

test('A03 ordinary sync authentication is unchanged', async () => {
  assert.equal((await request('/sync', reviewerToken)).status, 200);
  assert.equal((await request('/sync')).status, 401);
});

test('A03 existing review preflight origin and methods remain accepted', async () => {
  const response = await worker.runtime.dispatchFetch('http://127.0.0.1/review', { method: 'OPTIONS' });
  assert.equal(response.status, 204);
  assert.equal(response.headers.get('access-control-allow-origin'), '*');
  assert.equal(response.headers.get('access-control-allow-methods'), 'GET, POST, OPTIONS');
});

test('A03 admin overview permission does not permit writing another reviewer name', async () => {
  assert.equal((await request('/review', adminToken, note('A03-reviewer-one', 'admin-impersonation'))).status, 403);
});

for (const [label, configuration] of [
  ['non-array', 'invalid'], ['empty', []],
  ['unknown role', [{ sub: 'grant-subject', name: 'A03-grant', role: 'owner' }]],
  ['no identifier', [{ name: 'A03-grant', role: 'reviewer' }]],
  ['duplicate name', [{ sub: 'grant-subject', name: 'A03-grant', role: 'reviewer' },
    { sub: 'another-subject', name: 'A03-grant', role: 'admin' }]],
]) {
  test(`A03 ${label} grant configuration fails closed`, async () => {
    const fixture = await createGoogleAuthWorker({ reviewers: configuration });
    try {
      const token = await fixture.sign({ sub: 'grant-subject' });
      const response = await fixture.runtime.dispatchFetch('http://127.0.0.1/review/me', {
        headers: { Authorization: `Bearer ${token}` },
      });
      assert.equal(response.status, 403);
    } finally { await fixture.stop(); }
  });
}

test('A03 email grant requires a verified Google-authoritative email, or an explicit subject pin', async () => {
  const fixture = await createGoogleAuthWorker({ reviewers: [
    { email: 'a03.test@gmail.com', name: 'A03-email', role: 'reviewer' },
    { email: 'a03@example.test', name: 'A03-external', role: 'reviewer' },
    { sub: 'pinned-subject', email: 'a03@example.test', name: 'A03-pinned', role: 'reviewer' },
  ] });
  try {
    const cases = [
      [{ email: 'a03.test@gmail.com', email_verified: true }, 200, 'A03-email'],
      [{ email: 'a03.test@gmail.com', email_verified: false }, 403],
      [{ email: 'a03.test@gmail.com', email_verified: 'true' }, 403],
      [{ email: 'other.test@gmail.com', email_verified: true }, 403],
      [{ email: 'a03@example.test', email_verified: true }, 403],
      [{ email: 'a03@example.test', email_verified: true, hd: 'example.test' }, 200, 'A03-external'],
      [{ sub: 'pinned-subject', email: 'a03@example.test', email_verified: true }, 200, 'A03-pinned'],
      [{ sub: 'pinned-subject', email: 'different@example.test', email_verified: true }, 403],
    ];
    for (const [claims, status, name] of cases) {
      const response = await fixture.runtime.dispatchFetch('http://127.0.0.1/review/me', {
        headers: { Authorization: `Bearer ${await fixture.sign(claims)}` },
      });
      assert.equal(response.status, status);
      if (status === 200) assert.equal((await response.json()).reviewer, name);
    }
  } finally { await fixture.stop(); }
});
