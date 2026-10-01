// Drawing primitives for the kids-stories renderer.
// Everything is deterministic: no Math.random, no Date, no network. A frame is
// a pure function of (scene, local time, scene duration), so a re-render with
// the same timing.json produces the same pixels.
//
// Hard content rules (docs/kids_stories_brief.md): no human figure of any kind,
// no text of any kind is drawn by this engine.
'use strict';

const K = {};
K.W = 1280;
K.H = 720;
const W = K.W, H = K.H;
const TAU = Math.PI * 2;

// ---------- math ----------
K.clamp = (x, a = 0, b = 1) => (x < a ? a : x > b ? b : x);
K.lerp = (a, b, t) => a + (b - a) * t;
K.seg = (p, a, b) => K.clamp((p - a) / (b - a));
K.smooth = (t) => { t = K.clamp(t); return t * t * (3 - 2 * t); };
K.easeInOut = (t) => { t = K.clamp(t); return t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2; };
K.easeOut = (t) => { t = K.clamp(t); return 1 - Math.pow(1 - t, 3); };
K.easeIn = (t) => { t = K.clamp(t); return t * t * t; };
K.easeOutBack = (t) => { t = K.clamp(t); const c1 = 1.5, c3 = c1 + 1; return 1 + c3 * Math.pow(t - 1, 3) + c1 * Math.pow(t - 1, 2); };
K.fract = (x) => x - Math.floor(x);
K.mod = (a, m) => ((a % m) + m) % m;
// mulberry32 - a seeded PRNG so "random" scatter is identical on every render
K.rng = (seed) => {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6D2B79F5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
};

// ---------- colour ----------
K.hex = (h) => { h = h.replace('#', ''); return [parseInt(h.slice(0, 2), 16), parseInt(h.slice(2, 4), 16), parseInt(h.slice(4, 6), 16)]; };
K.toHex = (r, g, b) => '#' + [r, g, b].map((v) => Math.round(K.clamp(v, 0, 255)).toString(16).padStart(2, '0')).join('');
K.mix = (c1, c2, t) => { const a = K.hex(c1), b = K.hex(c2); t = K.clamp(t); return K.toHex(a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t); };
K.rgba = (c, a) => { const v = K.hex(c); return `rgba(${v[0]},${v[1]},${v[2]},${K.clamp(a)})`; };
K.ramp = (stops, t) => {
  if (t <= stops[0][0]) return stops[0][1];
  for (let i = 1; i < stops.length; i++) {
    if (t <= stops[i][0]) return K.mix(stops[i - 1][1], stops[i][1], (t - stops[i - 1][0]) / (stops[i][0] - stops[i - 1][0]));
  }
  return stops[stops.length - 1][1];
};
// A landscape colour under a light level: 0 = night, 0.5 = dusk, 1 = day.
K.tone = (day, light) => {
  const dusk = K.mix(K.mix(day, '#B8566A', 0.22), '#2A2140', 0.18);
  const night = K.mix(day, '#18203F', 0.74);
  return light >= 0.5 ? K.mix(dusk, day, (light - 0.5) * 2) : K.mix(night, dusk, light * 2);
};

// ---------- sky and light ----------
const OVER = 420; // overscan so camera moves never show an edge
K.sky = (c, cols, y0 = -OVER, y1 = H) => {
  const g = c.createLinearGradient(0, y0 < 0 ? 0 : y0, 0, y1);
  cols.forEach((col, i) => g.addColorStop(i / (cols.length - 1), col));
  c.fillStyle = g;
  c.fillRect(-OVER, -OVER, W + OVER * 2, H + OVER * 2);
};
K.glow = (c, x, y, r, col, a) => {
  const g = c.createRadialGradient(x, y, 0, x, y, r);
  g.addColorStop(0, K.rgba(col, a));
  g.addColorStop(1, K.rgba(col, 0));
  c.fillStyle = g;
  c.fillRect(x - r, y - r, r * 2, r * 2);
};
K.sun = (c, x, y, r, core = '#FFE8A8', glowCol = '#FFC46B', glowA = 0.55, alpha = 1) => {
  c.save();
  c.globalAlpha *= alpha;
  K.glow(c, x, y, r * 5, glowCol, glowA);
  K.glow(c, x, y, r * 2, core, 0.5);
  c.fillStyle = core;
  c.beginPath(); c.arc(x, y, r, 0, TAU); c.fill();
  c.restore();
};
const moonCv = document.createElement('canvas');
moonCv.width = moonCv.height = 256;
K.moon = (c, x, y, r, col = '#FFF4D6', alpha = 1) => {
  c.save();
  c.globalAlpha *= alpha;
  K.glow(c, x, y, r * 3.2, '#DDE6FF', 0.28);
  const m = moonCv.getContext('2d');
  m.clearRect(0, 0, 256, 256);
  m.globalCompositeOperation = 'source-over';
  m.fillStyle = col;
  m.beginPath(); m.arc(128, 128, 100, 0, TAU); m.fill();
  m.globalCompositeOperation = 'destination-out';
  m.beginPath(); m.arc(128 + 52, 128 - 26, 90, 0, TAU); m.fill();
  m.globalCompositeOperation = 'source-over';
  c.drawImage(moonCv, x - r * 1.28, y - r * 1.28, r * 2.56, r * 2.56);
  c.restore();
};
K.stars = (c, seed, n, alpha, t = 0, yMax = 420) => {
  if (alpha <= 0.01) return;
  const r = K.rng(seed);
  c.save();
  for (let i = 0; i < n; i++) {
    const x = r() * (W + 400) - 200, y = r() * (yMax + 200) - 200, s = 0.8 + r() * 1.8, ph = r() * TAU;
    const tw = 0.65 + 0.35 * Math.sin(t * 1.3 + ph);
    c.fillStyle = K.rgba('#FFF6DE', alpha * tw);
    c.beginPath(); c.arc(x, y, s, 0, TAU); c.fill();
  }
  c.restore();
};
K.cloud = (c, x, y, s, col, alpha = 1) => {
  c.save();
  c.globalAlpha *= alpha;
  c.fillStyle = col;
  c.beginPath();
  const bumps = [[-58, -4, 34], [-18, -24, 46], [30, -16, 40], [66, 0, 28]];
  for (const [bx, by, br] of bumps) { c.moveTo(x + (bx + br) * s, y + by * s); c.arc(x + bx * s, y + by * s, br * s, 0, TAU); }
  c.roundRect(x - 92 * s, y - 14 * s, 186 * s, 42 * s, 21 * s);
  c.fill();
  c.restore();
};

