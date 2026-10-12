import assert from 'node:assert/strict';
import { after, before, test } from 'node:test';
import { startLocalWorker } from '../test-support/local-worker.mjs';

let worker;
before(async () => {
  worker = await startLocalWorker();
  const response = await fetch(worker.base + '/review', {
    method: 'POST', headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ reviewer: 'audit_A07_valid',
      notes: [{ id: 'compatibility-probe', note: 'A07 local compatibility probe' }] }),
  });
  assert.equal(response.status, 200);
  assert.equal((await response.json()).saved, 1);
});
after(async () => { await worker?.stop(); });

test('A07 protected sync still rejects unauthenticated GET and POST', async () => {
  for (const method of ['GET', 'POST']) {
    const response = await fetch(worker.base + '/sync', { method });
    assert.equal(response.status, 401);
    assert.equal(await response.text(), 'Unauthorized');
  }
});

test('A07 actual review listing retains original count and fields', async () => {
  const response = await fetch(worker.base + '/review/reviewers');
  assert.equal(response.status, 200);
  const reviewer = (await response.json()).reviewers.find(
    (row) => row.reviewer === 'audit_A07_valid');
  assert.equal(reviewer.items, 1);
  assert.equal(reviewer.notes, 1);
  assert.equal(reviewer.done, 0);
});

test('A07 unsupported review method remains 405 with CORS', async () => {
  const response = await fetch(worker.base + '/review', { method: 'DELETE' });
  assert.equal(response.status, 405);
  assert.equal(response.headers.get('access-control-allow-origin'), '*');
});
