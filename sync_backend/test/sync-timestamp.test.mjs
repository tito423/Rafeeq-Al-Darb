import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { after, before, test } from 'node:test';
import { Miniflare, convertV4MiniflareOptions } from 'miniflare';
import { build } from 'esbuild';
import { fileURLToPath } from 'node:url';

// Actual Worker source and actual local D1. Only the Google HTTP transport
// is controlled here; this does not prove a live Google login.
let runtime;
let database;
const subject = 'audit-A06-local';
const now = Date.now();
before(async () => {
  const bundle = await build({ entryPoints: [fileURLToPath(new URL('../src/index.ts', import.meta.url))],
    bundle: true, write: false, format: 'esm', target: 'es2022' });
  runtime = new Miniflare(convertV4MiniflareOptions({
    script: bundle.outputFiles[0].text, modules: true,
    compatibilityDate: '2024-09-09', d1Databases: ['DB'],
    outboundService: async (request) => {
      const url = new URL(request.url);
      assert.equal(url.origin, 'https://oauth2.googleapis.com');
      assert.equal(url.pathname, '/tokeninfo');
      assert.equal(url.searchParams.get('id_token'), 'A06-controlled-transport');
      return Response.json({ iss: 'https://accounts.google.com', sub: subject,
        aud: '227986327850-ha6gea87kueaeg2a3582ecpu3s0nbnh1.apps.googleusercontent.com',
        exp: String(Math.floor(Date.now() / 1000) + 3600) });
    },
  }));
  database = await runtime.getD1Database('DB');
  const schema = await readFile(new URL('../schema.sql', import.meta.url), 'utf8');
  for (const statement of schema.split(';').filter((part) => part.trim())) {
    await database.prepare(statement).run();
  }
});
after(async () => { await runtime?.dispose(); });

async function post(updates, counters = []) {
  return runtime.dispatchFetch('http://127.0.0.1/sync', { method: 'POST',
    headers: { Authorization: 'Bearer A06-controlled-transport', 'content-type': 'application/json' },
    body: JSON.stringify({ updates, counters }),
  });
}
async function row(key = 'quran_last_page') {
  return database.prepare('SELECT value, updated_at, typeof(updated_at) AS storage FROM user_state WHERE sub = ? AND key = ?')
    .bind(subject, key).first();
}
async function clear() {
  await database.prepare('DELETE FROM user_state WHERE sub = ?').bind(subject).run();
}

for (const [label, timestamp] of Object.entries({
  text: 'blocked', numericString: String(now), null: null, boolean: true,
  fraction: now + 0.5, negative: -1, unsafe: Number.MAX_SAFE_INTEGER + 1,
  array: [], object: {}, overflow: 1e100,
})) {
  test(`A06 rejects ${label} timestamp without storing or blocking the next valid write`, async () => {
    await clear();
    const response = await post([{ key: 'quran_last_page', value: '540', updated_at: timestamp }]);
    assert.equal(response.status, 200, 'Invalid rows keep the existing ignored-row API policy');
    assert.deepEqual(await response.json(), { success: true });
    assert.equal(await row(), null, 'Invalid timestamp must not enter SQLite');
    assert.equal((await post([{ key: 'quran_last_page', value: '541', updated_at: now }])).status, 200);
    assert.deepEqual(await row(), { value: '541', updated_at: now, storage: 'integer' });
  });
}

test('A06 valid integer upserts preserve newer/older/equal and retry behavior', async () => {
  await clear();
  for (const [value, updated_at] of [['540', now], ['539', now - 1], ['538', now], ['541', now + 1], ['541', now + 1]]) {
    assert.equal((await post([{ key: 'quran_last_page', value, updated_at }])).status, 200);
  }
  assert.deepEqual(await row(), { value: '541', updated_at: now + 1, storage: 'integer' });
});

test('A06 zero and largest safe integer remain valid numeric boundaries', async () => {
  await clear();
  for (const updated_at of [0, Number.MAX_SAFE_INTEGER]) {
    assert.equal((await post([{ key: 'quran_last_page', value: '541', updated_at }])).status, 200);
    assert.equal((await row()).updated_at, updated_at);
    assert.equal((await row()).storage, 'integer');
  }
});

test('A06 mixed request preserves valid state and counter retry deduplication', async () => {
  await clear();
  const updates = [
    { key: 'quran_last_page', value: '541', updated_at: now },
    { key: 'tasbeeh_custom_target', value: '100', updated_at: 'blocked' },
  ];
  const counters = [{ key: 'tasbeeh_total', event_id: 'A06-valid-counter', increment_value: 7 }];
  for (let attempt = 0; attempt < 2; attempt++) assert.equal((await post(updates, counters)).status, 200);
  assert.equal((await row()).value, '541');
  assert.equal(await row('tasbeeh_custom_target'), null);
  const counter = await database.prepare('SELECT SUM(increment_value) AS total FROM user_counters WHERE sub = ?')
    .bind(subject).first();
  assert.equal(counter.total, 7);
});

test('A06 missing timestamp is still ignored and unauthenticated writes are rejected', async () => {
  await clear();
  assert.equal((await post([{ key: 'quran_last_page', value: '541' }])).status, 200);
  assert.equal(await row(), null);
  const response = await runtime.dispatchFetch('http://127.0.0.1/sync', { method: 'POST', body: '{}' });
  assert.equal(response.status, 401);
});

for (const [label, poisoned] of [['text', 'blocked'], ['fraction', now + 0.5],
  ['negative', -1], ['unsafe', Number.MAX_SAFE_INTEGER + 1]]) {
  test(`A06 valid write repairs pre-existing ${label} timestamp without touching another account`, async () => {
    await clear();
    await database.prepare('INSERT OR REPLACE INTO user_state (sub, key, value, updated_at) VALUES (?, ?, ?, ?)')
      .bind(subject, 'quran_last_page', '540', poisoned).run();
    await database.prepare('INSERT OR REPLACE INTO user_state (sub, key, value, updated_at) VALUES (?, ?, ?, ?)')
      .bind('audit-A06-other', 'quran_last_page', '542', now + 2).run();
    assert.equal((await post([{ key: 'quran_last_page', value: '541', updated_at: now }])).status, 200);
    assert.deepEqual(await row(), { value: '541', updated_at: now, storage: 'integer' });
    const other = await database.prepare('SELECT value, updated_at FROM user_state WHERE sub = ?')
      .bind('audit-A06-other').first();
    assert.deepEqual(other, { value: '542', updated_at: now + 2 });
  });
}