// ---------- land ----------
K.ridgeY = (x, seed, amp, scale) =>
  amp * (0.55 * Math.sin(x * 0.0042 * scale + seed) + 0.3 * Math.sin(x * 0.011 * scale + seed * 2.3) + 0.15 * Math.sin(x * 0.023 * scale + seed * 4.1));
K.ridge = (c, baseY, amp, seed, scale, col) => {
  c.fillStyle = col;
  c.beginPath();
  c.moveTo(-OVER, H + OVER);
  for (let x = -OVER; x <= W + OVER; x += 8) c.lineTo(x, baseY - K.ridgeY(x, seed, amp, scale));
  c.lineTo(W + OVER, H + OVER);
  c.closePath();
  c.fill();
};
// A mountain with a lit left face and a shaded right face. `top` is the width
// of a flat summit (0 = a peak).
K.mountain = (c, cx, baseY, w, h, col, shade, top = 0) => {
  const L = cx - w / 2, R = cx + w / 2, ty = baseY - h;
  c.fillStyle = col;
  c.beginPath();
  c.moveTo(L, baseY);
  c.quadraticCurveTo(cx - w * 0.28, baseY - h * 0.55, cx - top / 2, ty);
  c.lineTo(cx + top / 2, ty);
  c.quadraticCurveTo(cx + w * 0.28, baseY - h * 0.55, R, baseY);
  c.closePath();
  c.fill();
  c.fillStyle = shade;
  c.beginPath();
  c.moveTo(cx + top / 2, ty);
  c.quadraticCurveTo(cx + w * 0.28, baseY - h * 0.55, R, baseY);
  c.lineTo(cx + w * 0.06, baseY);
  c.quadraticCurveTo(cx + w * 0.1, baseY - h * 0.5, cx + top * 0.1, ty);
  c.closePath();
  c.fill();
};
K.palm = (c, x, groundY, h, trunk, leaf, sway = 0) => {
  c.save();
  c.strokeStyle = trunk;
  c.lineWidth = h * 0.07;
  c.lineCap = 'round';
  const tx = x + h * 0.12 + sway * h * 0.04, ty = groundY - h;
  c.beginPath(); c.moveTo(x, groundY); c.quadraticCurveTo(x + h * 0.02, groundY - h * 0.6, tx, ty); c.stroke();
  c.fillStyle = leaf;
  for (let i = 0; i < 7; i++) {
    const a = -Math.PI / 2 + (i - 3) * 0.52 + sway * 0.06;
    const len = h * (0.52 - Math.abs(i - 3) * 0.035);
    const ex = tx + Math.cos(a) * len, ey = ty + Math.sin(a) * len * 0.55 + len * 0.28;
    c.beginPath();
    c.moveTo(tx, ty);
    c.quadraticCurveTo((tx + ex) / 2 + Math.sin(a) * len * 0.18, (ty + ey) / 2 - len * 0.32, ex, ey);
    c.quadraticCurveTo((tx + ex) / 2, (ty + ey) / 2 - len * 0.08, tx, ty);
    c.fill();
  }
  c.restore();
};
K.shrub = (c, x, y, s, col) => {
  c.fillStyle = col;
  c.beginPath();
  for (const [bx, by, br] of [[-10, 0, 10], [0, -7, 12], [11, -1, 9]]) { c.moveTo(x + (bx + br) * s, y + by * s); c.arc(x + bx * s, y + by * s, br * s, Math.PI, TAU); }
  c.rect(x - 20 * s, y - 1, 40 * s, 3 * s);
  c.fill();
};

// Flat-roofed mud-brick houses: an old valley town. Walls, a parapet, an arched
// doorway and small windows. Windows may glow at night; no figures, ever.
K.house = (c, x, groundY, w, h, wall, shade, dark, glow = 0) => {
  c.fillStyle = wall;
  c.fillRect(x, groundY - h, w, h);
  c.fillRect(x - 3, groundY - h - 5, w + 6, 6);
  c.fillStyle = shade;
  c.fillRect(x + w * 0.76, groundY - h - 5, w * 0.24 + 3, h + 5);
  // doorway
  const dw = Math.max(8, w * 0.2), dh = Math.min(h * 0.5, dw * 1.7), dx = x + w * 0.3;
  c.fillStyle = dark;
  c.beginPath(); c.moveTo(dx, groundY); c.lineTo(dx, groundY - dh + dw / 2); c.arc(dx + dw / 2, groundY - dh + dw / 2, dw / 2, Math.PI, 0); c.lineTo(dx + dw, groundY); c.fill();
  // windows
  const ww = Math.max(4, w * 0.1);
  const win = glow > 0 ? K.mix(dark, '#FFC869', glow) : dark;
  c.fillStyle = win;
  if (h > 40) { c.fillRect(x + w * 0.58, groundY - h * 0.72, ww, ww * 1.2); }
  if (w > 50) { c.fillRect(x + w * 0.12, groundY - h * 0.72, ww, ww * 1.2); }
};
K.town = (c, seed, n, x0, x1, groundY, scale, light, glow) => {
  const r = K.rng(seed);
  const hs = [];
  for (let i = 0; i < n; i++) {
    const w = (38 + r() * 46) * scale, h = (34 + r() * 44) * scale, x = x0 + r() * (x1 - x0 - w), row = Math.floor(r() * 3);
    hs.push({ x, w, h, row, v: r() });
  }
  hs.sort((a, b) => a.row - b.row);
  for (const hh of hs) {
    const gy = groundY + hh.row * 9 * scale;
    const base = K.mix('#E6BE8A', '#D7A472', hh.v);
    K.house(c, hh.x, gy, hh.w, hh.h, K.tone(base, light), K.tone(K.mix(base, '#8A5A3C', 0.35), light), K.tone('#5A3A2A', light), glow * (hh.v > 0.35 ? 1 : 0));
  }
};

