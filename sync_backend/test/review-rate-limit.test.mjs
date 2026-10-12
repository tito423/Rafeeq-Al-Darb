import assert from 'node:assert/strict';
import { after, before, test } from 'node:test';
import { setTimeout as delay } from 'node:timers/promises';
import { startAuthenticatedLocalWorker } from '../test-support/authenticated-local-worker.mjs';

let worker;
const primaryIp = '192.0.2.18';
const otherIp = '192.0.2.19';
const headers = (ip, name = 'audit_A18_admin') => ({ 'CF-Connecting-IP': ip,
  'content-type': 'application/json', ...worker.headersFor(name) });
before(async () => { worker = await startAuthenticatedLocalWorker([
  'audit_A18', 'audit_A18_changed_name', 'audit_A18_admin',
], { adminNames: ['audit_A18_admin'] }); });
after(async () => { await worker?.stop(); });

test('A18 actual Wrangler review burst is stopped before the extra note is saved', async () => {
  // Keep the burst in one native rate window; no assertion or request is retried.
  const seconds = new Date().getSeconds();
  if (seconds >= 55) await delay((60 - seconds) * 1000);
  for (let i = 0; i < 120; i++) {
    const response = await fetch(worker.base + '/review', { method: 'POST', headers: headers(primaryIp, 'audit_A18'),
      body: JSON.stringify({ reviewer: 'audit_A18', notes: [{ id: `rate-${i}`, note: 'Local rate protection check' }] }) });
    assert.equal(response.status, 200, `Ordinary allowed request ${i}`);
    assert.equal((await response.json()).saved, 1);
  }
  const blocked = await fetch(worker.base + '/review', { method: 'POST', headers: headers(primaryIp, 'audit_A18'),
    body: JSON.stringify({ reviewer: 'audit_A18_changed_name', notes: [{ id: 'must-not-save', note: 'Blocked request' }] }) });
  assert.equal(blocked.status, 429);
  assert.equal(blocked.headers.get('access-control-allow-origin'), '*');
  assert.equal(blocked.headers.get('retry-after'), '60');
  assert.deepEqual(await blocked.json(), { error: 'rate limit exceeded' });
  const notes = await fetch(worker.base + '/review?reviewer=audit_A18_changed_name', { headers: headers(otherIp) });
  assert.equal(notes.status, 200);
  assert.deepEqual((await notes.json()).notes, []);
});

test('A18 exhausted review GET is limited but OPTIONS and sync are unaffected', async () => {
  const blocked = await fetch(worker.base + '/review/reviewers', { headers: headers(primaryIp, 'audit_A18') });
  assert.equal(blocked.status, 429);
  const preflight = await fetch(worker.base + '/review', { method: 'OPTIONS', headers: headers(primaryIp) });
  assert.equal(preflight.status, 204);
  assert.equal(preflight.headers.get('access-control-allow-origin'), '*');
  const sync = await fetch(worker.base + '/sync', { headers: { 'CF-Connecting-IP': primaryIp } });
  assert.equal(sync.status, 401);
});

test('A18 another source can read every previously accepted note', async () => {
  const response = await fetch(worker.base + '/review?reviewer=audit_A18', { headers: headers(otherIp) });
  assert.equal(response.status, 200);
  const notes = (await response.json()).notes;
  assert.equal(notes.length, 120);
  assert.equal(new Set(notes.map((row) => row.item_id)).size, 120);
});

test('A18 ordinary invalid JSON keeps the existing 400 and CORS', async () => {
  const response = await fetch(worker.base + '/review', { method: 'POST', headers: headers(otherIp), body: '{' });
  assert.equal(response.status, 400);
  assert.deepEqual(await response.json(), { error: 'bad json' });
  assert.equal(response.headers.get('access-control-allow-origin'), '*');
});

test('A03 reviewers sharing a network have independent limits; moving networks cannot reset one account', async () => {
  const another = await fetch(worker.base + '/review/reviewers', { headers: headers(primaryIp, 'audit_A18_admin') });
  assert.equal(another.status, 200);
  const sameAccount = await fetch(worker.base + '/review/reviewers', { headers: headers(otherIp, 'audit_A18') });
  assert.equal(sameAccount.status, 429);
});
