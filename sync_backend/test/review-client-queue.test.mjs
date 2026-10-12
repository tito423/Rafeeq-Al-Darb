import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { test } from 'node:test';
import vm from 'node:vm';

const html = await readFile(new URL('../review-client/index.html', import.meta.url), 'utf8');
const script = html.match(/<script>\s*([\s\S]*?)<\/script>/)[1];
const auth = await readFile(new URL('../review-client/auth.js', import.meta.url), 'utf8');
function page({ fetch = () => { throw new Error('Unexpected network in queue test'); }, seed = {} } = {}) {
  const timers = new Map(); let sequence = 0; let gate = null;
  const elements = new Map();
  const element = () => ({ innerHTML: '', textContent: '', className: '', style: {}, isConnected: true,
    addEventListener(type, handler) { (this.listeners ||= {})[type] = handler; }, click() {}, querySelectorAll() { return []; },
    querySelector(key) { if (!this.children) this.children = new Map(); if (!this.children.has(key)) this.children.set(key, element()); return this.children.get(key); },
    remove() { gate = null; this.isConnected = false; } });
  const document = {
    getElementById(key) { if (!elements.has(key)) elements.set(key, element()); return elements.get(key); },
    querySelector() { return gate; }, querySelectorAll() { return []; }, createElement: element,
    body: { appendChild(value) { gate = value; } }, head: { appendChild() {} },
  };
  const values = new Map(Object.entries(seed));
  const context = vm.createContext({
    console, document, location: { hash: '#intro' }, navigator: {}, URL, Blob, Headers,
    localStorage: { getItem(key) { return values.get(key) ?? null; }, setItem(key, value) { values.set(key, String(value)); } },
    setTimeout(callback, delay) { const id = ++sequence; timers.set(id, { callback, delay }); return id; },
    clearTimeout(id) { timers.delete(id); },
    fetch,
  });
  context.window = context;
  context.addEventListener = () => {};
  context.google = { accounts: { id: { initialize() {}, renderButton() {} } } };
  vm.runInContext(auth, context);
  vm.runInContext(script, context);
  return { context, timers, values, evaluate: (code) => vm.runInContext(code, context) };
}

test('A03 actual paired page never deletes a newer edit during an older successful send', async () => {
  const p = page(); let complete;
  p.context.responsePending = new Promise((resolve) => { complete = resolve; });
  p.evaluate("me = 'canonical';");
  p.evaluate("Object.defineProperty(auth, 'signedIn', {get:()=>true}); Object.defineProperty(auth, 'profile', {get:()=>({sub:'owner'})}); auth.request=()=>responsePending; pending.set('note', {id:'note', note:'older'});");
  const sending = p.evaluate('flush()');
  p.evaluate("pending.set('note', {id:'note', note:'newer'});");
  complete(new Response('{}'));
  await sending;
  assert.equal(p.evaluate("pending.get('note').note"), 'newer');
});

test('A03 actual paired page honors Retry-After and preserves unsent rows', async () => {
  const p = page();
  p.evaluate("me='canonical'; Object.defineProperty(auth,'signedIn',{get:()=>true}); Object.defineProperty(auth,'profile',{get:()=>({sub:'owner'})}); auth.request=async()=>{throw {status:429,retryMs:60000}}; pending.set('note',{id:'note',note:'unsent'});");
  await p.evaluate('flush()');
  assert.equal(p.evaluate('pending.size'), 1);
  assert.ok([...p.timers.values()].some((timer) => timer.delay === 60_000));
  assert.ok(![...p.timers.values()].some((timer) => timer.delay === 500));
});

test('A03 actual paired page stops automatic 401 retries without dropping the queue', async () => {
  const p = page();
  p.evaluate("me='canonical'; Object.defineProperty(auth,'signedIn',{get:()=>true}); Object.defineProperty(auth,'profile',{get:()=>({sub:'owner'})}); auth.request=async()=>{throw {status:401}}; pending.set('note',{id:'note',note:'unsent'});");
  await p.evaluate('flush()');
  assert.equal(p.evaluate('pending.size'), 1);
  assert.equal(p.timers.size, 0);
});