// Plain carved stones. Deliberately abstract: no heads, faces or limbs, nothing
// that reads as a figure, and no names or labels (the brief: "plain unnamed
// stone shapes").
K.stone = (c, kind, x, groundY, h, col, lit, shade) => {
  const w = h * 0.42;
  c.save();
  c.translate(x, groundY);
  const shapes = {
    slab: () => { c.beginPath(); c.moveTo(-w / 2, 0); c.lineTo(-w / 2, -h + w / 2); c.arc(0, -h + w / 2, w / 2, Math.PI, 0); c.lineTo(w / 2, 0); c.closePath(); },
    obelisk: () => { c.beginPath(); c.moveTo(-w * 0.5, 0); c.lineTo(-w * 0.32, -h * 0.9); c.lineTo(0, -h); c.lineTo(w * 0.32, -h * 0.9); c.lineTo(w * 0.5, 0); c.closePath(); },
    stepped: () => { c.beginPath(); c.moveTo(-w * 0.7, 0); c.lineTo(-w * 0.7, -h * 0.36); c.lineTo(-w * 0.5, -h * 0.36); c.lineTo(-w * 0.5, -h * 0.7); c.lineTo(-w * 0.3, -h * 0.7); c.lineTo(-w * 0.3, -h); c.lineTo(w * 0.3, -h); c.lineTo(w * 0.3, -h * 0.7); c.lineTo(w * 0.5, -h * 0.7); c.lineTo(w * 0.5, -h * 0.36); c.lineTo(w * 0.7, -h * 0.36); c.lineTo(w * 0.7, 0); c.closePath(); },
    boulder: () => { c.beginPath(); c.moveTo(-w * 0.8, 0); c.quadraticCurveTo(-w * 0.95, -h * 0.55, -w * 0.35, -h * 0.92); c.quadraticCurveTo(w * 0.1, -h * 1.06, w * 0.55, -h * 0.8); c.quadraticCurveTo(w * 0.95, -h * 0.45, w * 0.8, 0); c.closePath(); },
    column: () => { c.beginPath(); c.rect(-w * 0.36, -h * 0.92, w * 0.72, h * 0.92); c.rect(-w * 0.5, -h, w, h * 0.1); c.rect(-w * 0.5, -h * 0.1, w, h * 0.1); },
  };
  shapes[kind]();
  c.fillStyle = col; c.fill();
  c.save(); c.clip();
  c.fillStyle = shade; c.fillRect(w * 0.08, -h * 1.1, w, h * 1.2);
  c.fillStyle = lit; c.fillRect(-w, -h * 1.1, w * 0.35, h * 1.2);
  c.strokeStyle = K.rgba('#3B2C24', 0.35); c.lineWidth = Math.max(1, h * 0.012);
  c.beginPath(); c.moveTo(-w * 0.2, -h * 0.55); c.lineTo(-w * 0.05, -h * 0.47); c.lineTo(-w * 0.12, -h * 0.35); c.stroke();
  c.restore();
  c.restore();
};

// ---------- water ----------
K.water = (c, surf, top, bottom, colTop, colBot, foam, foamW = 3, step = 6) => {
  const g = c.createLinearGradient(0, top, 0, bottom);
  g.addColorStop(0, colTop); g.addColorStop(1, colBot);
  c.fillStyle = g;
  c.beginPath();
  c.moveTo(-OVER, H + OVER);
  for (let x = -OVER; x <= W + OVER; x += step) c.lineTo(x, surf(x));
  c.lineTo(W + OVER, H + OVER);
  c.closePath();
  c.fill();
  if (foam) {
    c.strokeStyle = foam; c.lineWidth = foamW; c.lineJoin = 'round';
    c.beginPath();
    for (let x = -OVER; x <= W + OVER; x += step) (x === -OVER ? c.moveTo(x, surf(x)) : c.lineTo(x, surf(x)));
    c.stroke();
  }
};
K.rain = (c, t, seed, n, alpha, vx, vy, len, col = '#DCE8F5', lw = 2) => {
  if (alpha <= 0.01) return;
  const r = K.rng(seed);
  c.save();
  c.strokeStyle = K.rgba(col, alpha); c.lineWidth = lw; c.lineCap = 'round';
  c.beginPath();
  const MW = W + 2 * OVER, MH = H + 2 * OVER;
  for (let i = 0; i < n; i++) {
    const x0 = r() * MW, y0 = r() * MH, sp = 0.8 + r() * 0.4;
    const y = K.mod(y0 + t * vy * sp, MH) - OVER, x = K.mod(x0 + t * vx * sp, MW) - OVER;
    c.moveTo(x, y); c.lineTo(x - (vx / vy) * len, y - len);
  }
  c.stroke();
  c.restore();
};

