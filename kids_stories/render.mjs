// Renders a kids story to MP4: a headless Chrome draws each frame on a canvas
// (engine/index.html + <story>/scenes.js), this script pulls the PNG over the
// Chrome DevTools Protocol and pipes it into ffmpeg (libx264).
//
// No npm dependencies: Node's built-in WebSocket and fetch speak CDP directly.
//
//   node render.mjs noah                  -> noah/preview.mp4
//   node render.mjs noah --stills         -> noah/out/stills/sceneNN.png (mid-scene frames, no encode)
//   node render.mjs noah --out file.mp4
//
// Environment: CHROME=<path to chrome/edge/chromium>, FFMPEG=<path to ffmpeg>.
import { spawn, spawnSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const FPS = 30, WIDTH = 1280, HEIGHT = 720;

const args = process.argv.slice(2);
const story = args.find((a) => !a.startsWith('--'));
if (!story) { console.error('usage: node render.mjs <story> [--stills] [--out file.mp4]'); process.exit(2); }
const stills = args.includes('--stills');
const outIdx = args.indexOf('--out');
const storyDir = path.join(HERE, story);
const outFile = outIdx >= 0 ? path.resolve(args[outIdx + 1]) : path.join(storyDir, 'preview.mp4');

const timing = JSON.parse(fs.readFileSync(path.join(storyDir, 'timing.json'), 'utf8'));

function findExe(envName, candidates) {
  if (process.env[envName]) return process.env[envName];
  for (const c of candidates) {
    if (c.includes(path.sep) || c.includes('/')) { if (fs.existsSync(c)) return c; continue; }
    const r = spawnSync(c, ['-version'], { stdio: 'ignore' });
    if (!r.error) return c;
  }
  throw new Error(`cannot find ${envName.toLowerCase()}; set ${envName}=<path>`);
}
const PF = process.env['ProgramFiles'] || 'C:\\Program Files';
const PF86 = process.env['ProgramFiles(x86)'] || 'C:\\Program Files (x86)';
const chromePath = findExe('CHROME', [
  path.join(PF, 'Google/Chrome/Application/chrome.exe'),
  path.join(PF86, 'Microsoft/Edge/Application/msedge.exe'),
  '/usr/bin/google-chrome', '/usr/bin/chromium', '/usr/bin/chromium-browser',
  '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
]);
const ffmpegPath = stills ? null : findExe('FFMPEG', ['ffmpeg', path.join(PF, 'ShareX/ffmpeg.exe')]);

// ---- a minimal CDP client ----
class CDP {
  constructor(ws) { this.ws = ws; this.id = 0; this.pending = new Map(); this.ws.onmessage = (ev) => this.onMsg(ev); }
  static connect(url) {
    return new Promise((resolve, reject) => {
      const ws = new WebSocket(url);
      ws.onopen = () => resolve(new CDP(ws));
      ws.onerror = (e) => reject(new Error('websocket error ' + (e.message || '')));
    });
  }
  onMsg(ev) {
    const m = JSON.parse(ev.data);
    if (m.id && this.pending.has(m.id)) {
      const { resolve, reject } = this.pending.get(m.id);
      this.pending.delete(m.id);
      m.error ? reject(new Error(m.error.message)) : resolve(m.result);
    }
  }
  send(method, params = {}) {
    const id = ++this.id;
    return new Promise((resolve, reject) => { this.pending.set(id, { resolve, reject }); this.ws.send(JSON.stringify({ id, method, params })); });
  }
  async eval(expr) {
    const r = await this.send('Runtime.evaluate', { expression: expr, awaitPromise: true, returnByValue: true });
    if (r.exceptionDetails) throw new Error('page: ' + (r.exceptionDetails.exception?.description || r.exceptionDetails.text));
    return r.result.value;
  }
  close() { this.ws.close(); }
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function launchChrome() {
  const userDir = fs.mkdtempSync(path.join(os.tmpdir(), 'kids-stories-chrome-'));
  const proc = spawn(chromePath, [
    '--headless=new', '--remote-debugging-port=0', `--user-data-dir=${userDir}`,
    '--no-first-run', '--no-default-browser-check', '--mute-audio', '--hide-scrollbars',
    '--allow-file-access-from-files', '--force-color-profile=srgb', `--window-size=${WIDTH},${HEIGHT}`,
    'about:blank',
  ], { stdio: 'ignore' });
  const portFile = path.join(userDir, 'DevToolsActivePort');
  for (let i = 0; i < 200 && !fs.existsSync(portFile); i++) await sleep(50);
  await sleep(100);
  const port = fs.readFileSync(portFile, 'utf8').split('\n')[0].trim();
  const list = await (await fetch(`http://127.0.0.1:${port}/json/list`)).json();
  const page = list.find((t) => t.type === 'page');
  return { proc, userDir, cdp: await CDP.connect(page.webSocketDebuggerUrl) };
}

const t0 = Date.now();
const { proc, userDir, cdp } = await launchChrome();
try {
  await cdp.send('Page.enable');
  const url = pathToFileURL(path.join(HERE, 'engine', 'index.html')).href;
  await cdp.send('Page.navigate', { url });
  for (let i = 0; i < 200; i++) { if (await cdp.eval('window.__engineReady === true').catch(() => false)) break; await sleep(50); }
  const nScenes = await cdp.eval(`loadStory(${JSON.stringify(story)})`);
  const total = await cdp.eval(`init(${JSON.stringify(timing)})`);
  const frames = Math.round(total * FPS);
  console.log(`${story}: ${nScenes} scenes, ${total.toFixed(2)} s, ${frames} frames`);

  if (stills) {
    const dir = path.join(storyDir, 'out', 'stills');
    fs.mkdirSync(dir, { recursive: true });
    let start = 0;
    for (let i = 0; i < timing.length; i++) {
      for (const [tag, f] of [['a', 0.2], ['b', 0.5], ['c', 0.85]]) {
        const url = await cdp.eval(`renderAt(${start + timing[i].seconds * f})`);
        fs.writeFileSync(path.join(dir, `scene${String(i + 1).padStart(2, '0')}${tag}.png`), Buffer.from(url.split(',')[1], 'base64'));
      }
      start += timing[i].seconds;
    }
    console.log('stills in', dir);
  } else {
    fs.mkdirSync(path.dirname(outFile), { recursive: true });
    const ff = spawn(ffmpegPath, [
      '-y', '-loglevel', 'error', '-f', 'image2pipe', '-framerate', String(FPS), '-c:v', 'png', '-i', '-',
      '-vf', 'scale=out_color_matrix=bt709:out_range=tv,format=yuv420p',
      '-c:v', 'libx264', '-preset', 'slow', '-crf', '18', '-profile:v', 'high', '-tune', 'animation',
      '-x264-params', 'colorprim=bt709:transfer=bt709:colormatrix=bt709',
      '-colorspace', 'bt709', '-color_primaries', 'bt709', '-color_trc', 'bt709', '-color_range', 'tv',
      '-r', String(FPS), '-an', '-movflags', '+faststart', outFile,
    ], { stdio: ['pipe', 'inherit', 'inherit'] });
    const ffDone = new Promise((res, rej) => ff.on('close', (code) => (code === 0 ? res() : rej(new Error('ffmpeg exit ' + code)))));
    for (let f = 0; f < frames; f++) {
      const url = await cdp.eval(`renderAt(${f / FPS})`);
      const buf = Buffer.from(url.slice(url.indexOf(',') + 1), 'base64');
      if (!ff.stdin.write(buf)) await new Promise((r) => ff.stdin.once('drain', r));
      if (f % 150 === 0) process.stdout.write(`frame ${f}/${frames}\r`);
    }
    ff.stdin.end();
    await ffDone;
    console.log(`wrote ${outFile} (${(fs.statSync(outFile).size / 1048576).toFixed(2)} MiB)`);
  }
} finally {
  cdp.close();
  proc.kill();
  await sleep(300);
  try { fs.rmSync(userDir, { recursive: true, force: true }); } catch { /* chrome may still hold a lock */ }
}
console.log(`render time ${((Date.now() - t0) / 1000).toFixed(1)} s`);
