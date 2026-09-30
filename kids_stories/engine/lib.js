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
  c.save();
  c.translate(x, y);
  c.scale(s, s);
  if (opts.ramp) {
    c.fillStyle = tn('#6E4529');
    c.beginPath(); c.moveTo(-500, 200); c.lineTo(-178, 122); c.lineTo(-100, 122); c.lineTo(-100, 134); c.lineTo(-178, 134); c.lineTo(-470, 206); c.closePath(); c.fill();
    c.fillStyle = tn('#9C6A42');
    c.beginPath(); c.moveTo(-500, 200); c.lineTo(-178, 122); c.lineTo(-100, 122); c.lineTo(-100, 127); c.lineTo(-178, 127); c.lineTo(-490, 204); c.closePath(); c.fill();
    c.strokeStyle = tn('#5A3822'); c.lineWidth = 2;
    for (let i = 1; i < 8; i++) { const u = i / 8, px = -500 + (322) * u, py = 200 - 78 * u; c.beginPath(); c.moveTo(px, py); c.lineTo(px + 2, py + 5); c.stroke(); }
  }
  arkPlanks.forEach((pl, i) => {
    const a = K.clamp(kf - i);
    if (a <= 0) return;
    if (pl.kind === 'block' && !opts.blocks) return;
    const e = K.easeOut(K.clamp(a / 0.7));
    c.save();
    c.globalAlpha *= K.clamp(a / 0.3);
    c.translate(0, (1 - e) * -64);
    if (pl.kind === 'block') {
      woodPlank(c, pl.x - 20, 140, 40, 60, tn('#7A4E2E'), pl.v);
    } else if (pl.kind === 'hull') {
      c.save(); arkHull(c); c.clip();
      const base = tn(K.mix(hullCols[Math.floor(pl.v * 3)], '#5E3A22', pl.r / ARK_ROWS * 0.45));
      woodPlank(c, pl.x0, pl.y0, pl.x1 - pl.x0, pl.y1 - pl.y0, base, pl.v);
      c.restore();
      const k = K.clamp((a - 0.7) / 0.3), py = (pl.y0 + pl.y1) / 2;
      if (pl.x0 > -400) peg(c, pl.x0 + 9, py, k);
      if (pl.x1 < 400) peg(c, pl.x1 - 9, py, k);
    } else if (pl.kind === 'cabin') {
      woodPlank(c, pl.x0, pl.y0, pl.x1 - pl.x0, pl.y1 - pl.y0, tn(K.mix('#B98252', '#9A6A43', pl.v)), pl.v);
      const k = K.clamp((a - 0.7) / 0.3), py = (pl.y0 + pl.y1) / 2;
      peg(c, pl.x0 + 8, py, k); peg(c, pl.x1 - 8, py, k);
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

window.K = K;