// ---------- the ark ----------
// Local frame: deck line y=0, hull bottom y=140, ends rise to y≈-50, ground
// (when on land, on timber blocks) at y=200. Built plank by plank with pegs:
// al-Qamar 54:13 «ذات ألواح ودسر».
const ARK_ROWS = 7, ARK_TOP = -52, ARK_BOT = 140, ARK_RH = (ARK_BOT - ARK_TOP) / ARK_ROWS;
K.ARK = { groundY: 200, doorX0: -178, doorX1: -106, doorY0: 14, doorY1: 122 };
const arkHull = (c) => {
  c.beginPath();
  c.moveTo(-365, -52);
  c.quadraticCurveTo(-335, 140, -185, 140);
  c.lineTo(185, 140);
  c.quadraticCurveTo(335, 140, 360, -48);
  c.quadraticCurveTo(330, -4, 300, 0);
  c.lineTo(-305, 0);
  c.quadraticCurveTo(-335, -4, -365, -52);
  c.closePath();
};
const arkPlanks = (() => {
  const list = [];
  for (let i = 0; i < 4; i++) list.push({ kind: 'block', x: -150 + i * 100 });
  for (let r = ARK_ROWS - 1; r >= 0; r--) {
    const y0 = ARK_TOP + r * ARK_RH;
    const sp = r % 2 ? [-420, -150, 110, 420] : [-420, -90, 170, 420];
    for (let s = 0; s < 3; s++) list.push({ kind: 'hull', x0: sp[s], x1: sp[s + 1], y0, y1: y0 + ARK_RH, r });
  }
  for (let r = 0; r < 4; r++) {
    const y1 = -r * 27, y0 = y1 - 27;
    const sp = r % 2 ? [-215, -20, 175] : [-215, -70, 175];
    for (let s = 0; s < 2; s++) list.push({ kind: 'cabin', x0: sp[s], x1: sp[s + 1], y0, y1, r });
  }
  list.push({ kind: 'roof', band: 0 }, { kind: 'roof', band: 1 });
  const rr = K.rng(54013);
  for (const p of list) p.v = rr();
  return list;
})();
K.arkPlankCount = arkPlanks.length;
const peg = (c, x, y, k) => {
  if (k <= 0) return;
  const s = K.easeOutBack(k);
  c.fillStyle = '#3E2819'; c.beginPath(); c.arc(x, y, 3.6 * s, 0, TAU); c.fill();
  c.fillStyle = '#7A5236'; c.beginPath(); c.arc(x - 0.8, y - 0.8, 1.4 * s, 0, TAU); c.fill();
};
const woodPlank = (c, x, y, w, h, base, v) => {
  c.fillStyle = K.mix(base, '#3A2416', 0.55);
  c.fillRect(x, y, w, h);
  c.fillStyle = base;
  c.fillRect(x + 1.5, y + 1.5, w - 3, h - 3);
  c.fillStyle = K.rgba('#FFE2B8', 0.18);
  c.fillRect(x + 1.5, y + 1.5, w - 3, 3);
  c.strokeStyle = K.rgba('#4A2E1C', 0.28); c.lineWidth = 1;
  c.beginPath();
  const gy = y + h * (0.45 + v * 0.25);
  c.moveTo(x + 8, gy); c.bezierCurveTo(x + w * 0.35, gy - 2, x + w * 0.6, gy + 3, x + w - 8, gy);
  c.stroke();
};
// opts: { build 0..1, blocks bool, door 'none'|'open'|'closed', ramp bool, light 0..1 }
K.ark = (c, x, y, s, opts = {}) => {
  const build = opts.build ?? 1, light = opts.light ?? 1;
  const kf = build * arkPlanks.length;
  const hullCols = ['#A86C40', '#9A6139', '#B27849'];
  const tn = (col) => K.tone(col, light);
  // pegs follow the plank by default; opts.pegs (0..1) drives them on their own
  // clock so they can be tapped in on the word «ومسامير»
  const NP = arkPlanks.length;
  const pegK = (a, i) => (opts.pegs === undefined ? K.clamp((a - 0.7) / 0.3) : (a >= 1 ? K.clamp((opts.pegs - (i / NP) * 0.75) / 0.25) : 0));
  c.save();
  c.translate(x, y);
  c.scale(s, s);
  if (opts.ramp) {
    // opts.rampDown 0..1 slides the ramp out of the door (stowed, it lies
    // behind the hull planks, which are drawn after it)
    c.save();
    const rr = 1 - (opts.rampDown ?? 1);
    c.translate(rr * 322, -rr * 78);
    c.fillStyle = tn('#6E4529');
    c.beginPath(); c.moveTo(-500, 200); c.lineTo(-178, 122); c.lineTo(-100, 122); c.lineTo(-100, 134); c.lineTo(-178, 134); c.lineTo(-470, 206); c.closePath(); c.fill();
    c.fillStyle = tn('#9C6A42');
    c.beginPath(); c.moveTo(-500, 200); c.lineTo(-178, 122); c.lineTo(-100, 122); c.lineTo(-100, 127); c.lineTo(-178, 127); c.lineTo(-490, 204); c.closePath(); c.fill();
    c.strokeStyle = tn('#5A3822'); c.lineWidth = 2;
    for (let i = 1; i < 8; i++) { const u = i / 8, px = -500 + (322) * u, py = 200 - 78 * u; c.beginPath(); c.moveTo(px, py); c.lineTo(px + 2, py + 5); c.stroke(); }
    c.restore();
  }
  arkPlanks.forEach((pl, i) => {
    const a = K.clamp(kf - i);
    if (a <= 0) return;
    if (pl.kind === 'block' && !opts.blocks) return;
    const e = K.easeOut(K.clamp(a / 0.7));
    c.save();
    c.globalAlpha *= K.clamp(a / 0.3);
    if (opts.from) {
      // fly in along an arc from the pile (local units), turning as it lands
      const u = K.easeInOut(K.clamp(a / 0.8)), cx0 = pl.kind === 'hull' || pl.kind === 'cabin' ? (pl.x0 + pl.x1) / 2 : 0;
      c.translate((1 - u) * (opts.from[0] - cx0), (1 - u) * opts.from[1] - Math.sin(Math.PI * u) * 150);
      c.rotate((1 - u) * 0.5 * (pl.v - 0.5));
    } else {
      c.translate(0, (1 - e) * -64);
    }
    if (pl.kind === 'block') {
      woodPlank(c, pl.x - 20, 140, 40, 60, tn('#7A4E2E'), pl.v);
    } else if (pl.kind === 'hull') {
      c.save(); arkHull(c); c.clip();
      const base = tn(K.mix(hullCols[Math.floor(pl.v * 3)], '#5E3A22', pl.r / ARK_ROWS * 0.45));
      woodPlank(c, pl.x0, pl.y0, pl.x1 - pl.x0, pl.y1 - pl.y0, base, pl.v);
      c.restore();
      const k = pegK(a, i), py = (pl.y0 + pl.y1) / 2;
      if (pl.x0 > -400) { peg(c, pl.x0 + 9, py, k); K.puff(c, pl.x0 + 9, py, k * 1.6, 1.2); }
      if (pl.x1 < 400) { peg(c, pl.x1 - 9, py, k); K.puff(c, pl.x1 - 9, py, k * 1.6, 1.2); }
    } else if (pl.kind === 'cabin') {
      woodPlank(c, pl.x0, pl.y0, pl.x1 - pl.x0, pl.y1 - pl.y0, tn(K.mix('#B98252', '#9A6A43', pl.v)), pl.v);
      const k = pegK(a, i), py = (pl.y0 + pl.y1) / 2;
      peg(c, pl.x0 + 8, py, k); peg(c, pl.x1 - 8, py, k);
      K.puff(c, pl.x0 + 8, py, k * 1.6, 1.2); K.puff(c, pl.x1 - 8, py, k * 1.6, 1.2);
    } else if (pl.kind === 'roof') {
      c.fillStyle = tn(pl.band ? '#7B4A30' : '#8C5536');
      c.beginPath();
      if (pl.band === 0) { c.moveTo(-240, -106); c.lineTo(200, -106); c.lineTo(168, -130); c.lineTo(-208, -130); }
      else { c.moveTo(-208, -130); c.lineTo(168, -130); c.lineTo(118, -150); c.lineTo(-158, -150); }
      c.closePath(); c.fill();
      c.fillStyle = K.rgba('#FFE2B8', 0.14);
      c.fillRect(pl.band ? -158 : -208, pl.band ? -150 : -130, pl.band ? 276 : 376, 3);
    }
    c.restore();
  });
  if (build >= 0.999) {
    // vents under the roof
    c.fillStyle = tn('#3A2519');
    for (const vx of [-160, -90, -20, 50, 120]) c.fillRect(vx, -98, 16, 11);
    const d = K.ARK;
    if (opts.door === 'open') {
      c.fillStyle = tn('#6E4529'); c.fillRect(d.doorX0 - 5, d.doorY0 - 5, d.doorX1 - d.doorX0 + 10, d.doorY1 - d.doorY0 + 5);
      c.fillStyle = '#26170F'; c.fillRect(d.doorX0, d.doorY0, d.doorX1 - d.doorX0, d.doorY1 - d.doorY0);
    } else if (opts.door === 'closed') {
      c.fillStyle = tn('#6E4529'); c.fillRect(d.doorX0 - 5, d.doorY0 - 5, d.doorX1 - d.doorX0 + 10, d.doorY1 - d.doorY0 + 5);
      for (let i = 0; i < 3; i++) woodPlank(c, d.doorX0 + i * 24, d.doorY0, 24, d.doorY1 - d.doorY0, tn('#94603A'), 0.3 + i * 0.2);
    }
  }
  c.restore();
};
// The ark's silhouette (hull + cabin + roof) as a path in its local frame.
K.arkOutline = (c) => {
  arkHull(c);
  c.moveTo(-215, 0); c.lineTo(-215, -106); c.lineTo(175, -106); c.lineTo(175, 0);
  c.moveTo(-240, -106); c.lineTo(-158, -150); c.lineTo(118, -150); c.lineTo(200, -106);
};
// Map a point in the ark's local frame to world space.
K.arkPt = (x, y, s, lx, ly) => [x + lx * s, y + ly * s];

