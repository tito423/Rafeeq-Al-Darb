// Story 5 - Sulayman (Solomon), peace be upon him, and the ant. VISUALS ONLY.
// Narration: docs/kids_stories/sulayman_narration.md (27:15-19 + al-Muyassar).
// Dawud and Sulayman are NEVER drawn - each only a warm light. The jinn are not
// drawn (unseen); the procession shows men (featureless) and birds.
'use strict';
(() => {
const { W, H } = K;
const TAU = Math.PI * 2;
const E = K.easeInOut, B = K.beat, A = K.after;
const ARMY = ['#5A6E8A', '#6E5A48', '#4E6A58'], ARMYC = ['#E2D2A8', '#D8C8A0'];

const garden = (c, t, light) => {
  KIT.sky(c, t, light, { sun: [1040, 150] });
  KIT.land(c, light, { farCol: '#B8A890', midCol: '#9AAE76' });
  K.par(c, 0.8, () => {
    KIT.ground(c, 540, light, '#B9C98A');
    // palace: white stone with arches (no figures on it)
    c.fillStyle = K.tone('#EFE6D2', light); c.fillRect(380, 330, 520, 220);
    c.fillStyle = K.tone('#D8CCB2', light); c.fillRect(380, 310, 520, 24);
    for (let i = 0; i < 5; i++) { const x = 420 + i * 96; c.fillStyle = K.tone('#B8AA90', light); c.beginPath(); c.moveTo(x, 550); c.lineTo(x, 420); c.arc(x + 28, 420, 28, Math.PI, 0); c.lineTo(x + 56, 550); c.fill(); }
    c.fillStyle = K.tone('#E2C26A', light); c.beginPath(); c.arc(640, 300, 46, Math.PI, 0); c.fill();
  });
  K.par(c, 1, () => { KIT.palm(c, 200, 660, 210, light, t, 0); KIT.palm(c, 1100, 670, 230, light, t, 2); });
};
// a small friendly ant, facing +x; lift raises the antennae
const ant = (c, x, y, s, t, ph = 0, o = {}) => {
  c.save(); c.translate(x, y); c.scale(s * (o.dir || 1), s);
  const step = Math.sin(t * 14 + ph) * (o.walk ?? 1);
  c.strokeStyle = '#3A2418'; c.lineWidth = 2.2; c.lineCap = 'round';
  for (let i = 0; i < 3; i++) for (const side of [-1, 1]) { const bx = -8 + i * 8; c.beginPath(); c.moveTo(bx, 0); c.lineTo(bx + side * 3 + step * 3 * (i % 2 ? 1 : -1), 9); c.stroke(); }
  c.fillStyle = '#5A3424';
  c.beginPath(); c.ellipse(-12, -3, 8, 6, 0, 0, TAU); c.fill();
  c.beginPath(); c.ellipse(0, -3, 5, 4, 0, 0, TAU); c.fill();
  c.beginPath(); c.arc(10, -5, 5.5, 0, TAU); c.fill();
  const lift = o.lift || 0;
  c.beginPath(); c.moveTo(12, -9); c.quadraticCurveTo(16, -18 - lift * 6, 20 + lift * 2, -16 - lift * 8); c.moveTo(10, -9); c.quadraticCurveTo(12, -19 - lift * 6, 14, -20 - lift * 8); c.stroke();
  c.fillStyle = '#FFFFFF'; c.beginPath(); c.arc(12, -6, 1.4, 0, TAU); c.fill();   // an animal may have an eye
  c.restore();
};
const procession = (c, t, x0, gy, s, o = {}) => {
  // rows of featureless men in step, birds in formation above
  for (let row = 0; row < 3; row++) {
    for (let i = 0; i < 12; i++) {
      const x = x0 + i * 70 * s + row * 20 * s, y = gy + row * 22 * s;
      K.person(c, x, y, s * (0.85 + row * 0.08), { phase: t * 5 + i * 0.6, walk: o.walk ?? 1, robe: ARMY[(i + row) % 3], cloth: ARMYC[i % 2], dir: o.dir || 1 });
    }
  }
};
const flock = (c, t, x0, y0, s, alpha = 1) => {
  for (let i = 0; i < 14; i++) {
    const col = i % 7, row = Math.floor(i / 7);
    const x = x0 + col * 46 * s - row * 23 * s, y = y0 - Math.abs(col - 3) * 10 * s + row * 30 * s + Math.sin(t * 2 + i) * 4;
    const f = Math.sin(t * 9 + i) * 0.8;
    c.strokeStyle = K.rgba('#3A3448', alpha); c.lineWidth = 2.2 * s; c.lineCap = 'round';
    c.beginPath(); c.moveTo(x - 9 * s, y - f * 5 * s); c.quadraticCurveTo(x - 4 * s, y - 3 * s, x, y); c.quadraticCurveTo(x + 4 * s, y - 3 * s, x + 9 * s, y - f * 5 * s); c.stroke();
  }
};
const HOLES = [[300, 610], [520, 640], [760, 620], [980, 650], [1160, 615]];
const valleyFloor = (c, light) => {
  KIT.ground(c, 520, light, '#D2B682');
  for (const [x, y] of HOLES) {
    c.fillStyle = K.tone('#B89662', light); c.beginPath(); c.ellipse(x, y, 54, 18, 0, Math.PI, TAU); c.fill();
    c.fillStyle = '#3A2418'; c.beginPath(); c.ellipse(x, y - 4, 13, 6, 0, 0, TAU); c.fill();
  }
};

const s1 = { // God gave Dawud and Sulayman knowledge; they praised Him
  cam: (p) => [K.lerp(1.02, 1.14, E(p)), 640, K.lerp(380, 430, E(p)), 0],
  draw(c, t, d, p) {
    const ilm = B(1, 'علم', 4.72), hm = B(1, 'فحمد', 5.36);
    garden(c, t, 0.95);
    K.par(c, 1, () => {
      const up = A(t, hm - 0.2, 1);
      K.presence(c, 560, 600, 26 + 6 * up, t, A(t, 0.6, 1));   // Dawud
      K.presence(c, 720, 600, 26 + 6 * up, t, A(t, 1.6, 1));   // Sulayman
      K.dust(c, t, 2701, 24, '#FFF4C8', 0.6 * A(t, ilm - 0.3, 1), 500, 780, 380, 620, 2);
      K.rays(c, 640, 600, 8, 700, -Math.PI * 0.85, -Math.PI * 0.15, '#FFF0C8', 0.1 * up, t);
    });
    KIT.foreGrass(c, t, 0.95);
  },
};
const s2 = { // Sulayman inherited from his father: prophethood, knowledge, kingship
  cam: (p) => [K.lerp(1.14, 1.22, E(p)), K.lerp(640, 700, E(p)), 440, 0],
  draw(c, t, d, p) {
    const mk = B(2, 'الملك', 5.12);
    garden(c, t, 0.92);
    K.par(c, 1, () => {
      K.presence(c, 560, 600, 22, t, K.lerp(0.9, 0.35, E(p)));
      K.presence(c, 720, 600, 26 + 10 * A(t, 0.5, d), t, 1);
      K.glow(c, 640, 300, 160, '#FFE0A0', 0.3 * A(t, mk - 0.3, 1));
    });
    KIT.foreGrass(c, t, 0.92);
  },
};
const s3 = { // he was taught the speech of birds and given of everything
  cam: (p) => [K.lerp(1.2, 1.1, E(p)), 700, K.lerp(440, 410, E(p)), 0],
  draw(c, t, d, p) {
    const ty = B(3, 'الطير', 2.32), at = B(3, 'وأعطاه', 2.88);
    garden(c, t, 0.94);
    K.par(c, 1, () => {
      K.presence(c, 720, 600, 30, t, 1);
      // birds gather and circle around the light on «الطير»
      const g = A(t, ty - 1, 1.6);
      for (let i = 0; i < 12; i++) {
        const a = t * (0.6 + (i % 3) * 0.15) + i * TAU / 12, rr = K.lerp(600, 120 + (i % 4) * 30, g);
        const x = 720 + Math.cos(a) * rr, y = 520 + Math.sin(a) * rr * 0.45 - 40, f = Math.sin(t * 10 + i) * 0.8;
        c.strokeStyle = '#3A3448'; c.lineWidth = 2.6; c.lineCap = 'round';
        c.beginPath(); c.moveTo(x - 10, y - f * 6); c.quadraticCurveTo(x - 4, y - 4, x, y); c.quadraticCurveTo(x + 4, y - 4, x + 10, y - f * 6); c.stroke();
      }
      K.dust(c, t, 2702, 30, '#FFF0B8', 0.6 * A(t, at - 0.2, 1), 560, 880, 400, 640, 2);
    });
    KIT.foreGrass(c, t, 0.94);
  },
};
const s4 = { // his hosts of jinn, men and birds were gathered, marching in order
  cam: (p) => [1.04, K.lerp(380, 900, E(p)), 380, 0],
  draw(c, t, d, p) {
    const ty = B(4, 'الطير', 5.12);
    KIT.sky(c, t, 0.95, { sun: [1100, 140] });
    KIT.land(c, 0.95, { farCol: '#C8B090', midCol: '#C9A872' });
    K.par(c, 1, () => {
      KIT.ground(c, 560, 0.95, '#D9B880');
      const x0 = -200 + 220 * p;
      K.presence(c, x0 + 900, 610, 30, t, 1);
      procession(c, t, x0, 640, 0.95);
      flock(c, t, x0 + 300 + 80 * p, 200, 1.4, A(t, ty - 0.6, 0.8));
    });
    K.par(c, 1.1, () => K.dust(c, t, 2703, 36, '#E8C99A', 0.4, -100, W + 100, 560, 720, 10));
  },
};
const s5 = { // until they came to the valley of the ants
  cam: (p) => [K.lerp(1.0, 1.35, E(p)), 640, K.lerp(380, 560, E(p)), 0],
  draw(c, t, d, p) {
    KIT.sky(c, t, 0.95, { sun: [1100, 140] });
    KIT.land(c, 0.95, { farCol: '#C8B090', midCol: '#C9A872' });
    K.par(c, 0.7, () => { procession(c, t, -300 + 160 * p, 470, 0.5); });
    K.par(c, 1, () => {
      valleyFloor(c, 0.95);
      for (let i = 0; i < 18; i++) { const x = K.mod(i * 77 + t * 30, 1100) + 100, y = 600 + (i % 4) * 20; ant(c, x, y, 0.9, t, i); }
    });
  },
};
const s6 = { // an ant said: ants, go into your homes, lest Sulayman and his hosts crush you unknowing
  cam: (p, t, d) => {
    const nm = B(6, 'نملة', 1.12);
    return [K.lerp(1.3, 1.9, A(t, nm - 0.6, 1.2)), K.lerp(640, 560, A(t, nm - 0.6, 1.2)), K.lerp(540, 600, A(t, nm - 0.6, 1.2)), 0];
  },
  draw(c, t, d, p) {
    const nm = B(6, 'نملة', 1.12), dk = B(6, 'ادخلوا', 3.28);
    KIT.sky(c, t, 0.95, { sun: [1100, 140] });
    KIT.land(c, 0.95, { farCol: '#C8B090', midCol: '#C9A872' });
    K.par(c, 0.7, () => procession(c, t, -100 + 120 * p, 470, 0.5));
    K.par(c, 1, () => {
      valleyFloor(c, 0.95);
      // the ants run to the nearest hole on «ادخلوا» and vanish into it
      const run = A(t, dk - 0.2, 2.6, (x) => x);
      for (let i = 0; i < 18; i++) {
        const x0 = K.mod(i * 77 + Math.min(t, dk) * 30, 1100) + 100, y0 = 600 + (i % 4) * 20;
        const [hx, hy] = HOLES.reduce((b, h) => (Math.abs(h[0] - x0) < Math.abs(b[0] - x0) ? h : b));
        const u = K.clamp(run * 1.4 - (i % 5) * 0.08);
        if (u >= 1) continue;
        ant(c, K.lerp(x0, hx, u), K.lerp(y0, hy - 4, u), 0.9 * (1 - u * 0.4), t * (1 + run), i, { dir: hx < x0 && u > 0 ? -1 : 1 });
      }
      // the one who warned stands on a pebble, antennae up
      c.fillStyle = '#B8A07A'; c.beginPath(); c.ellipse(560, 612, 26, 10, 0, 0, TAU); c.fill();
      ant(c, 560, 602, 1.2, t, 0, { walk: 0, lift: A(t, nm - 0.2, 0.4) });
    });
  },
};
const s7 = { // he smiled at her words, for she understood and warned her people
  cam: (p) => [K.lerp(1.2, 1.05, E(p)), 640, K.lerp(500, 420, E(p)), 0],
  draw(c, t, d, p) {
    const tb = B(7, 'فتبسم', 0.32);
    KIT.sky(c, t, 0.95, { sun: [1100, 140] });
    KIT.land(c, 0.95, { farCol: '#C8B090', midCol: '#C9A872' });
    K.par(c, 0.85, () => { procession(c, t, 120, 520, 0.6, { walk: 0 }); K.presence(c, 960, 500, 22 + 8 * A(t, tb, 0.6), t, 1); });
    K.par(c, 1, () => { valleyFloor(c, 0.95); ant(c, 560, 602, 1.2, t, 0, { walk: 0, lift: 0.4 }); });
  },
};
const s8 = { // he remembered God's favour and prayed in thanks
  cam: (p) => [K.lerp(1.05, 1.18, E(p)), 820, K.lerp(420, 380, E(p)), 0],
  draw(c, t, d, p) {
    const da = B(8, 'فدعا', 3.04);
    KIT.sky(c, t, 0.97, { sun: [1100, 140], extra: () => K.rays(c, 960, 500, 12, 900, -Math.PI * 0.9, -Math.PI * 0.1, '#FFF0C8', 0.12 * A(t, da - 0.2, 1), t) });
    KIT.land(c, 0.95, { farCol: '#C8B090', midCol: '#C9A872' });
    K.par(c, 0.85, () => { procession(c, t, 120, 520, 0.6, { walk: 0 }); K.presence(c, 960, 500, 26 + 10 * A(t, da, 1), t, 1); });
    K.par(c, 1, () => valleyFloor(c, 0.95));
  },
};
const s9 = { // recitation 27:19 - the valley at peace; the light brightens with the du'a
  cam: (p) => [K.lerp(1.0, 1.12, E(p)), K.lerp(560, 760, E(p)), K.lerp(400, 430, E(p)), 0],
  draw(c, t, d, p) {
    const marks = [B(9, 'رب', 6.8), B(9, 'أشكر', 10.32), B(9, 'صالحا', 24.64), B(9, 'الصالحين', 31.84)];
    KIT.sky(c, t, 0.97, { sun: [1100, 140] });
    K.par(c, 0.15, () => K.birds(c, t, 2704, 7, 400, 200, 200, 26, 9, '#4A4A58', 0.6));
    KIT.land(c, 0.95, { farCol: '#C8B090', midCol: '#C9A872' });
    K.par(c, 0.85, () => {
      procession(c, t, 120, 520, 0.6, { walk: 0 });
      K.presence(c, 960, 500, 30, t, 1);
      for (const at of marks) { const q = K.clamp((t - at) / 2.4); if (q > 0 && q < 1) { c.strokeStyle = K.rgba('#FFE2A0', 0.45 * (1 - q)); c.lineWidth = 3; c.beginPath(); c.ellipse(960, 500, 40 + q * 300, 20 + q * 140, 0, 0, TAU); c.stroke(); } }
    });
    K.par(c, 1, () => {
      valleyFloor(c, 0.95);
      // the ants peep out of their homes, safe
      HOLES.forEach(([x, y], i) => { const up = 0.5 + 0.5 * Math.sin(t * 0.8 + i * 1.3); if (up > 0.3) ant(c, x + 6, y - 8 - up * 6, 0.8, t, i, { walk: 0, lift: up }); });
    });
  },
};
const s10 = { cam: (p) => [K.lerp(1.1, 1.02, E(p)), 640, K.lerp(390, 362, E(p)), 0], draw(c, t, d, p) { KIT.lesson(c, t, p, { seed: 2705 }); K.par(c, 1, () => { for (let i = 0; i < 6; i++) ant(c, 60 + i * 40 + K.mod(t * 20, 40), 690, 0.8, t, i); }); } };

window.STORY_SCENES = [s1, s2, s3, s4, s5, s6, s7, s8, s9, s10];
})();
