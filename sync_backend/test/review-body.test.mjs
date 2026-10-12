import assert from 'node:assert/strict';
import http from 'node:http';
import { after, before, test } from 'node:test';
import { startAuthenticatedLocalWorker } from '../test-support/authenticated-local-worker.mjs';

const limit = 2 * 1024 * 1024;
let worker;
before(async () => { worker = await startAuthenticatedLocalWorker([
  'audit_A05_valid', 'audit_A05_boundary', 'audit_A05_declared', 'audit_A05_unicode',
  'audit_A05_chunked', 'audit_A05_small_utf8',
]); });
after(async () => { await worker?.stop(); });

function sizedBody(bytes, reviewer) {
  const prefix = JSON.stringify({ reviewer, notes: [], padding: '' });
  return prefix.slice(0, -2) + 'x'.repeat(bytes - Buffer.byteLength(prefix)) + '"}';
}

async function post(body) {
  let reviewer = 'audit_A05_valid';
  try { reviewer = JSON.parse(body).reviewer ?? reviewer; } catch { /* Preserve the malformed-body control. */ }
  return fetch(worker.base + '/review', {
    method: 'POST', headers: { 'content-type': 'application/json', ...worker.headersFor(reviewer) }, body,
  });
}

function chunked(body) {
  return new Promise((resolve, reject) => {
    const request = http.request(worker.base + '/review', {
      method: 'POST', headers: {
        'content-type': 'application/json', 'transfer-encoding': 'chunked',
        ...worker.headersFor(JSON.parse(body).reviewer),
      },
    }, (response) => {
      const data = [];
      response.on('data', (chunk) => data.push(chunk));
      response.on('end', () => resolve({
        status: response.statusCode, headers: response.headers,
        body: Buffer.concat(data).toString('utf8'),
      }));
      response.on('error', reject);
    });
    request.on('error', reject);
    const bytes = Buffer.from(body);
    for (let offset = 0; offset < bytes.length; offset += 16_381) {
      request.write(bytes.subarray(offset, offset + 16_381));
    }
    request.end();
  });
}

test('A05 ordinary review persists unchanged in actual local D1', async () => {
  const reviewer = 'audit_A05_valid';
  const response = await post(JSON.stringify({
    reviewer, notes: [{ id: 'boundary-probe', note: 'A05 local boundary probe' }],
  }));
  assert.equal(response.status, 200);
  assert.equal((await response.json()).saved, 1);
  const saved = await (await fetch(worker.base + '/review?reviewer=' + reviewer, { headers: worker.headersFor(reviewer) })).json();
  assert.equal(saved.notes.length, 1);
  assert.equal(saved.notes[0].note, 'A05 local boundary probe');
});

test('A05 exactly 2MiB JSON remains accepted', async () => {
  const body = sizedBody(limit, 'audit_A05_boundary');
  assert.equal(Buffer.byteLength(body), limit);
  const response = await post(body);
  assert.equal(response.status, 200);
  assert.equal((await response.json()).saved, 0);
});

test('A05 declared ASCII body one byte over limit is rejected', async () => {
  const response = await post(sizedBody(limit + 1, 'audit_A05_declared'));
  assert.equal(response.status, 413);
  assert.equal(response.headers.get('access-control-allow-origin'), '*');
});

test('A05 UTF8 bytes are capped even when string length is below limit', async () => {
  const body = JSON.stringify({ reviewer: 'audit_A05_unicode', notes: [],
    padding: '🙂'.repeat(600_000) });
  assert.ok(body.length < limit);
  assert.ok(Buffer.byteLength(body) > limit);
  assert.equal((await post(body)).status, 413);
});

test('A05 chunked ASCII body without content-length is capped', async () => {
  const response = await chunked(sizedBody(limit + 1, 'audit_A05_chunked'));
  assert.equal(response.status, 413);
  assert.equal(response.headers['access-control-allow-origin'], '*');
});

test('A05 small UTF8 JSON across chunk boundaries stays accepted', async () => {
  const response = await chunked(JSON.stringify({
    reviewer: 'audit_A05_small_utf8', notes: [], padding: '🙂'.repeat(10_000),
  }));
  assert.equal(response.status, 200);
  assert.equal(JSON.parse(response.body).saved, 0);
});

test('A05 bad JSON remains 400 with review CORS', async () => {
  const response = await post('{');
  assert.equal(response.status, 400);
  assert.equal((await response.json()).error, 'bad json');
  assert.equal(response.headers.get('access-control-allow-origin'), '*');
});

test('A05 review preflight remains 204', async () => {
  const response = await fetch(worker.base + '/review', { method: 'OPTIONS' });
  assert.equal(response.status, 204);
  assert.equal(response.headers.get('access-control-allow-origin'), '*');
});

