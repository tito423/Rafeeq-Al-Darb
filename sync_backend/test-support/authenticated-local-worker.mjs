import assert from 'node:assert/strict';
import { startLocalWorker } from './local-worker.mjs';

// Runs the production entrypoint and claims each reviewer name through the
// real /review/register route, so tests write with the keys a browser gets.
export async function startAuthenticatedLocalWorker(names) {
  const worker = await startLocalWorker();
  const tokens = new Map();
  try {
    for (const name of names) {
      const response = await fetch(worker.base + '/review/register', {
        method: 'POST', headers: { 'content-type': 'application/json', 'CF-Connecting-IP': '192.0.2.250' },
        body: JSON.stringify({ reviewer: name }),
      });
      assert.equal(response.status, 200, `register ${name}`);
      tokens.set(name, (await response.json()).token);
    }
    return { ...worker, tokenFor: (name) => tokens.get(name), headersFor(name) {
      assert.ok(tokens.has(name), 'Missing registered test reviewer');
      return { Authorization: `Bearer ${tokens.get(name)}` };
    } };
  } catch (error) { await worker.stop(); throw error; }
}