// ---------- animals ----------
// Flat, friendly side views, facing right. Origin is the ground under the body.
const leg = (c, x, y, len, w, col, ang) => {
  c.save(); c.translate(x, y); c.rotate(ang);
  c.fillStyle = col; c.beginPath(); c.roundRect(-w / 2, -w / 2, w, len + w / 2, w / 2); c.fill();
  c.restore();
};
const legs = (c, pts, hipY, len, w, col, phase, far) => {
  pts.forEach((lx, i) => {
    const ang = Math.sin(phase + (i ? Math.PI : 0) + (far ? Math.PI / 2 : 0)) * 0.38;
    leg(c, lx, hipY, len, w, col, ang);
  });
};
const eye = (c, x, y, r) => { c.fillStyle = '#2B1D16'; c.beginPath(); c.arc(x, y, r, 0, TAU); c.fill(); };
K.ANIMALS = {
  elephant: { len: 120, draw(c, ph, col) {
    const body = col || '#9C929B', dark = K.mix(body, '#3E3440', 0.3);
    legs(c, [-30, 22], -34, 30, 17, dark, ph, true);
    c.fillStyle = body; c.beginPath(); c.ellipse(0, -60, 50, 32, 0, 0, TAU); c.fill();
    c.strokeStyle = body; c.lineWidth = 3; c.beginPath(); c.moveTo(-48, -64); c.quadraticCurveTo(-60, -50, -56, -38); c.stroke();
    c.beginPath(); c.arc(50, -72, 23, 0, TAU); c.fill();
    c.lineWidth = 11; c.lineCap = 'round'; c.beginPath(); c.moveTo(66, -66); c.quadraticCurveTo(74 + Math.sin(ph) * 3, -40, 70 + Math.sin(ph) * 4, -24); c.stroke();
    c.fillStyle = dark; c.beginPath(); c.ellipse(40, -70, 13, 18, -0.15, 0, TAU); c.fill();
    c.fillStyle = '#FFF6E4'; c.beginPath(); c.moveTo(62, -58); c.quadraticCurveTo(72, -54, 76, -60); c.lineTo(64, -62); c.fill();
    eye(c, 60, -78, 2.6);
    legs(c, [-22, 32], -34, 30, 17, body, ph + 0.4, false);
  } },
  camel: { len: 105, draw(c, ph, col) {
    const body = col || '#C99A5E', dark = K.mix(body, '#5A3A20', 0.3);
    legs(c, [-26, 24], -52, 48, 8, dark, ph, true);
    c.fillStyle = body;
    c.beginPath(); c.ellipse(0, -64, 40, 18, 0, 0, TAU); c.fill();
    c.beginPath(); c.ellipse(-4, -80, 21, 17, 0, Math.PI, TAU); c.fill();
    c.strokeStyle = body; c.lineWidth = 13; c.lineCap = 'round';
    c.beginPath(); c.moveTo(30, -66); c.quadraticCurveTo(54, -66, 54, -98); c.stroke();
    c.beginPath(); c.ellipse(62, -101, 13, 7, 0.1, 0, TAU); c.fill();
    c.lineWidth = 3; c.beginPath(); c.moveTo(-38, -66); c.quadraticCurveTo(-46, -56, -44, -46); c.stroke();
    eye(c, 60, -104, 2);
    legs(c, [-20, 30], -52, 48, 8, body, ph + 0.4, false);
  } },
  lion: { len: 95, draw(c, ph, col) {
    const body = col || '#D9A441', mane = K.mix(body, '#8A4A1E', 0.55), dark = K.mix(body, '#5A3A20', 0.3);
    legs(c, [-24, 20], -30, 26, 10, dark, ph, true);
    c.strokeStyle = body; c.lineWidth = 4; c.lineCap = 'round';
    c.beginPath(); c.moveTo(-36, -40); c.quadraticCurveTo(-56, -44, -58, -64); c.stroke();
    c.fillStyle = mane; c.beginPath(); c.arc(-58, -65, 6, 0, TAU); c.fill();
    c.fillStyle = body; c.beginPath(); c.ellipse(0, -42, 38, 17, 0, 0, TAU); c.fill();
    c.fillStyle = mane; c.beginPath(); c.arc(34, -54, 21, 0, TAU); c.fill();
    c.fillStyle = body; c.beginPath(); c.arc(40, -52, 13, 0, TAU); c.fill();
    c.beginPath(); c.ellipse(51, -48, 7, 5, 0, 0, TAU); c.fill();
    eye(c, 44, -56, 2);
    legs(c, [-18, 26], -30, 26, 10, body, ph + 0.4, false);
  } },
  sheep: { len: 70, draw(c, ph, col) {
    const wool = col || '#F2E6CF', dark = '#4A3A32';
    legs(c, [-14, 14], -18, 16, 6, dark, ph, true);
    c.fillStyle = wool; c.beginPath();
    for (const [bx, by, br] of [[-18, -30, 12], [-4, -36, 14], [12, -33, 13], [-10, -24, 12], [8, -24, 12]]) { c.moveTo(bx + br, by); c.arc(bx, by, br, 0, TAU); }
    c.fill();
    c.fillStyle = dark; c.beginPath(); c.ellipse(28, -36, 10, 7, 0.35, 0, TAU); c.fill();
    c.beginPath(); c.ellipse(22, -41, 6, 3, -0.4, 0, TAU); c.fill();
    c.fillStyle = '#F2E6CF'; c.beginPath(); c.arc(31, -38, 1.6, 0, TAU); c.fill();
    legs(c, [-8, 18], -18, 16, 6, dark, ph + 0.4, false);
  } },
  horse: { len: 100, draw(c, ph, col) {
    const body = col || '#9A5B36', dark = K.mix(body, '#2A1A12', 0.35), mane = '#3E2A1E';
    legs(c, [-26, 24], -44, 40, 8, dark, ph, true);
    c.strokeStyle = mane; c.lineWidth = 6; c.lineCap = 'round';
    c.beginPath(); c.moveTo(-36, -58); c.quadraticCurveTo(-50, -48, -48, -30); c.stroke();
    c.fillStyle = body; c.beginPath(); c.ellipse(0, -56, 38, 16, 0, 0, TAU); c.fill();
    c.strokeStyle = body; c.lineWidth = 16;
    c.beginPath(); c.moveTo(26, -60); c.lineTo(40, -86); c.stroke();
    c.beginPath(); c.ellipse(50, -86, 16, 8, 0.45, 0, TAU); c.fill();
    c.strokeStyle = mane; c.lineWidth = 5; c.beginPath(); c.moveTo(24, -66); c.lineTo(36, -94); c.stroke();
    eye(c, 46, -91, 2);
    legs(c, [-20, 30], -44, 40, 8, body, ph + 0.4, false);
  } },
};
K.ANIMAL_COL = { elephant: '#9C929B', camel: '#C99A5E', lion: '#D9A441', sheep: '#F2E6CF', horse: '#9A5B36' };
// shade > 0 darkens the animal (the partner walking on the far side).
K.animal = (c, type, x, y, s, phase, ang = 0, shade = 0) => {
  const a = K.ANIMALS[type];
  c.save();
  c.translate(x, y - Math.abs(Math.sin(phase)) * 1.6 * s);
  c.rotate(ang);
  c.scale(s, s);
  a.draw(c, phase, shade > 0 ? K.mix(K.ANIMAL_COL[type], '#4A3A40', shade) : null);
  c.restore();
};

