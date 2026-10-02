// Story 3 - Ibrahim (Abraham), peace be upon him, and the idols. VISUALS ONLY.
// Narration and sources: docs/kids_stories/ibrahim_narration.md (al-Anbiya
// 21:51-70 + al-Muyassar). Rules (docs/kids_stories_brief.md rule 1): Ibrahim
// is NEVER drawn - his presence is only a warm light; ordinary people are flat
// and featureless; the idols are plain carved stones (no faces, no names);
// no text. Events keyed to the spoken word (K.beat; fallbacks = measured times).
'use strict';
(() => {
const { W, H } = K;
const TAU = Math.PI * 2;
const E = K.easeInOut;
const B = K.beat, A = K.after;

const SKY = {
  night: ['#0E1534', '#1B2550', '#2E3A66'],
  dusk: ['#2F2B5C', '#9A537A', '#F2A56B'],
  day: ['#5DA9D6', '#A3D2E6', '#F4E3C0'],
};
const skyAt = (light) => {
  const [a, b, t] = light < 0.5 ? [SKY.night, SKY.dusk, light * 2] : [SKY.dusk, SKY.day, (light - 0.5) * 2];
  return a.map((c, i) => K.mix(c, b[i], t));
};
const ground = (c, y, light, col = '#D9A86C') => {
  const g = c.createLinearGradient(0, y, 0, H + 60);
  g.addColorStop(0, K.tone(col, light)); g.addColorStop(1, K.tone(K.mix(col, '#8A5A3C', 0.35), light));
  c.fillStyle = g; c.fillRect(-420, y, W + 840, H - y + 420);
};
const palm = (c, x, gy, h, light, t, ph = 0) =>
  K.palm(c, x, gy, h, K.tone('#6B4A34', light), K.tone('#5E7A45', light), Math.sin(t * 0.9 + ph) + 0.35 * Math.sin(t * 2.3 + ph * 2));
const ROBES = ['#7A5A48', '#5E6A7A', '#8A6E3E', '#6E4E5A', '#4E6A58', '#8C5A4A', '#6A5E7E'];
const CLOTH = ['#E9DCC4', '#D8CBB0', '#EFE4CC', '#DCCFB8'];
const foreGrass = (c, t, light, y = 746) => K.par(c, 1.32, () => {
  const col = K.tone('#5E6B3A', light * 0.7);
  K.grass(c, 291, -380, 260, y, 46, col, t, 1);
  K.grass(c, 292, 1040, 1680, y, 52, col, t + 0.7, 1);
});
const skyLayer = (c, t, light, extra) => K.par(c, 0, () => {
  K.sky(c, skyAt(light), 0, 480);
  if (light > 0.6) K.sun(c, 1040, 140, 34, '#FFF1C4', '#FFD68A', 0.45);
  for (const [x, y, s, v] of [[200, 120, 0.9, 7], [640, 80, 0.7, 5], [1100, 150, 1.0, 6]]) K.cloud(c, K.mod(x + t * v + 200, W + 500) - 250, y, s, K.tone('#FFF8EC', light), 0.85);
  if (extra) extra();
});
const backTown = (c, t, light) => {
  K.par(c, 0.3, () => { K.ridge(c, 410, 50, 2.3, 0.7, K.tone('#C4A08A', light)); K.haze(c, 320, 470, '#F2DCC0', 0.28); });
  K.par(c, 0.55, () => { ground(c, 470, light); K.town(c, 211, 22, 40, 1240, 480, 0.8, light, 0); });
};
// The courtyard of the idols: a stone floor, the row of carved stones on a
// platform, the biggest in the middle.
const IDOLS = [['boulder', 330, 110], ['slab', 440, 140], ['stepped', 545, 128], ['obelisk', 640, 230], ['column', 735, 120], ['slab', 840, 136], ['boulder', 950, 104]];
const BIG = 3;
const floor = (c, light) => {
  ground(c, 540, light, '#D8B888');
  c.strokeStyle = K.rgba('#8A6E54', 0.25); c.lineWidth = 2;
  for (let i = 0; i < 8; i++) { const y = 560 + i * i * 4.5; c.beginPath(); c.moveTo(-420, y); c.lineTo(W + 420, y); c.stroke(); }
  c.fillStyle = K.tone('#B08E70', light); c.beginPath(); c.roundRect(260, 598, 760, 22, 6); c.fill();
  c.fillStyle = K.tone('#8C6E56', light); c.fillRect(266, 616, 748, 16);
};
// draw the idols; broken[i] = 0..1 (0 whole, then it bursts into pieces that settle)
const idols = (c, light, broken = [], dim = 0) => {
  IDOLS.forEach(([kind, x, h], i) => {
    const b = broken[i] || 0;
    const col = K.tone(K.mix('#9C8A78', '#5E5650', dim), light), lit = K.tone(K.mix('#C7AE8E', '#7A7068', dim), light), sh = K.tone('#6E5E54', light);
    if (b <= 0) { K.stone(c, kind, x, 606, h, col, lit, sh); return; }
    const r = K.rng(1000 + i), fly = K.easeOut(K.clamp(b / 0.6));
    for (let k = 0; k < 9; k++) {
      const w = h * (0.12 + r() * 0.14), hh = w * (0.6 + r() * 0.6);
      const sx = x + (r() - 0.5) * h * 0.4, sy = 606 - r() * h;
      const ex = x + (r() - 0.5) * h * 1.4, ey = 604 - r() * 8;
      const px = K.lerp(sx, ex, fly), py = K.lerp(sy, ey, fly) - Math.sin(Math.PI * fly) * h * 0.5;
      c.save(); c.translate(px, py); c.rotate((r() - 0.5) * 3 * fly);
      c.fillStyle = k % 3 ? col : lit; c.beginPath(); c.moveTo(-w / 2, 0); c.lineTo(w / 2, -hh * 0.2); c.lineTo(w * 0.3, -hh); c.lineTo(-w * 0.4, -hh * 0.8); c.closePath(); c.fill();
      c.restore();
    }
    K.puff(c, x, 600, b * 1.4, 2.4, '#E6D2B4');
  });
};
const crowd = (c, seed, n, x0, x1, gy, s, t, o = {}) => {
  const r = K.rng(seed), list = [];
  for (let i = 0; i < n; i++) list.push({ x: x0 + r() * (x1 - x0), row: r(), k: Math.floor(r() * 7), cl: Math.floor(r() * 4), ph: r() * TAU, d: r() < 0.5 ? 1 : -1 });
  list.sort((a, b) => a.row - b.row);
  for (const p of list) {
    const ss = s * (0.85 + p.row * 0.35), y = gy + p.row * 30 * s;
    let x = p.x, walk = o.walk || 0, dir = o.face || (p.x < 640 ? 1 : -1);
    if (o.leave) { x += -o.leave * 700 * (p.x < 640 ? 1 : -1); walk = o.leave > 0 && o.leave < 1 ? 1 : 0; dir = p.x < 640 ? -1 : 1; }
    if (o.arrive !== undefined) { x += (1 - o.arrive) * 700 * (p.x < 640 ? -1 : 1); walk = o.arrive < 1 ? 1 : walk; }
    K.person(c, x, y, ss, { phase: t * 5 + p.ph, walk, robe: ROBES[p.k], cloth: CLOTH[p.cl], dir, shake: o.shake || 0, point: o.point || 0 });
  }
};
// Fire: flame tongues flickering; `cool` 0..1 turns it into a calm cool light.
const fire = (c, x, y, w, h, t, cool = 0, alpha = 1) => {
  if (alpha <= 0.01) return;
  c.save(); c.globalAlpha *= alpha;
  const hh = h * (1 - 0.65 * cool);
  const layers = [['#C2361E', '#7FB8E0', 1], ['#F07A24', '#B8E2F4', 0.78], ['#FFC94A', '#E8FAFF', 0.55], ['#FFF2B0', '#FFFFFF', 0.32]];
  for (const [hot, cold, k] of layers) {
    c.fillStyle = K.mix(hot, cold, cool);
    c.beginPath(); c.moveTo(x - w / 2 * k, y);
    const n = 7;
    for (let i = 0; i <= n; i++) {
      const u = i / n, fx = x - w / 2 * k + u * w * k;
      const f = Math.sin(t * 7 + i * 1.7) * 0.18 + Math.sin(t * 11.3 + i * 2.9) * 0.1;
      const th = hh * k * (0.55 + 0.45 * Math.sin(Math.PI * u)) * (1 + f);
      c.quadraticCurveTo(fx - w / n * k * 0.5, y - th * 0.55, fx, y - th);
      c.quadraticCurveTo(fx + w / n * k * 0.4, y - th * 0.5, fx + w / n * k * 0.5, y - th * 0.15);
    }
    c.lineTo(x + w / 2 * k, y); c.closePath(); c.fill();
  }
  c.globalCompositeOperation = 'lighter';
  K.glow(c, x, y - hh * 0.4, w * 0.9, cool > 0.5 ? '#BFE6FF' : '#FF9A3C', 0.35);
  // embers rise while it burns
  const r = K.rng(7777);
  for (let i = 0; i < 26; i++) {
    const q = K.fract(t * (0.4 + r() * 0.5) + r()), ex = x + (r() - 0.5) * w + Math.sin(t * 3 + i) * 10;
    c.fillStyle = K.rgba(K.mix('#FFB04A', '#DDF4FF', cool), (1 - q) * 0.8 * (1 - cool * 0.6));
    c.beginPath(); c.arc(ex, y - q * h * 1.3, 2 + r() * 2, 0, TAU); c.fill();
  }
  c.restore();
};
const woodPile = (c, x, y, w) => {
  for (let i = 0; i < 9; i++) {
    const a = (i - 4) * 0.18, l = w * (0.5 + (i % 3) * 0.12);
    c.save(); c.translate(x + (i - 4) * w * 0.06, y); c.rotate(a);
    c.fillStyle = i % 2 ? '#5A3A24' : '#6E4A2E'; c.fillRect(-l / 2, -10, l, 14); c.restore();
  }
};

// ---- 1. God gave Ibrahim guidance (21:51) ----
const s1 = {
  cam: (p) => [K.lerp(1.02, 1.14, E(p)), K.lerp(560, 640, E(p)), K.lerp(360, 410, E(p)), 0],
  draw(c, t, d, p) {
    const ib = B(1, 'إبراهيم', 1.44), hd = B(1, 'الهد', 4.16);
    const light = K.lerp(0.55, 0.85, E(p));
    skyLayer(c, t, light, () => {
      const sy = K.lerp(470, 380, E(p));
      K.rays(c, 300, sy, 10, 900, -Math.PI + 0.2, -0.2, '#FFE2B0', 0.08, t);
      K.sun(c, 300, sy, 34, '#FFE8A8', '#FFB070', 0.5);
    });
    K.par(c, 0.12, () => K.birds(c, t, 3101, 6, 500, 200, 180, 30, 9, '#4A3A40', 0.6));
    backTown(c, t, light);
    K.par(c, 1, () => {
      ground(c, 560, light);
      palm(c, 230, 660, 210, light, t, 0); palm(c, 1080, 670, 230, light, t, 2);
      K.presence(c, 640, 600, 26 + 10 * A(t, hd - 0.2, 0.6), t, A(t, ib - 0.3, 0.9));
    });
    K.par(c, 1.08, () => K.dust(c, t, 3102, 30, '#FFF1D2', 0.4, -100, W + 100, 300, 700, 5));
    foreGrass(c, t, light);
  },
};

// ---- 2. His people worshipped idols they made with their own hands (21:52) ----
const s2 = {
  cam: (p, t, d) => {
    const as = B(2, 'أصنام', 2.72);
    return [K.lerp(1.04, 1.18, A(t, as - 0.6, 1.6)), K.lerp(600, 640, E(p)), K.lerp(380, 450, A(t, as - 0.6, 1.6)), 0];
  },
  draw(c, t, d, p) {
    const as = B(2, 'أصنام', 2.72), sn = B(2, 'نعوها', 3.84);
    skyLayer(c, t, 0.9);
    backTown(c, t, 0.9);
    K.par(c, 1, () => {
      floor(c, 0.9);
      K.glow(c, 640, 520, 360, '#FFD9A0', 0.15 * A(t, as - 0.3, 0.8));
      idols(c, 0.9);
      // «صنعوها بأيديهم»: at the side a stone is being carved - chisel taps, dust
      const cv = A(t, sn - 0.4, 0.5);
      K.stone(c, 'slab', 1110, 660, 90 * (0.7 + 0.3 * cv), '#A8968A', '#CDB6A0', '#7A6A60');
      for (let k = 0; k < 4; k++) { const q = K.fract((t - sn) * 1.6 + k / 4); if (t > sn - 0.4) K.puff(c, 1100, 600 + k * 6, q, 1, '#E8D6BC'); }
      K.person(c, 1040, 680, 1.1, { phase: t * 2, robe: ROBES[2], cloth: CLOTH[1], dir: 1, point: 0.6 + 0.4 * Math.abs(Math.sin(t * 5)) * cv });
      crowd(c, 3201, 8, 330, 950, 670, 1.0, t, { face: 0 });
    });
    foreGrass(c, t, 0.9);
  },
};

// ---- 3. He asked them about the idols; they said: our fathers did so (21:52-53) ----
const s3 = {
  cam: (p, t, d) => [1.16, K.lerp(560, 680, E(p)), 450, 0],
  draw(c, t, d, p) {
    const sa = B(3, 'فسأل', 0.24), ql = B(3, 'فقالوا', 2.64);
    skyLayer(c, t, 0.9);
    backTown(c, t, 0.9);
    K.par(c, 1, () => {
      floor(c, 0.9);
      idols(c, 0.9);
      crowd(c, 3301, 9, 420, 1000, 670, 1.05, t, { shake: 0.3 * A(t, ql - 0.1, 0.4) * (1 - A(t, ql + 2, 0.5)) });
      const ask = A(t, sa - 0.1, 0.4) * (1 - A(t, sa + 1.6, 0.6));
      K.presence(c, 260, 640, 26 + 8 * ask, t, 1);
    });
    foreGrass(c, t, 0.9);
  },
};

// ---- 4. He told them their Lord is the Lord of the heavens and the earth, who created them (21:56) ----
const s4 = {
  cam: (p, t, d) => {
    const sm = B(4, 'السماوات', 3.68), ar = B(4, 'والأرض', 4.8);
    const up = A(t, sm - 0.8, 1.2), down = A(t, ar - 0.2, 1.4);
    return [K.lerp(1.16, 1.0, up), 640, K.lerp(450, 280, up) + 140 * down, 0];
  },
  draw(c, t, d, p) {
    const sm = B(4, 'السماوات', 3.68), kh = B(4, 'خلقهن', 6.24);
    const shine = A(t, sm - 0.5, 1.2);
    skyLayer(c, t, 0.92, () => {
      K.rays(c, 1040, 140, 14, 1200, Math.PI * 0.5, Math.PI * 1.05, '#FFF4D0', 0.12 * shine, t);
    });
    K.par(c, 0.12, () => { K.birds(c, t, 3401, 9, 300, 180, 260, 32, 10, '#4A3A40', 0.7 * shine); K.birds(c, t + 5, 3402, 6, 900, 240, 180, 26, 8, '#4A3A40', 0.6 * shine); });
    backTown(c, t, 0.92);
    K.par(c, 0.8, () => { K.ridge(c, 560, 30, 4.4, 1.0, '#9AB070'); });
    K.par(c, 1, () => {
      floor(c, 0.92);
      idols(c, 0.92);
      K.presence(c, 260, 640, 28 + 6 * A(t, kh - 0.2, 0.6), t, 1);
      crowd(c, 3301, 9, 420, 1000, 670, 1.05, t);
    });
    K.par(c, 1.08, () => K.dust(c, t, 3403, 40, '#FFF6DC', 0.45 * shine, -100, W + 100, 0, 700, 4));
    foreGrass(c, t, 0.92);
  },
};

// ---- 5. When his people had gone, he broke the idols into pieces, all but the biggest (21:57-58) ----
const s5 = {
  cam: (p, t, d) => {
    const tk = B(5, 'وترك', 6.64);
    return [K.lerp(1.1, 1.22, E(p)) + 0.12 * A(t, tk - 0.3, 1.4), K.lerp(600, 640, E(p)), K.lerp(420, 470, E(p)) - 40 * A(t, tk - 0.3, 1.4), 0];
  },
  draw(c, t, d, p) {
    const dh = B(5, 'ذهب', 1.04), ks = B(5, 'كسر', 2.4), qt = B(5, 'قطع', 5.12), tk = B(5, 'وترك', 6.64);
    const light = K.lerp(0.85, 0.7, p);
    skyLayer(c, t, light);
    backTown(c, t, light);
    K.par(c, 1, () => {
      floor(c, light);
      // the stones break one after another from «كسر» to «قطعًا»; the biggest stays
      const order = [0, 6, 1, 5, 2, 4];
      const broken = [];
      order.forEach((idx, k) => { broken[idx] = K.clamp((t - (ks + k * (qt + 0.4 - ks) / order.length)) / 0.9); });
      idols(c, light, broken);
      // the light moves along the row as each one falls, then stands by the big one
      const k = Math.min(order.length - 1, Math.max(0, Math.floor((t - ks) / ((qt + 0.4 - ks) / order.length))));
      const tx = t < ks ? 200 : t > tk - 0.4 ? 560 : IDOLS[order[k]][1] - 60;
      K.presence(c, tx, 640, 26, t, 1);
      crowd(c, 3301, 9, 420, 1000, 670, 1.05, t, { leave: A(t, dh - 0.3, 1.6, (x) => x) });
    });
    foreGrass(c, t, light);
  },
};

// ---- 6. They came back, saw their idols broken, and asked: who did this? (21:59) ----
const s6 = {
  cam: (p, t, d) => [K.lerp(1.04, 1.14, E(p)), 640, K.lerp(400, 450, E(p)), 0],
  draw(c, t, d, p) {
    const rj = B(6, 'فرجع', 0.24), ra = B(6, 'فرأوا', 1.6), ql = B(6, 'فقالوا', 4.0);
    skyLayer(c, t, 0.75);
    backTown(c, t, 0.75);
    K.par(c, 1, () => {
      floor(c, 0.75);
      idols(c, 0.75, [1, 1, 1, 0, 1, 1, 1]);
      crowd(c, 3601, 11, 300, 1000, 670, 1.05, t, { arrive: A(t, rj - 0.2, ra - rj + 0.4), shake: 0.6 * A(t, ql - 0.2, 0.3), point: A(t, ra, 0.5) * 0.7 });
    });
    foreGrass(c, t, 0.75);
  },
};

// ---- 7. They brought him before the people; he said: ask your idols, if they can speak (21:61-63) ----
const s7 = {
  cam: (p, t, d) => {
    const is = B(7, 'اسألوا', 4.32);
    return [K.lerp(1.06, 1.2, E(p)), K.lerp(560, 660, A(t, is - 0.4, 1.2)), 440, 0];
  },
  draw(c, t, d, p) {
    const ns = B(7, 'الناس', 2.8), is = B(7, 'اسألوا', 4.32);
    skyLayer(c, t, 0.75);
    backTown(c, t, 0.75);
    K.par(c, 1, () => {
      floor(c, 0.75);
      idols(c, 0.75, [1, 1, 1, 0, 1, 1, 1]);
      crowd(c, 3701, 14, 180, 1100, 672, 1.05, t, { arrive: A(t, 0, ns) });
      // a beam from his light toward the big stone on «اسألوا»
      const beam = A(t, is - 0.1, 0.5) * (1 - A(t, d - 0.8, 0.8));
      if (beam > 0) {
        const g = c.createLinearGradient(520, 640, 640, 440);
        g.addColorStop(0, K.rgba('#FFE2A0', 0.5 * beam)); g.addColorStop(1, K.rgba('#FFE2A0', 0));
        c.strokeStyle = g; c.lineWidth = 10; c.lineCap = 'round';
        c.beginPath(); c.moveTo(520, 630); c.lineTo(K.lerp(520, 640, beam), K.lerp(630, 450, beam)); c.stroke();
      }
      K.presence(c, 500, 640, 28, t, A(t, 0.2, 0.8));
    });
    foreGrass(c, t, 0.75);
  },
};

// ---- 8. They knew in themselves the idols cannot speak, nor help nor harm (21:64-66) ----
const s8 = {
  cam: (p, t, d) => [K.lerp(1.2, 1.3, E(p)), 640, K.lerp(430, 470, E(p)), 0],
  draw(c, t, d, p) {
    const ar = B(8, 'فعرفوا', 0.32), tn = B(8, 'تنفع', 5.6);
    const dim = A(t, tn - 0.4, 1.4);
    skyLayer(c, t, 0.72);
    backTown(c, t, 0.72);
    K.par(c, 1, () => {
      floor(c, 0.72);
      idols(c, 0.72 - 0.15 * dim, [1, 1, 1, 0, 1, 1, 1], dim);
      // heads go down - they know (body language: no shaking, no pointing)
      crowd(c, 3701, 14, 180, 1100, 672 + 4 * A(t, ar, 0.8), 1.05, t);
      K.presence(c, 500, 640, 28, t, 1);
    });
    foreGrass(c, t, 0.72);
  },
};

// ---- 9. They grew angry, lit a great fire and threw him into it (21:68) ----
const s9 = {
  cam: (p, t, d) => [K.lerp(1.04, 1.2, E(p)), 640, K.lerp(400, 430, E(p)), 0],
  draw(c, t, d, p) {
    const gd = B(9, 'غضبوا', 1.28), as = B(9, 'وأشعلوا', 2.08), al = B(9, 'وألقو', 4.96);
    const red = A(t, gd - 0.4, 1.2), grow = A(t, as - 0.2, 1.8, K.easeOut);
    skyLayer(c, t, K.lerp(0.7, 0.45, red));
    K.par(c, 0, () => { c.fillStyle = K.rgba('#B8402A', 0.18 * red); c.fillRect(-420, -420, W + 840, H + 840); });
    backTown(c, t, K.lerp(0.7, 0.5, red));
    K.par(c, 1, () => {
      ground(c, 560, 0.6, '#C9A06C');
      woodPile(c, 640, 640, 300);
      fire(c, 640, 640, 380 * grow, 380 * grow, t, 0, grow);
      crowd(c, 3901, 14, 120, 1160, 680, 1.0, t, { shake: 0.4 * red });
      // the light goes into the fire on «وألقوا إبراهيم فيها»
      const into = A(t, al - 0.1, 0.9);
      K.presence(c, K.lerp(380, 640, into), K.lerp(640, 560, into), 24, t, 1);
    });
    K.par(c, 1.1, () => K.dust(c, t, 3902, 30, '#FFB060', 0.5 * grow, 300, 980, 200, 640, 2));
  },
};

// ---- 10. Recitation: al-Anbiya 21:69 (Minshawi). The fire turns calm and cool;
// the light inside it stays bright and unharmed.
const s10 = {
  cam: (p, t, d) => [K.lerp(1.2, 1.32, E(p)), 640, K.lerp(430, 450, E(p)), 0],
  draw(c, t, d, p) {
    const yn = B(10, 'نار', 2.16), kn = B(10, 'كوني', 3.04), sl = B(10, 'وسلاما', 5.6);
    const cool = A(t, kn - 0.3, 2.6);
    skyLayer(c, t, K.lerp(0.45, 0.8, cool));
    K.par(c, 0, () => { c.fillStyle = K.rgba('#B8402A', 0.18 * (1 - cool)); c.fillRect(-420, -420, W + 840, H + 840); });
    backTown(c, t, K.lerp(0.5, 0.8, cool));
    K.par(c, 1, () => {
      ground(c, 560, K.lerp(0.6, 0.85, cool), '#C9A06C');
      woodPile(c, 640, 640, 300);
      fire(c, 640, 640, 380, 380, t * (1 - 0.6 * cool), cool, 1);
      crowd(c, 3901, 14, 120, 1160, 680, 1.0, t, { shake: 0.4 * (1 - A(t, yn, 0.6)) });
      K.presence(c, 640, 560, 26 + 12 * A(t, sl - 0.3, 1), t, 1);
    });
  },
};

// ---- 11. The fire did not burn him; no harm touched him (21:69) ----
const s11 = {
  cam: (p, t, d) => [K.lerp(1.32, 1.18, E(p)), 640, K.lerp(450, 430, E(p)), 0],
  draw(c, t, d, p) {
    const fade = A(t, 0.3, d * 0.8);
    skyLayer(c, t, 0.85);
    backTown(c, t, 0.85);
    K.par(c, 1, () => {
      ground(c, 560, 0.85, '#C9A06C');
      woodPile(c, 640, 640, 300);
      fire(c, 640, 640, 380, 380, t * 0.4, 1, 1 - fade);
      crowd(c, 3901, 14, 120, 1160, 680, 1.0, t);
      K.presence(c, 640, 590, 30, t, 1);
    });
    K.par(c, 1.08, () => K.dust(c, t, 3911, 30, '#E8FAFF', 0.4, 300, 980, 200, 640, 2));
  },
};

// ---- 12. They wanted harm for him; God brought their plot to nothing (21:70) ----
const s12 = {
  cam: (p, t, d) => [K.lerp(1.16, 1.04, E(p)), 640, K.lerp(430, 390, E(p)), 0],
  draw(c, t, d, p) {
    const ab = B(12, 'فأبطل', 2.16);
    skyLayer(c, t, 0.9, () => K.rays(c, 640, -80, 10, 1000, Math.PI * 0.3, Math.PI * 0.7, '#FFF0C8', 0.1 * A(t, ab, 1.2), t));
    backTown(c, t, 0.9);
    K.par(c, 1, () => {
      ground(c, 560, 0.9, '#C9A06C');
      woodPile(c, 640, 640, 300);
      // they go away, heads down
      crowd(c, 3901, 14, 120, 1160, 680, 1.0, t, { leave: A(t, ab - 0.2, 3, (x) => x) });
      K.presence(c, 640, 600, 30, t, 1);
    });
    foreGrass(c, t, 0.9);
  },
};

// ---- 13. The lesson. Calm morning, palms, the lower third kept clear ----
const s13 = {
  cam: (p, t, d) => [K.lerp(1.1, 1.02, E(p)), 640, K.lerp(390, 362, E(p)), 0],
  draw(c, t, d, p) {
    const up = E(K.seg(p, 0, 0.8));
    K.par(c, 0, () => {
      K.sky(c, ['#8EC3DE', '#CFE0E2', '#F7D6A8', '#F3B98A'], 0, 470);
      const sy = K.lerp(460, 360, up);
      K.rays(c, 900, sy, 12, 950, Math.PI + 0.2, TAU - 0.2, '#FFF1C8', 0.06, t);
      K.sun(c, 900, sy, 38, '#FFF0C2', '#FFB36B', 0.55);
      for (const [x, y, s, v] of [[250, 120, 0.8, 4], [600, 90, 0.6, 3], [1100, 140, 0.7, 5]]) K.cloud(c, K.mod(x + t * v + 200, W + 500) - 250, y, s, '#FFF3E4', 0.85);
    });
    K.par(c, 0.15, () => K.birds(c, t, 3131, 6, 300, 200, 170, 34, 9, '#5A4A50', 0.6));
    K.par(c, 0.45, () => { K.ridge(c, 480, 50, 3.1, 0.8, '#C8A88E'); K.haze(c, 380, 560, '#FBE6CC', 0.3); });
    K.par(c, 0.7, () => { K.ridge(c, 540, 26, 6.9, 1.2, '#A7B97F'); palm(c, 180, 600, 170, 0.95, t, 0); palm(c, 1110, 610, 190, 0.95, t, 2); });
    K.par(c, 1, () => {
      const g = c.createLinearGradient(0, 600, 0, H);
      g.addColorStop(0, '#B9C98A'); g.addColorStop(1, '#A9BC7C');
      c.fillStyle = g; c.fillRect(-420, 600, W + 840, 600);
      for (const [x, s] of [[120, 1.0], [260, 0.8], [1010, 0.9], [1180, 1.1]]) K.shrub(c, x, 604, s, '#86A060');
    });
    K.par(c, 1.08, () => K.dust(c, t, 3132, 30, '#FFF4D8', 0.4, -100, W + 100, 200, 650, 4));
  },
};

window.STORY_SCENES = [s1, s2, s3, s4, s5, s6, s7, s8, s9, s10, s11, s12, s13];
})();
