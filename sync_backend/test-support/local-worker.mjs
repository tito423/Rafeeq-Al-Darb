import { spawn, spawnSync } from 'node:child_process';
import { mkdtemp, realpath, rm, writeFile } from 'node:fs/promises';
import { createServer } from 'node:net';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { setTimeout as delay } from 'node:timers/promises';

const backend = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');

async function freePort() {
  const server = createServer();
  await new Promise((resolve, reject) => {
    server.once('error', reject);
    server.listen(0, '127.0.0.1', resolve);
  });
  const port = server.address().port;
  await new Promise((resolve) => server.close(resolve));
  return port;
}

/// Run the actual Wrangler dev pipeline with isolated LOCAL D1 persistence.
export async function startLocalWorker({ entrypoint } = {}) {
  const temporaryRoot = await realpath(tmpdir());
  const directory = await mkdtemp(path.join(temporaryRoot, 'rafeeq-worker-'));
  const port = await freePort();
  const inspector = await freePort();
  const child = spawn(process.execPath, [
    process.env.RAFEEQ_WRANGLER_TEST_CLI ?? path.join(backend, 'node_modules/wrangler/bin/wrangler.js'),
    'dev', ...(entrypoint ? [entrypoint] : []), '--local', '--ip', '127.0.0.1', '--port', String(port),
    '--inspector-port', String(inspector), '--persist-to', directory,
    '--config', path.join(backend, 'wrangler.toml'), '--log-level',
    process.env.RAFEEQ_WORKER_DEV_LOG_LEVEL ?? 'error',
  ], {
    cwd: backend, windowsHide: true, detached: process.platform !== 'win32',
    env: { ...process.env, WRANGLER_SEND_METRICS: 'false' },
    stdio: ['ignore', 'pipe', 'pipe'],
  });
  let output = '';
  child.stdout.on('data', (data) => { output += data; });
  child.stderr.on('data', (data) => { output += data; });
  const base = `http://127.0.0.1:${port}`;
  const stop = async () => {
    if (child.exitCode === null) {
      if (process.platform === 'win32') {
        spawnSync('taskkill', ['/PID', String(child.pid), '/T', '/F'],
          { windowsHide: true, stdio: 'ignore' });
      } else {
        process.kill(-child.pid, 'SIGTERM');
      }
      await Promise.race([
        new Promise((resolve) => child.once('exit', resolve)), delay(5000, undefined, { ref: false }),
      ]);
    }
    if (process.env.RAFEEQ_WORKER_TEST_LOG) {
      await writeFile(process.env.RAFEEQ_WORKER_TEST_LOG, output);
    }
    const actual = await realpath(directory);
    const relative = path.relative(temporaryRoot, actual);
    if (!relative.startsWith('rafeeq-worker-') ||
        relative.includes(path.sep) || path.isAbsolute(relative)) {
      throw new Error('Refusing cleanup outside the owned worker temp directory');
    }
    await rm(actual, { recursive: true });
  };
  try {
    for (let attempt = 0; attempt < 120; attempt++) {
      if (child.exitCode !== null) throw new Error('Wrangler dev exited: ' + output);
      try {
        const response = await fetch(base + '/review', {
          method: 'OPTIONS', signal: AbortSignal.timeout(1000),
        });
        if (response.status === 204) return { base, stop };
      } catch { /* The owned local listener is not ready yet. */ }
      await delay(250);
    }
    throw new Error('Wrangler local listener did not become ready: ' + output);
  } catch (error) {
    await stop();
    throw error;
  }
}