// ---------- v2: camera, parallax, word beats ----------
// K.CAM is set by the engine before each scene draw: the scene camera's centre
// (x, y) and zoom z. K.par draws a layer at depth f: f = 1 sits on the focal
// plane (moves with the camera), f < 1 is farther (moves and zooms less),
// f > 1 is foreground (moves more). A frame stays a pure function of time.
K.CAM = { x: W / 2, y: H / 2, z: 1 };
K.par = (c, f, fn) => {
  const { x, y, z } = K.CAM, s = Math.pow(z, f - 1);
  c.save();
  c.translate(x, y); c.scale(s, s);
  c.translate(-(W / 2 + f * (x - W / 2)), -(H / 2 + f * (y - H / 2)));
  fn();
  c.restore();
};
// Word timings (words.json, set by the renderer). K.beat(scene, 'word', n)
// returns the start second of the n-th spoken word containing that text
// (diacritics ignored), or `fallback` seconds if the recogniser spelt it
// differently. Visual events are keyed to these so they land on the voice.
K.WORDS = null;
const bare = (s) => s.replace(/[ً-ٰٟـ،,.]/g, '');
K.beat = (scene, word, fallback, n = 1) => {
  const list = K.WORDS && K.WORDS[String(scene)];
  if (list) {
    const w = bare(word);
    let k = 0;
    for (const e of list) if (bare(e.word).includes(w) && ++k === n) return e.t;
  }
  return fallback;
};
// 0 before `at`, eased to 1 over `dur` seconds after it.
K.after = (t, at, dur = 0.6, ease = K.easeInOut) => ease(K.clamp((t - at) / dur));

