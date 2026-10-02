// Story 4 - Musa (Moses), peace be upon him, and the sea. VISUALS ONLY.
// Narration: docs/kids_stories/musa_narration.md (26:52-67, 20:77-79, 2:50 +
// al-Muyassar). Musa is NEVER drawn - only a warm light. Pharaoh, his soldiers
// and the believers are flat featureless figures; the drowning is shown as the
// sea closing - nobody is drawn in the water. No staff is drawn either: the
// strike is a beam of light from his presence to the sea.
'use strict';
(() => {
const { W, H } = K;
const TAU = Math.PI * 2;
const E = K.easeInOut, B = K.beat, A = K.after;
const SOLDIER = ['#6E3E34', '#5A3A30', '#7A4A30'], SOLCLOTH = ['#C9A25A', '#B08E50'];
const BELIEVERS = ['#5E6A7A', '#4E6A58', '#7A5A48', '#6E4E5A'];
// soldiers: featureless figures in a darker uniform with a gold head cloth
const soldiers = (c, seed, n, x0, x1, gy, s, t, o = {}) =>
  KIT.crowd(c, seed, n, x0, x1, gy, s, t, { ...o, robes: SOLDIER, cloths: SOLCLOTH });
const believers = (c, seed, n, x0, x1, gy, s, t, o = {}) =>
  KIT.crowd(c, seed, n, x0, x1, gy, s, t, { ...o, robes: BELIEVERS });
// The parted sea, seen down the dry path: two walls of water as tall as
// mountains on either side, foam on their tops, the sand path between.
// k: 0 closed .. 1 fully open. close: 0..1 the walls falling back together.
const partedSea = (c, t, k, close = 0) => {
  const hor = 430, gy = H + 40;
  // the sea beyond, up to the horizon
  KIT.sea(c, t, hor, 4, 0.95, ['#3F86A2', '#2A5E80']);
  const open = k * (1 - close);
  if (open <= 0.001) { KIT.sea(c, t + 1, hor + 10, 6, 1); return; }
  // the dry path (perspective trapezoid)
  const halfFar = 30 * open, halfNear = 380 * open;
  c.fillStyle = '#D9BE8A';
  c.beginPath(); c.moveTo(640 - halfFar, hor); c.lineTo(640 + halfFar, hor); c.lineTo(640 + halfNear, gy); c.lineTo(640 - halfNear, gy); c.closePath(); c.fill();
  // faint ripples in the wet sand (not boards)
  c.strokeStyle = K.rgba('#B89A66', 0.28); c.lineWidth = 1.5;
  for (let i = 1; i < 9; i++) { const u = (i / 9) ** 2, y = K.lerp(hor, gy, u), hw = halfFar + (halfNear - halfFar) * u; c.beginPath(); for (let x = -hw; x <= hw; x += 12) { const yy = y + Math.sin(x * 0.05 + i) * 2 * u; x === -hw ? c.moveTo(640 + x, yy) : c.lineTo(640 + x, yy); } c.stroke(); }
  // the walls: height rises with k (like a great mountain), sway gently
  const wall = (side) => {
    const hTop = 360 * open, inner = (y) => 640 + side * K.lerp(halfFar, halfNear, (y - hor) / (gy - hor));
    c.beginPath();
    c.moveTo(inner(hor), hor);
    for (let y = hor; y <= gy; y += 10) c.lineTo(inner(y) + side * Math.sin(t * 2 + y * 0.03) * 4, y);
    c.lineTo(640 + side * 1000, gy);
    c.lineTo(640 + side * 1000, hor - hTop);
    for (let x = 1000; x >= 0; x -= 20) c.lineTo(640 + side * Math.max(x, halfFar), hor - hTop * (0.6 + 0.4 * (1 - x / 1000)) + Math.sin(t * 1.6 + x * 0.02) * 6);
    c.closePath();
    const g = c.createLinearGradient(640 + side * halfFar, 0, 640 + side * 900, 0);
    g.addColorStop(0, '#6FC0D6'); g.addColorStop(0.3, '#3F86A2'); g.addColorStop(1, '#1F4F6A');
    c.fillStyle = g; c.fill();
    // foam along the inner face and the top
    c.strokeStyle = K.rgba('#EAF8FA', 0.8); c.lineWidth = 4;
    c.beginPath(); for (let y = hor - hTop * 0.6; y <= gy; y += 10) { const x = inner(Math.max(y, hor)) + side * Math.sin(t * 2 + y * 0.03) * 4; y === hor - hTop * 0.6 ? c.moveTo(x, y) : c.lineTo(x, y); } c.stroke();
    K.spray(c, t, side > 0 ? 501 : 502, 14, 640 + side * (halfFar + 10), 640 + side * (halfFar + 160), hor - hTop * 0.6, 30, '#EAF8FA', 0.6 * open);
  };
  wall(-1); wall(1);
};

const s1 = { // he is told to leave by night with those who believed
  cam: (p) => [K.lerp(1.04, 1.14, E(p)), K.lerp(560, 680, E(p)), K.lerp(380, 420, E(p)), 0],
  draw(c, t, d, p) {
    const yk = B(1, 'يخرج', 4.48), lay = B(1, 'ليل', 5.12);
    const light = K.lerp(0.18, 0.08, p);
    KIT.sky(c, t, light, { moon: [1020, 140], cloudA: 0.3 });
    KIT.land(c, light, { farCol: '#8E7A8A', midCol: '#9A8070', haze: '#3A4060' });
    KIT.town(c, light, 0.9, { seed: 52, n: 22 });
    K.par(c, 1, () => {
      KIT.palm(c, 1150, 670, 200, light, t, 1);
      // the believers walk out of the town, left, behind the light
      const go = A(t, yk - 0.4, d - yk + 0.4, (x) => x);
      believers(c, 2601, 12, 600, 1000, 650, 0.95, t, { face: -1, walk: go > 0 ? 1 : 0, shift: -380 * go });
      K.presence(c, K.lerp(560, 200, go), 610, 26, t, A(t, 0.2, 1));
    });
    KIT.foreGrass(c, t, light);
  },
};
const s2 = { // Pharaoh hears of it and sends men to gather his army from every city
  cam: (p) => [K.lerp(1.0, 1.1, E(p)), 640, K.lerp(380, 410, E(p)), 0],
  draw(c, t, d, p) {
    const rs = B(2, 'أرسل', 3.04);
    const light = 0.55;
    KIT.sky(c, t, light, { cols: ['#3A3A6A', '#B07A80', '#F2B27A'], sun: [200, 440], sunA: 0.7 });
    KIT.land(c, light, { farCol: '#B39080', midCol: '#C49A72' });
    KIT.town(c, light, 0.4, { seed: 53, n: 18, x0: 380, x1: 1260, scale: 1.2 });
    K.par(c, 1, () => {
      // columns of soldiers march in from the cities on «أرسل»
      const m = A(t, rs - 0.5, d - rs + 0.5, (x) => x);
      soldiers(c, 2602, 9, -260, 120, 640, 0.9, t, { face: 1, walk: 1, shift: 420 * m });
      soldiers(c, 2603, 9, -560, -180, 690, 1.0, t, { face: 1, walk: 1, shift: 460 * m });
    });
    K.par(c, 1.1, () => K.dust(c, t, 2604, 30, '#E8C99A', 0.4, -100, W + 100, 500, 720, 12));
  },
};
const s3 = { // Pharaoh: they are few, and we are ready for them
  cam: (p) => [K.lerp(1.15, 1.25, E(p)), 760, 430, 0],
  draw(c, t, d, p) {
    const ql = B(3, 'قليلون', 2.4);
    KIT.sky(c, t, 0.6, { cols: ['#3A3A6A', '#B07A80', '#F2B27A'] });
    KIT.land(c, 0.6);
    K.par(c, 1, () => {
      KIT.ground(c, 560, 0.65);
      // the palace steps and two columns (architecture, no figures on it but people)
      c.fillStyle = '#C9B08A'; for (let i = 0; i < 4; i++) c.fillRect(620 + i * 14, 600 - i * 18, 420 - i * 28, 18);
      c.fillStyle = '#B79C78'; c.fillRect(700, 330, 34, 220); c.fillRect(960, 330, 34, 220); c.fillRect(680, 310, 340, 26);
      // Pharaoh: a featureless figure in a long dark robe with a tall headdress
      const px = 850, py = 546, pt = A(t, ql - 0.3, 0.4) * (1 - A(t, ql + 2.6, 0.5));
      K.person(c, px, py, 1.5, { robe: '#2E3A5E', cloth: '#E2C26A', dir: -1, point: pt, shake: 0.5 * pt, phase: t * 3 });
      c.fillStyle = '#E2C26A'; c.beginPath(); c.moveTo(px - 12, py - 122); c.lineTo(px + 12, py - 122); c.lineTo(px + 6, py - 150); c.lineTo(px - 6, py - 150); c.fill();
      soldiers(c, 2605, 10, 300, 640, 660, 1.0, t, { face: 1 });
    });
  },
};
const s4 = { // they set out after them and caught up at sunrise
  cam: (p) => [1.06, K.lerp(500, 780, E(p)), 400, 0],
  draw(c, t, d, p) {
    const sh = B(4, 'شروق', 6.8);
    const up = A(t, sh - 2.5, 3);
    KIT.sky(c, t, K.lerp(0.42, 0.75, up), { sun: [1060, K.lerp(500, 400, up)], extra: () => K.rays(c, 1060, K.lerp(500, 400, up), 10, 900, Math.PI * 0.95, Math.PI * 1.5, '#FFE2B0', 0.1 * up, t) });
    KIT.land(c, K.lerp(0.45, 0.75, up), { farCol: '#C4A08A' });
    K.par(c, 1, () => {
      KIT.ground(c, 560, K.lerp(0.5, 0.8, up), '#D9B880');
      soldiers(c, 2606, 16, -200, 700, 650, 0.95, t, { face: 1, walk: 1, shift: 160 * p });
    });
    K.par(c, 1.1, () => K.dust(c, t, 2607, 40, '#E8C99A', 0.45, -100, W + 100, 520, 720, 14));
    KIT.foreGrass(c, t, 0.7);
  },
};
const shore = (c, t, light) => {
  KIT.sky(c, t, light, { sun: [1080, 300], sunA: 0.8 });
  K.par(c, 0.4, () => { c.fillStyle = '#9DB8C4'; c.fillRect(-420, 410, W + 840, 30); });
  K.par(c, 0.7, () => KIT.sea(c, t, 440, 6, 0.95));
};
const s5 = { // the two sides saw each other; Musa's people were afraid
  cam: (p) => [K.lerp(1.02, 1.12, E(p)), 640, 420, 0],
  draw(c, t, d, p) {
    const ra = B(5, 'رأى', 0.96), kh = B(5, 'خاف', 3.36);
    shore(c, t, 0.8);
    K.par(c, 1, () => {
      KIT.ground(c, 560, 0.85, '#E0C490');
      believers(c, 2608, 14, 120, 600, 640, 1.0, t, { face: 1, shake: A(t, kh - 0.2, 0.4) });
      K.presence(c, 360, 600, 26, t, 1);
      soldiers(c, 2609, 14, 1300, 1700, 610, 0.7, t, { face: -1, walk: 1, shift: -300 * A(t, ra - 0.6, d) });
    });
    K.par(c, 1.1, () => K.dust(c, t, 2610, 30, '#E8C99A', 0.4, 700, 1400, 500, 700, -10));
  },
};
const s6 = { // Musa: no, they will not reach us - God is with me
  cam: (p) => [K.lerp(1.12, 1.3, E(p)), K.lerp(560, 420, E(p)), 450, 0],
  draw(c, t, d, p) {
    const la = B(6, 'لا', 1.76), ma = B(6, 'معي', 4.56);
    shore(c, t, 0.82);
    K.par(c, 1, () => {
      KIT.ground(c, 560, 0.85, '#E0C490');
      believers(c, 2608, 14, 120, 600, 640, 1.0, t, { face: 1, shake: 1 - A(t, la, 1.2) });
      K.presence(c, 360, 600, 26 + 14 * A(t, ma - 0.3, 0.8), t, 1);
      soldiers(c, 2609, 14, 1000, 1400, 610, 0.7, t, { face: -1 });
    });
  },
};
const s7 = { // recitation 26:63 - the light strikes the sea; it splits; walls like mountains
  cam: (p, t, d) => {
    const fl = B(7, 'فانفلق', 8.4);
    return [K.lerp(1.15, 1.0, A(t, fl - 1, 2)), 640, K.lerp(450, 360, A(t, fl - 1, 2.5)), 0];
  },
  draw(c, t, d, p) {
    const ad = B(7, 'اضرب', 5.68), fl = B(7, 'فانفلق', 8.4), td = B(7, 'كالطود', 12.8);
    const k = Math.min(1, 0.55 * A(t, fl - 0.3, 1.5) + 0.45 * A(t, td - 0.6, 1.6));
    KIT.sky(c, t, 0.85, { sun: [1080, 260], extra: () => K.rays(c, 640, 380, 9, 900, Math.PI * 1.05, Math.PI * 1.95, '#FFF4D6', 0.12 * A(t, fl, 2), t) });
    K.par(c, 1, () => {
      partedSea(c, t, k);
      // the beam of light from his presence to the sea on «اضرب»
      const beam = A(t, ad - 0.1, 0.3) * (1 - A(t, ad + 1.4, 0.8));
      if (beam > 0) { K.glow(c, 640, 470, 240 * beam, '#FFF0C8', 0.5 * beam); }
      KIT.ground(c, 650, 0.9, '#E0C490');
      believers(c, 2611, 16, 240, 1040, 690, 1.0, t, { face: 1 });
      K.presence(c, 640, 650, 28, t, 1);
    });
  },
};
const s8 = { // the sea split, each side like a great mountain, dry paths in it
  cam: (p) => [K.lerp(1.0, 1.12, E(p)), 640, K.lerp(360, 400, E(p)), 0],
  draw(c, t, d, p) {
    const yb = B(8, 'يابسة', 8.08);
    KIT.sky(c, t, 0.88, { sun: [1080, 240] });
    K.par(c, 1, () => {
      partedSea(c, t, 1);
      K.glow(c, 640, 520, 300, '#FFF0C8', 0.15 * A(t, yb - 1, 1));
    });
    K.par(c, 1.1, () => K.dust(c, t, 2612, 30, '#FFFFFF', 0.35, -100, W + 100, 100, 600, 3));
  },
};
const s9 = { // they cross, fearing neither pursuit nor drowning
  cam: (p) => [K.lerp(1.0, 1.08, E(p)), 640, 380, 0],
  draw(c, t, d, p) {
    KIT.sky(c, t, 0.88, { sun: [1080, 240] });
    K.par(c, 1, () => {
      partedSea(c, t, 1);
      // a long line walking away down the path (they get smaller toward the horizon)
      for (let i = 0; i < 18; i++) {
        const u = K.fract(i / 18 + p * 0.35), y = K.lerp(H + 20, 450, u), s = K.lerp(1.1, 0.12, u);
        K.person(c, 640 + Math.sin(i * 1.7) * 120 * (1 - u), y, s, { phase: t * 5 + i, walk: 1, robe: BELIEVERS[i % 4], cloth: KIT.CLOTH[i % 4], dir: i % 2 ? 1 : -1 });
      }
      K.presence(c, 640, K.lerp(560, 480, p), 24, t, 1);
    });
  },
};
const s10 = { // Pharaoh and his soldiers go into the sea after them
  cam: (p) => [K.lerp(1.08, 1.0, E(p)), 640, 380, 0],
  draw(c, t, d, p) {
    KIT.sky(c, t, 0.75, { sun: [1080, 240], cloud: '#B8B8C4' });
    K.par(c, 1, () => {
      partedSea(c, t, 1);
      for (let i = 0; i < 14; i++) {
        const u = K.fract(i / 14 + p * 0.5), y = K.lerp(H + 40, 520, u), s = K.lerp(1.1, 0.25, u);
        K.person(c, 640 + Math.sin(i * 2.3) * 140 * (1 - u), y, s, { phase: t * 6 + i, walk: 1, robe: SOLDIER[i % 3], cloth: SOLCLOTH[i % 2], dir: 1 });
      }
    });
  },
};
const s11 = { // when they were across, God brought the sea down; they all drowned
  cam: (p, t, d) => {
    const at = B(11, 'أطب', 4.16);
    return [K.lerp(1.0, 1.1, A(t, at, 2)), 640, K.lerp(380, 420, A(t, at, 2)), Math.sin(t * 5) * 0.004 * A(t, at, 0.3) * (1 - A(t, at + 2, 1))];
  },
  draw(c, t, d, p) {
    const at = B(11, 'أطب', 4.16);
    const close = A(t, at - 0.2, 2.2, K.easeIn);
    KIT.sky(c, t, 0.7, { cloud: '#A8A8B8' });
    K.par(c, 1, () => {
      partedSea(c, t, 1, close);
      // only the sea: a great surge of foam where the walls meet
      const meet = A(t, at + 1.4, 0.5) * (1 - A(t, at + 3.5, 2));
      K.spray(c, t, 2613, 60, 300, 980, 470, 160, '#F0FAFC', 0.85 * meet);
      // the believers safe on the near shore, the light with them
      KIT.ground(c, 680, 0.85, '#E0C490');
      believers(c, 2614, 12, 150, 560, 712, 0.9, t, { face: 1 });
      K.presence(c, 620, 680, 24, t, 1);
    });
  },
};
const s12 = { // God saved Musa and all with him - a great sign
  cam: (p) => [K.lerp(1.1, 1.0, E(p)), 640, K.lerp(420, 380, E(p)), 0],
  draw(c, t, d, p) {
    const ay = B(12, 'آية', 5.68);
    KIT.sky(c, t, 0.95, { sun: [1000, 180], extra: () => K.rays(c, 1000, 180, 12, 1000, Math.PI * 0.55, Math.PI * 1.05, '#FFF0C8', 0.1 + 0.06 * A(t, ay, 1), t) });
    K.par(c, 0.6, () => KIT.sea(c, t, 440, 4, 1));
    K.par(c, 1, () => {
      KIT.ground(c, 600, 0.95, '#E0C490');
      believers(c, 2615, 18, 100, 1180, 640, 1.0, t, { face: 1 });
      K.presence(c, 640, 610, 30, t, 1);
    });
    K.par(c, 0.15, () => K.birds(c, t, 2616, 6, 300, 200, 160, 30, 9, '#4A4A58', 0.6));
  },
};
const s13 = {
  cam: (p) => [K.lerp(1.1, 1.02, E(p)), 640, K.lerp(390, 362, E(p)), 0],
  draw(c, t, d, p) {
    KIT.lesson(c, t, p, { seed: 2617, mid: () => K.par(c, 0.7, () => KIT.sea(c, t, 560, 3, 1, ['#E8A982', '#7C6E98'])) });
  },
};
window.STORY_SCENES = [s1, s2, s3, s4, s5, s6, s7, s8, s9, s10, s11, s12, s13];
})();
