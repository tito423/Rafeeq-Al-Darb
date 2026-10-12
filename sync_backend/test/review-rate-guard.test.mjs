import assert from 'node:assert/strict';
import { test } from 'node:test';
import { build } from 'esbuild';
import { fileURLToPath } from 'node:url';

const bundle = await build({ entryPoints: [fileURLToPath(new URL('../src/index.ts', import.meta.url))],
  bundle: true, write: false, format: 'esm', target: 'es2022' });
const { default: worker } = await import(
  'data:text/javascript;base64,' + Buffer.from(bundle.outputFiles[0].text).toString('base64'));
const forbiddenDatabase = { prepare() { assert.fail('Rate rejection must do no D1 work'); } };

test('A18 blocked request consumes neither malformed body nor D1 and uses source bucket', async () => {
  let called = 0;
  const request = new Request('http://127.0.0.1/review', { method: 'POST', body: '{',
    headers: { 'CF-Connecting-IP': '192.0.2.18' } });
  request.body.getReader = () => assert.fail('Blocked body must not be parsed');
  const response = await worker.fetch(request, { DB: forbiddenDatabase,
    REVIEW_RATE_LIMITER: { async limit({ key }) {
      called++; assert.equal(key, 'rafeeq:review:v1:192.0.2.18'); return { success: false };
    } },
  }, {});
  assert.equal(response.status, 429);
  assert.equal(called, 1);
  assert.equal(response.headers.get('retry-after'), '60');
  assert.equal(response.headers.get('access-control-allow-origin'), '*');
});

test('A18 missing source cannot bypass a shared unknown bucket', async () => {
  const response = await worker.fetch(new Request('http://127.0.0.1/review?reviewer=changed'), {
    DB: forbiddenDatabase, REVIEW_RATE_LIMITER: { async limit({ key }) {
      assert.equal(key, 'rafeeq:review:v1:unknown'); return { success: false };
    } },
  }, {});
  assert.equal(response.status, 429);
});

for (const [label, limiter] of [['missing', undefined], ['failed', { async limit() { throw new Error('binding down'); } }]]) {
  test(`A18 ${label} limiter fails closed before D1 with retriable response`, async () => {
    const response = await worker.fetch(new Request('http://127.0.0.1/review?reviewer=audit'), {
      DB: forbiddenDatabase, REVIEW_RATE_LIMITER: limiter,
    }, {});
    assert.equal(response.status, 503);
    assert.equal(response.headers.get('retry-after'), '5');
    assert.equal(response.headers.get('access-control-allow-origin'), '*');
    assert.deepEqual(await response.json(), { error: 'rate limiter unavailable' });
  });
}

test('A18 preflight uses neither limiter nor D1', async () => {
  const response = await worker.fetch(new Request('http://127.0.0.1/review', { method: 'OPTIONS' }), {
    DB: forbiddenDatabase, REVIEW_RATE_LIMITER: { limit() { assert.fail('Preflight must not consume rate quota'); } },
  }, {});
  assert.equal(response.status, 204);
  assert.equal(response.headers.get('access-control-allow-origin'), '*');
});