// ---------- v2: atmosphere and life ----------
K.haze = (c, y0, y1, col, a) => {
  const g = c.createLinearGradient(0, y0, 0, y1);
  g.addColorStop(0, K.rgba(col, 0)); g.addColorStop(0.55, K.rgba(col, a)); g.addColorStop(1, K.rgba(col, a * 0.6));
  c.fillStyle = g; c.fillRect(-OVER, y0, W + OVER * 2, y1 - y0);
};
// God rays from (x, y): soft wedges added with 'lighter'.
K.rays = (c, x, y, n, len, a0, a1, col, alpha, t = 0) => {
  if (alpha <= 0.005) return;
  c.save();
  c.globalCompositeOperation = 'lighter';
  for (let i = 0; i < n; i++) {
    const u = n === 1 ? 0.5 : i / (n - 1);
    const a = K.lerp(a0, a1, u) + Math.sin(t * 0.35 + i * 1.7) * 0.025;
    const wdt = 0.035 + 0.03 * (0.5 + 0.5 * Math.sin(i * 2.3 + t * 0.5));
    const g = c.createRadialGradient(x, y, 0, x, y, len);
    g.addColorStop(0, K.rgba(col, alpha * (0.7 + 0.3 * Math.sin(t * 0.8 + i))));
    g.addColorStop(1, K.rgba(col, 0));
    c.fillStyle = g;
    c.beginPath(); c.moveTo(x, y); c.arc(x, y, len, a - wdt, a + wdt); c.closePath(); c.fill();
  }
  c.restore();
};
// Floating motes / dust in light.
K.dust = (c, t, seed, n, col, alpha, x0 = -100, x1 = W + 100, y0 = 0, y1 = H, vx = 6) => {
  if (alpha <= 0.01) return;
  const r = K.rng(seed);
  c.save();
  for (let i = 0; i < n; i++) {
    const bx = r(), by = r(), s = 0.8 + r() * 2.2, ph = r() * TAU, sp = 0.5 + r();
    const x = x0 + K.mod(bx * (x1 - x0) + t * vx * sp + Math.sin(t * 0.6 + ph) * 14, x1 - x0);
    const y = y0 + K.mod(by * (y1 - y0) + Math.sin(t * 0.45 + ph * 2) * 18 - t * 3 * sp, y1 - y0);
    c.fillStyle = K.rgba(col, alpha * (0.5 + 0.5 * Math.sin(t * 1.4 + ph)));
    c.beginPath(); c.arc(x, y, s, 0, TAU); c.fill();
  }
  c.restore();
};
// A flock far off: small flapping strokes drifting across.
K.birds = (c, t, seed, n, x0, y0, spread, vx, s, col, alpha = 1) => {
  if (alpha <= 0.01) return;
  const r = K.rng(seed);
  c.save();
  c.strokeStyle = K.rgba(col, alpha); c.lineCap = 'round'; c.lineJoin = 'round';
  for (let i = 0; i < n; i++) {
    const ox = (r() - 0.5) * spread, oy = (r() - 0.5) * spread * 0.35, ph = r() * TAU, sz = s * (0.7 + r() * 0.5);
    const x = K.mod(x0 + ox + vx * t + 300, W + 700) - 350, y = y0 + oy + Math.sin(t * 0.9 + ph) * 6;
    const f = Math.sin(t * 9 + ph) * 0.8;
    c.lineWidth = Math.max(1.2, sz * 0.18);
    c.beginPath();
    c.moveTo(x - sz, y - f * sz * 0.6); c.quadraticCurveTo(x - sz * 0.45, y - sz * 0.35 - f * sz * 0.2, x, y);
    c.quadraticCurveTo(x + sz * 0.45, y - sz * 0.35 - f * sz * 0.2, x + sz, y - f * sz * 0.6);
    c.stroke();
  }
  c.restore();
};
// Grass blades along a ground line, swaying in a wind that travels sideways.
K.grass = (c, seed, x0, x1, y, h, col, t, wind = 1, density = 0.35) => {
  const r = K.rng(seed);
  c.fillStyle = col;
  c.beginPath();
  for (let x = x0; x < x1; x += 1 / density) {
    const hh = h * (0.5 + r() * 0.7), xx = x + r() * 4;
    const b = (Math.sin(t * 1.7 - xx * 0.012) * 0.5 + 0.5) * wind * hh * 0.45 + r() * 3;
    c.moveTo(xx - 1.6, y); c.quadraticCurveTo(xx + b * 0.3, y - hh * 0.6, xx + b, y - hh); c.quadraticCurveTo(xx + b * 0.3 + 1, y - hh * 0.55, xx + 1.6, y);
  }
  c.fill();
};
// Spray / splash droplets thrown up from a line and falling back.
K.spray = (c, t, seed, n, x0, x1, y, hMax, col, alpha) => {
  if (alpha <= 0.01) return;
  const r = K.rng(seed);
  c.save();
  for (let i = 0; i < n; i++) {
    const bx = x0 + r() * (x1 - x0), ph = r(), vx = (r() - 0.5) * 60, h = hMax * (0.4 + r() * 0.6), per = 0.9 + r() * 0.8;
    const q = K.fract(t / per + ph);
    const x = bx + vx * q, yy = y - 4 * h * q * (1 - q);
    c.fillStyle = K.rgba(col, alpha * (1 - q * 0.6));
    c.beginPath(); c.arc(x, yy, 1.6 + r() * 2.4, 0, TAU); c.fill();
  }
  c.restore();
};
// Nuh's presence (peace be upon him): ONLY a soft warm light, never a figure
// (docs/kids_stories_brief.md rule 1). Breathes slowly; sparkles orbit it.
K.presence = (c, x, y, r, t, alpha = 1) => {
  if (alpha <= 0.01) return;
  c.save();
  c.globalCompositeOperation = 'lighter';
  const b = 1 + 0.06 * Math.sin(t * 1.6) + 0.03 * Math.sin(t * 2.9);
  K.glow(c, x, y, r * 2.6 * b, '#FFB65C', 0.22 * alpha);
  K.glow(c, x, y, r * 1.3 * b, '#FFD58A', 0.42 * alpha);
  K.glow(c, x, y, r * 0.5 * b, '#FFF4D2', 0.75 * alpha);
  const rr = K.rng(7110);
  for (let i = 0; i < 9; i++) {
    const a = rr() * TAU + t * (0.3 + rr() * 0.4), d = r * (0.6 + rr() * 0.9), ph = rr() * TAU;
    const px = x + Math.cos(a) * d, py = y + Math.sin(a) * d * 0.7 - K.fract(t * 0.15 + ph) * r * 0.6;
    c.fillStyle = K.rgba('#FFF1C9', alpha * 0.7 * (0.5 + 0.5 * Math.sin(t * 2.2 + ph)));
    c.beginPath(); c.arc(px, py, 1.6 + rr() * 1.6, 0, TAU); c.fill();
  }
  c.restore();
};
// A puff of dust (k: 0 -> 1 over its life).
K.puff = (c, x, y, k, s = 1, col = '#E8D3B0') => {
  if (k <= 0 || k >= 1) return;
  const r = K.rng(Math.round(x * 7 + y * 13));
  c.save();
  for (let i = 0; i < 7; i++) {
    const a = -Math.PI + r() * Math.PI, d = (6 + r() * 16) * s * K.easeOut(k);
    c.fillStyle = K.rgba(col, 0.75 * (1 - k));
    c.beginPath(); c.arc(x + Math.cos(a) * d, y + Math.sin(a) * d * 0.6, (2 + r() * 3) * s * (0.6 + k), 0, TAU); c.fill();
  }
  c.restore();
};