test('A03 old-account failure cannot strand a newly selected account queue', async () => {
  const p = page(); let reject;
  p.context.oldRequest = new Promise((_, fail) => { reject = fail; });
  p.context.account = 'old';
  p.evaluate("me='old-name'; Object.defineProperty(auth,'signedIn',{get:()=>true}); Object.defineProperty(auth,'profile',{get:()=>({sub:account})}); auth.request=()=>oldRequest; pending.set('note',{id:'note',note:'old note'});");
  const sending = p.evaluate('flush()');
  p.context.account = 'new';
  p.evaluate("pending.clear(); pending.set('note',{id:'note',note:'new account note'});");
  reject({ status: 401 });
  await sending;
  assert.equal(p.evaluate("pending.get('note').note"), 'new account note');
  assert.ok([...p.timers.values()].some((timer) => timer.delay === 500));
});

test('A03 account switch leaves the previous reviewer route before any new protected read', async () => {
  let wrongReads = 0;
  const p = page({ fetch: async (url) => {
    if (url.endsWith('/me')) return Response.json({ sub: 'new-subject', reviewer: 'new-name', role: 'reviewer' });
    if (url.includes('?reviewer=old-name')) { wrongReads++; return new Response('{}', { status: 403 }); }
    return Response.json({ reviewers: [] });
  } });
  p.context.location.hash = '#who/old-name';
  p.evaluate('readHash()');
  await p.evaluate("auth.authorize('test-only-credential')");
  assert.equal(p.context.location.hash, 'who');
  assert.equal(wrongReads, 0);
});

test('A03 previous account saved status is cleared when new scope has no notes', async () => {
  const p = page({ fetch: async () => Response.json({ sub: 'new-subject', reviewer: 'new-name', role: 'reviewer' }) });
  p.evaluate("setSync('saved', 'Old account saved status')");
  await p.evaluate("auth.authorize('test-only-credential')");
  assert.equal(p.context.document.getElementById('sync').textContent, '');
});

test('A03 delayed previous reviewer rendering cannot overwrite the current route', async () => {
  const p = page(); let complete;
  p.context.oldPage = new Promise((resolve) => { complete = resolve; });
  p.evaluate("tab='who'; a1='old-name'; auth.request=()=>oldPage;");
  const rendering = p.evaluate('render()');
  p.evaluate("tab='intro'; a1=null;");
  await p.evaluate('render()');
  complete(Response.json({ notes: [{ item_id: 'old-row', note: 'Stale previous account text' }] }));
  await rendering;
  assert.ok(!p.context.document.getElementById('main').innerHTML.includes('Stale previous account text'));
});

test('A03 cleared offline note is replayed as a deletion after login', () => {
  const p = page();
  p.evaluate("me='canonical'; Object.defineProperty(auth,'signedIn',{get:()=>true}); Object.defineProperty(auth,'profile',{get:()=>({sub:'owner'})}); auth.request=()=>new Promise(()=>{}); store={undo:{c:'',ok:false}}; pushAll();");
  assert.equal(p.evaluate('pending.size'), 1);
  assert.equal(p.evaluate("pending.get('undo').note"), '');
  assert.equal(p.evaluate("pending.get('undo').done"), false);
});

test('A03 draft input survives a pending same-account login before textarea blur', async () => {
  let resolveLogin;
  const reply = new Promise((resolve) => { resolveLogin = resolve; });
  const identity = { sub: 'owned-subject', reviewer: 'canonical', role: 'reviewer' };
  const p = page({ seed: { review_profile_v1: JSON.stringify(identity),
    'review_account_v1:owned-subject': '{}' }, fetch: async (url) =>
    url.endsWith('/me') ? reply : Response.json({ saved: 1 }) });
  const login = p.evaluate("auth.authorize('test-only-credential')");
  const input = p.context.document.getElementById('main').listeners.input;
  assert.equal(typeof input, 'function');
  input({ type: 'input', target: { type: 'textarea', value: 'Draft before login reply',
    classList: { toggle() {} }, closest() { return { dataset: { id: 'draft', ex: 'Original interface title', sec: 'Interface' } }; } } });
  assert.equal(JSON.parse(p.values.get('review_account_v1:owned-subject')).draft.c, 'Draft before login reply');
  resolveLogin(Response.json(identity));
  await login;
  assert.equal(p.evaluate("store.draft.c"), 'Draft before login reply');
});
