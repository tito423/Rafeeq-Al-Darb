import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { test } from 'node:test';
import ts from 'typescript';

// Load the actual standalone TS helper; no duplicated reader implementation.
const source = await readFile(new URL('../src/request_body.ts', import.meta.url), 'utf8');
const code = ts.transpileModule(source, { compilerOptions: {
  module: ts.ModuleKind.ES2022, target: ts.ScriptTarget.ES2022,
} }).outputText;
const { readBoundedJson, PayloadTooLarge } = await import(
  'data:text/javascript;base64,' + Buffer.from(code).toString('base64'));

test('A05 declared oversize never acquires the body reader', async () => {
  const request = new Request('http://127.0.0.1/review', {
    method: 'POST', body: '{}', headers: { 'content-length': '33' },
  });
  request.body.getReader = () => assert.fail('Oversized declared body was read');
  await assert.rejects(readBoundedJson(request, 32), PayloadTooLarge);
  await request.body.cancel();
});

test('A05 streaming overflow cancels input and releases the reader', async () => {
  let pulls = 0;
  let cancelled = false;
  const stream = new ReadableStream({
    pull(controller) { pulls++; controller.enqueue(new Uint8Array(16)); },
    cancel() { cancelled = true; },
  });
  const request = new Request('http://127.0.0.1/review', {
    method: 'POST', body: stream, duplex: 'half',
  });
  await assert.rejects(readBoundedJson(request, 32), PayloadTooLarge);
  assert.equal(cancelled, true);
  assert.ok(pulls <= 4, 'The remaining unbounded input must not be consumed');
  assert.equal(request.body.locked, false);
});

test('A05 UTF8 split inside a code point is decoded without alteration', async () => {
  const expected = { text: '🙂' };
  const bytes = new TextEncoder().encode(JSON.stringify(expected));
  const stream = new ReadableStream({ start(controller) {
    for (const byte of bytes) controller.enqueue(Uint8Array.of(byte));
    controller.close();
  } });
  const request = new Request('http://127.0.0.1/review', {
    method: 'POST', body: stream, duplex: 'half',
  });
  assert.deepEqual(await readBoundedJson(request, bytes.length), expected);
  assert.equal(request.body.locked, false);
});

test('A05 malformed length cannot bypass actual streamed byte count', async () => {
  const request = new Request('http://127.0.0.1/review', {
    method: 'POST', body: 'x'.repeat(33), headers: { 'content-length': 'invalid' },
  });
  await assert.rejects(readBoundedJson(request, 32), PayloadTooLarge);
});

test('A05 malformed small JSON still fails as JSON rather than size', async () => {
  const request = new Request('http://127.0.0.1/review', { method: 'POST', body: '{' });
  await assert.rejects(readBoundedJson(request, 32), SyntaxError);
  assert.equal(request.body.locked, false);
});

test('A05 empty body still fails as JSON', async () => {
  const request = new Request('http://127.0.0.1/review', { method: 'POST' });
  await assert.rejects(readBoundedJson(request, 32), SyntaxError);
});