// An ordinary person, flat kids style (allowed by brief rule 1 as updated
// 2026-09-30): a plain head with NO eyes, mouth or features, a head cloth, a
// robe and simple arms. Never used for a prophet or a companion.
// o: { phase (walk), walk 0..1, point 0..1 (arm raised toward +x), shake 0..1
//      (shoulders bobbing - laughing body language), robe, cloth, skin, dir }
K.person = (c, x, gy, s, o = {}) => {
  const ph = o.phase || 0, walk = o.walk ?? 0, dir = o.dir || 1;
  const robe = o.robe || '#8C6A52', cloth = o.cloth || '#E9DCC4', skin = o.skin || '#C99872';
  const shake = (o.shake || 0) * Math.abs(Math.sin(ph * 2.6)) * 3;
  c.save();
  c.translate(x, gy - Math.abs(Math.sin(ph)) * 2.2 * walk * s);
  c.scale(s * dir, s);
  // legs / feet under the robe
  c.fillStyle = K.mix(robe, '#2A1C14', 0.55);
  for (const k of [0, 1]) {
    const sw = Math.sin(ph + k * Math.PI) * 7 * walk;
    c.beginPath(); c.ellipse(-4 + k * 8 + sw, -3, 6, 3.5, 0, 0, TAU); c.fill();
  }
  // robe
  c.fillStyle = robe;
  c.beginPath(); c.moveTo(-15, -4); c.quadraticCurveTo(-13, -40, -9, -62 - shake); c.lineTo(9, -62 - shake); c.quadraticCurveTo(13, -40, 15, -4); c.closePath(); c.fill();
  c.fillStyle = K.rgba('#000000', 0.12); c.beginPath(); c.moveTo(3, -62 - shake); c.lineTo(9, -62 - shake); c.quadraticCurveTo(13, -40, 15, -4); c.lineTo(4, -4); c.closePath(); c.fill();
  // back arm
  c.strokeStyle = K.mix(robe, '#2A1C14', 0.25); c.lineWidth = 6; c.lineCap = 'round';
  c.beginPath(); c.moveTo(-5, -56 - shake); c.lineTo(-9 - Math.sin(ph) * 5 * walk, -34 - shake); c.stroke();
  // head: plain, featureless
  c.fillStyle = skin; c.beginPath(); c.arc(0, -72 - shake, 9, 0, TAU); c.fill();
  // head cloth
  c.fillStyle = cloth;
  c.beginPath(); c.arc(0, -74 - shake, 10, Math.PI * 1.02, TAU * 0.99); c.lineTo(10, -66 - shake); c.quadraticCurveTo(-4, -68 - shake, -11, -58 - shake); c.lineTo(-10, -74 - shake); c.fill();
  // front arm: hangs and swings, or rises to point
  const pt = K.easeInOut(o.point || 0);
  const ang = K.lerp(1.45 + Math.sin(ph + Math.PI) * 0.35 * walk, -0.35 + Math.sin(ph * 2.6) * 0.05 * (o.shake || 0), pt);
  c.strokeStyle = robe; c.lineWidth = 6;
  c.beginPath(); c.moveTo(4, -56 - shake); c.lineTo(4 + Math.cos(ang) * 22, -56 - shake + Math.sin(ang) * 22); c.stroke();
  c.fillStyle = skin; c.beginPath(); c.arc(4 + Math.cos(ang) * 24, -56 - shake + Math.sin(ang) * 24, 3.2, 0, TAU); c.fill();
  c.restore();
};

window.K = K;
