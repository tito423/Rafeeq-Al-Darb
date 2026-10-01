// Story 2 - Yunus (Jonah), peace be upon him. VISUALS ONLY.
// Narration and its sources: docs/kids_stories/yunus_narration.md (verses +
// al-Muyassar). Rules (docs/kids_stories_brief.md rule 1): Yunus is NEVER
// drawn - his presence is only a warm light (K.presence); ordinary people are
// flat and featureless; no angels; no text; nothing beyond the narration.
// Events are keyed to the spoken word (K.beat) from words.json; the fallback
// seconds are the measured times.
'use strict';
(() => {
const { W, H } = K;
const TAU = Math.PI * 2;
const E = K.easeInOut;
const B = K.beat, A = K.after;

// ---- shared ----
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
const palm = (c, x, gy, h, light, t, ph = 0, wind = 1) =>
  K.palm(c, x, gy, h, K.tone('#6B4A34', light), K.tone('#5E7A45', light), wind * (Math.sin(t * 0.9 + ph) + 0.35 * Math.sin(t * 2.3 + ph * 2)));
const ROBES = ['#7A5A48', '#5E6A7A', '#8A6E3E', '#6E4E5A', '#4E6A58', '#8C5A4A', '#6A5E7E'];
const CLOTH = ['#E9DCC4', '#D8CBB0', '#EFE4CC', '#DCCFB8'];
// A river town on a plain (Nineveh is not named on screen - nothing is).
const town = (c, t, light, glow) => {
  K.par(c, 0.3, () => { K.ridge(c, 420, 50, 1.7, 0.7, K.tone('#BFA08E', light)); K.haze(c, 320, 480, K.mix('#F2DCC0', '#8A90C0', 1 - light), 0.28); });
  K.par(c, 0.55, () => K.ridge(c, 470, 30, 5.1, 1.1, K.tone('#C49A72', light)));
  K.par(c, 0.8, () => { ground(c, 520, light); K.town(c, 147, 26, 120, 1160, 540, 1.1, light, glow); });
};
const foreGrass = (c, t, light, y = 746, wind = 1) => K.par(c, 1.32, () => {
  const col = K.tone('#5E6B3A', light * 0.7);
  K.grass(c, 191, -380, 260, y, 46, col, t, wind);
  K.grass(c, 192, 1040, 1680, y, 52, col, t + 0.7, wind);
});
// A crowd of townspeople around (x, gy): n figures, deterministic placement.
const crowd = (c, seed, n, x0, x1, gy, s, t, o = {}) => {
  const r = K.rng(seed), list = [];
  for (let i = 0; i < n; i++) list.push({ x: x0 + r() * (x1 - x0), row: r(), k: Math.floor(r() * 7), cl: Math.floor(r() * 4), ph: r() * TAU, d: r() < 0.5 ? 1 : -1 });
  list.sort((a, b) => a.row - b.row);
  for (const p of list) {
    const ss = s * (0.8 + p.row * 0.4), y = gy + p.row * 26 * s;
    const vis = o.appear ? K.clamp((o.appear - p.row * 0.3 - (p.x - x0) / (x1 - x0) * 0.5) / 0.2) : 1;
    if (vis <= 0) continue;
    c.save(); c.globalAlpha *= vis;
    const off = o.leave ? -o.leave * 260 * (0.6 + p.row) * p.d : 0;
    K.person(c, p.x + off, y, ss, { phase: t * 5 + p.ph, walk: o.walk || (o.leave > 0 && o.leave < 1 ? 1 : 0), robe: ROBES[p.k], cloth: CLOTH[p.cl], dir: o.leave ? p.d * -1 : (o.face || p.d), shake: o.shake || 0, point: o.point || 0 });
    c.restore();
  }
};

// ---- the ship: a merchant sailing vessel, loaded (al-Saffat 37:140 «المشحون») ----
const ship = (c, x, y, s, t, o = {}) => {
  const roll = (o.roll ?? 0.03) * Math.sin(t * 1.3) + (o.tilt || 0);
  c.save(); c.translate(x, y); c.rotate(roll); c.scale(s, s);
  // mast and sail (behind the people)
  c.fillStyle = '#5A3A24'; c.fillRect(-6, -300, 12, 300);
  c.fillRect(-150, -280, 300, 8);
  const bil = 18 + 10 * Math.sin(t * 1.1) + (o.wind || 0) * 30;
  c.fillStyle = K.tone('#F1E4C8', o.light ?? 1);
  c.beginPath(); c.moveTo(-140, -272); c.lineTo(140, -272); c.quadraticCurveTo(150 + bil, -170, 132, -70); c.lineTo(-132, -70); c.quadraticCurveTo(-150 + bil, -170, -140, -272); c.fill();
  c.strokeStyle = K.rgba('#B9A888', 0.6); c.lineWidth = 3;
  for (const yy of [-210, -140]) { c.beginPath(); c.moveTo(-142 + bil * 0.4, yy); c.quadraticCurveTo(0, yy + 8, 142 + bil * 0.6, yy); c.stroke(); }
  c.strokeStyle = '#3E2A1A'; c.lineWidth = 2;
  c.beginPath(); c.moveTo(0, -300); c.lineTo(-250, -10); c.moveTo(0, -300); c.lineTo(250, -10); c.stroke();
  // cargo: crates and sacks fill the deck
  const cargo = o.cargo ?? 1;
  const CR = [[-200, 44, '#9A6A43'], [-150, 40, '#B07C4E'], [150, 42, '#9A6A43'], [196, 36, '#A87447'], [-175, 30, '#8C5E3A'], [172, 30, '#B07C4E']];
  CR.forEach(([cx, sz, col], i) => {
    const k = K.easeOutBack(K.clamp(cargo * CR.length - i));
    if (k <= 0) return;
    const yy = i >= 4 ? -sz - 40 : -sz;
    c.fillStyle = col; c.fillRect(cx - sz / 2, yy - (1 - k) * 60, sz, sz);
    c.strokeStyle = K.rgba('#3E2A1A', 0.5); c.lineWidth = 2; c.strokeRect(cx - sz / 2, yy - (1 - k) * 60, sz, sz);
  });
  // passengers (featureless), the presence among them
  if (o.people) o.people(c);
  // hull
  c.fillStyle = '#7A4A2C';
  c.beginPath(); c.moveTo(-300, 0); c.lineTo(300, 0); c.quadraticCurveTo(290, 70, 210, 96); c.lineTo(-210, 96); c.quadraticCurveTo(-290, 70, -300, 0); c.fill();
  c.fillStyle = '#8E5834'; c.fillRect(-296, 0, 592, 14);
  c.strokeStyle = K.rgba('#3E2414', 0.5); c.lineWidth = 2;
  for (const yy of [32, 58, 80]) { c.beginPath(); c.moveTo(-282 + (yy - 32) * 0.5, yy); c.lineTo(282 - (yy - 32) * 0.5, yy); c.stroke(); }
  c.fillStyle = '#6A3E24';
  c.beginPath(); c.moveTo(300, 0); c.quadraticCurveTo(330, -30, 340, -60); c.lineTo(316, -50); c.quadraticCurveTo(306, -20, 286, 0); c.fill();
  c.beginPath(); c.moveTo(-300, 0); c.quadraticCurveTo(-326, -26, -334, -50); c.lineTo(-312, -44); c.quadraticCurveTo(-302, -18, -286, 0); c.fill();
  c.restore();
};
const SAILORS = [[-110, 2, 0], [-60, 4, 1], [30, 3, 2], [84, 5, 3], [120, 6, 1]];
const deckPeople = (t, o = {}) => (c) => {
  SAILORS.forEach(([x, k, cl], i) => K.person(c, x, 0, 0.95, { phase: t * 2 + i, robe: ROBES[k], cloth: CLOTH[cl], dir: i % 2 ? -1 : 1, shake: o.shake || 0 }));
  if (o.glow !== undefined) K.presence(c, -12, -46, 26, t, o.glow);
};

// ---- the whale: big, round and gentle - for children, not a monster ----
const whale = (c, x, y, s, t, o = {}) => {
  const sw = Math.sin(t * 1.4) * 0.12, mouth = o.mouth || 0;
  c.save(); c.translate(x, y); c.scale(s * (o.dir || 1), s); c.rotate(o.rot || 0);
  const body = o.col || '#3F5F86', belly = K.mix(body, '#B9CCE0', 0.55);
  // tail
  c.save(); c.translate(-300, -10); c.rotate(sw);
  c.fillStyle = body;
  c.beginPath(); c.moveTo(40, 0); c.quadraticCurveTo(-20, -10, -90, -70); c.quadraticCurveTo(-60, -10, -100, 50); c.quadraticCurveTo(-20, 10, 40, 10); c.fill();
  c.restore();
  // body
  c.fillStyle = body;
  c.beginPath(); c.moveTo(-310, -6);
  c.bezierCurveTo(-200, -120, 120, -150, 250, -60);
  c.quadraticCurveTo(300, -20, 290, 10 - mouth * 20);
  c.lineTo(180, 20 + mouth * 10);
  c.lineTo(290, 30 + mouth * 40);
  c.quadraticCurveTo(250, 110, 60, 110);
  c.bezierCurveTo(-120, 110, -250, 60, -310, 6);
  c.closePath(); c.fill();
  // belly grooves
  c.fillStyle = belly;
  c.beginPath(); c.moveTo(-200, 60); c.quadraticCurveTo(40, 130, 270, 40 + mouth * 40); c.quadraticCurveTo(200, 104, 40, 108); c.quadraticCurveTo(-120, 104, -200, 60); c.fill();
  c.strokeStyle = K.rgba(body, 0.35); c.lineWidth = 3;
  for (let i = 0; i < 5; i++) { c.beginPath(); c.moveTo(-60 + i * 50, 92 - i * 3); c.quadraticCurveTo(40 + i * 50, 98, 120 + i * 40, 70 + mouth * 20); c.stroke(); }
  // flipper
  c.save(); c.translate(40, 70); c.rotate(0.5 + Math.sin(t * 1.4 + 1) * 0.15);
  c.fillStyle = K.mix(body, '#1E3350', 0.2); c.beginPath(); c.ellipse(0, 30, 22, 60, 0, 0, TAU); c.fill(); c.restore();
  // eye - an animal may have eyes; a kind, sleepy one
  c.fillStyle = '#16233A'; c.beginPath(); c.arc(190, -18, 9, 0, TAU); c.fill();
  c.fillStyle = '#FFFFFF'; c.beginPath(); c.arc(193, -21, 3, 0, TAU); c.fill();
  // what is inside shows as a soft light through the body (o.inner)
  if (o.inner) {
    c.save(); c.beginPath(); c.ellipse(0, 10, 260, 90, 0, 0, TAU); c.clip();
    c.globalCompositeOperation = 'lighter';
    K.glow(c, -10, 20, 170, '#FFC878', 0.32 * o.inner);
    c.restore();
  }
  c.restore();
};

// underwater: depth gradient, light shafts from the surface, bubbles, fish
const deep = (c, t, d = 1) => {
  K.par(c, 0, () => {
    const g = c.createLinearGradient(0, -420, 0, H + 200);
    g.addColorStop(0, K.mix('#3B8FB0', '#123050', d * 0.6)); g.addColorStop(0.5, K.mix('#1E5E84', '#0A1C36', d * 0.7)); g.addColorStop(1, K.mix('#0E3354', '#040C1C', d));
    c.fillStyle = g; c.fillRect(-420, -420, W + 840, H + 840);
    K.rays(c, 640, -260, 9, 1100, Math.PI * 0.32, Math.PI * 0.68, '#BFE6F2', 0.1 * (1 - d * 0.7), t);
  });
  K.par(c, 0.4, () => {
    const r = K.rng(4401);
    for (let i = 0; i < 3; i++) {
      const y0 = 160 + i * 150, sp = 18 + i * 9;
      for (let j = 0; j < 7; j++) {
        const x = K.mod(r() * W + t * sp, W + 300) - 150, y = y0 + Math.sin(t * 1.2 + j) * 10 + r() * 30;
        c.fillStyle = K.rgba(i % 2 ? '#7FC4D8' : '#A8D8E4', 0.35 * (1 - d * 0.5));
        c.beginPath(); c.ellipse(x, y, 9, 4, 0, 0, TAU); c.moveTo(x - 9, y); c.lineTo(x - 15, y - 4); c.lineTo(x - 15, y + 4); c.fill();
      }
    }
  });
};
const bubbles = (c, t, seed, n, alpha, x0 = 0, x1 = W) => {
  const r = K.rng(seed);
  for (let i = 0; i < n; i++) {
    const x = x0 + r() * (x1 - x0), ph = r(), rad = 2 + r() * 6, sp = 0.5 + r();
    const y = H + 40 - K.fract(ph + t * 0.12 * sp) * (H + 80);
    c.strokeStyle = K.rgba('#DDF3F5', alpha); c.lineWidth = 1.6;
    c.beginPath(); c.arc(x + Math.sin(t * 2 + ph * 9) * 6, y, rad, 0, TAU); c.stroke();
  }
};
const sea = (c, t, level, Am, light = 1, cols) => {
  const [a, b] = cols || ['#3F86A2', '#1F4F6A'];
  K.water(c, (x) => level - Am * (Math.sin(x * 0.009 - t * 1.1) + 0.4 * Math.sin(x * 0.021 + t * 1.7)), level - Am - 10, H + 200, K.tone(a, light), K.tone(b, light), K.rgba('#E3F2F4', 0.8), 3);
};

// ---- 1. Yunus is sent to his people, to call them to God alone (21:87) ----
const s1 = {
  cam: (p, t, d) => [K.lerp(1.02, 1.16, E(p)), K.lerp(520, 660, E(p)), K.lerp(370, 420, E(p)), 0],
  draw(c, t, d, p) {
    const yu = B(1, 'يونس', 2.16), yd = B(1, 'يدعوهم', 4.96);
    K.par(c, 0, () => {
      K.sky(c, skyAt(0.95), 0, 480);
      K.sun(c, 1040, 140, 34, '#FFF1C4', '#FFD68A', 0.45);
      for (const [x, y, s, v] of [[200, 120, 0.9, 7], [640, 80, 0.7, 5], [1100, 150, 1.0, 6]]) K.cloud(c, K.mod(x + t * v + 200, W + 500) - 250, y, s, '#FFF8EC', 0.9);
    });
    K.par(c, 0.12, () => K.birds(c, t, 2101, 6, 300, 200, 180, 30, 9, '#4A3A40', 0.6));
    town(c, t, 0.95, 0);
    K.par(c, 1, () => {
      // a few townspeople in the square
      crowd(c, 2102, 9, 560, 1000, 640, 1.05, t, { face: -1 });
      // his presence arrives on «يونس», moves to them on «يدعوهم»
      const x = K.lerp(300, 470, A(t, yd - 0.4, 1.4));
      K.presence(c, x, 600, 28, t, A(t, yu - 0.3, 0.9));
      palm(c, 180, 660, 200, 0.95, t, 0);
    });
    K.par(c, 1.08, () => K.dust(c, t, 2103, 30, '#FFF1D2', 0.4, -100, W + 100, 300, 700, 5));
    foreGrass(c, t, 0.95);
  },
};

// ---- 2. They did not believe; he warned them; they did not turn back (21:87) ----
const s2 = {
  cam: (p, t, d) => [K.lerp(1.16, 1.1, E(p)), K.lerp(660, 620, E(p)), K.lerp(420, 400, E(p)), 0],
  draw(c, t, d, p) {
    const fy = B(2, 'يؤمنوا', 0.72), wr = B(2, 'العذاب', 2.64);
    const dim = A(t, wr - 0.6, 1.4);
    K.par(c, 0, () => {
      K.sky(c, skyAt(0.95).map((col) => K.mix(col, '#7A7E98', 0.45 * dim)), 0, 480);
      K.sun(c, 1040, 140, 34, '#FFF1C4', '#FFD68A', 0.45, 1 - 0.5 * dim);
      for (let i = 0; i < 6; i++) K.cloud(c, K.mod(i * 260 + t * 9 + 100, W + 500) - 250, 90 + (i % 2) * 40, 1.2, K.mix('#FFF8EC', '#6E7088', dim), 0.5 + 0.4 * dim);
    });
    town(c, t, 0.95 - 0.25 * dim, 0);
    K.par(c, 1, () => {
      // they turn their backs and walk away on «فلم يؤمنوا»
      crowd(c, 2102, 9, 560, 1000, 640, 1.05, t, { face: -1, leave: A(t, fy - 0.2, 2.6, (x) => x) });
      K.presence(c, 470, 600, 28, t, 1 - 0.15 * dim);
    });
    foreGrass(c, t, 0.9 - 0.2 * dim);
  },
};

// ---- 3. He did not stay patient with them and left, angry, heavy-hearted (21:87) ----
const s3 = {
  cam: (p, t, d) => [1.08, K.lerp(600, 380, E(p)), 400, 0],
  draw(c, t, d, p) {
    const kh = B(3, 'وخرج', 1.84);
    const light = K.lerp(0.75, 0.52, p);
    K.par(c, 0, () => {
      K.sky(c, skyAt(light), 0, 480);
      K.sun(c, 200, K.lerp(330, 420, p), 32, '#FFE1A0', '#FF9E5E', 0.5);
    });
    town(c, t, light, 0.2 * p);
    K.par(c, 1, () => {
      // the road out of the town, toward the sea on the left
      c.fillStyle = K.tone('#E6C38E', light);
      c.beginPath(); c.moveTo(-420, 690); c.quadraticCurveTo(300, 620, 700, 640); c.lineTo(700, 660); c.quadraticCurveTo(300, 650, -420, 740); c.fill();
      const x = K.lerp(520, 40, A(t, kh - 0.2, d - kh, (x) => x));
      // dimmer, redder: a heavy heart (the narration says so; nothing more is drawn)
      c.save(); c.globalCompositeOperation = 'source-over';
      K.presence(c, x, 630, 26, t, 0.8);
      c.restore();
    });
    K.par(c, 1.06, () => K.dust(c, t, 2301, 24, '#FFD9A8', 0.35, -100, W + 100, 380, 700, -8));
    foreGrass(c, t, light, 746, 1.4);
  },
};

// ---- 4. He boarded a ship full of passengers and goods (37:140) ----
const s4 = {
  cam: (p, t, d) => [K.lerp(1.0, 1.12, E(p)), K.lerp(560, 700, E(p)), K.lerp(360, 400, E(p)), 0],
  draw(c, t, d, p) {
    const rk = B(4, 'وركب', 0.4), mm = B(4, 'مملوءة', 2.32);
    K.par(c, 0, () => {
      K.sky(c, ['#6E9CC6', '#BFD6E2', '#F2DEC0'], 0, 460);
      for (const [x, y, s, v] of [[260, 110, 0.9, 6], [800, 80, 0.8, 5], [1180, 130, 0.7, 7]]) K.cloud(c, K.mod(x + t * v + 200, W + 500) - 250, y, s, '#FFF4E6', 0.85);
    });
    K.par(c, 0.12, () => K.birds(c, t, 2401, 5, 600, 180, 160, 24, 8, '#4A4A58', 0.5));
    K.par(c, 0.4, () => { c.fillStyle = '#9DB8C4'; c.fillRect(-420, 430, W + 840, 30); K.haze(c, 380, 470, '#E6EEF0', 0.4); });
    K.par(c, 1, () => {
      sea(c, t, 470, 6, 1);
      // the quay on the left
      c.fillStyle = '#B49A7A'; c.fillRect(-420, 520, 470, 260); c.fillStyle = '#8E765C'; c.fillRect(-420, 520, 470, 14);
      const sx = K.lerp(640, 780, A(t, d - 1.6, 1.6));
      ship(c, sx, 520, 0.9, t, { cargo: A(t, mm - 0.6, 1.4, (x) => x), people: deckPeople(t, { glow: A(t, rk - 0.2, 0.8) }) });
      sea(c, t + 2, 560, 5, 1, ['#3A7E9A', '#1A4560']);
      K.spray(c, t, 2402, 10, sx - 260, sx + 260, 560, 20, '#E8F6F8', 0.5);
    });
  },
};

// ---- 5. Great waves surrounded it; the passengers feared drowning (37:141) ----
const s5 = {
  cam: (p, t, d) => [1.12, 640 + 20 * Math.sin(t * 0.7), 400 + 14 * Math.sin(t * 1.1), Math.sin(t * 0.9) * 0.02],
  draw(c, t, d, p) {
    const am = B(5, 'الأمواج', 1.52), kh = B(5, 'وخاف', 3.12);
    const storm = A(t, am - 0.8, 1.2), Am = 8 + 46 * storm;
    K.par(c, 0, () => K.sky(c, [K.mix('#6E8CB0', '#2E3856', storm), K.mix('#B8C8D6', '#4E5A78', storm), K.mix('#E6DCC6', '#7E8AA2', storm)], 0, 460));
    K.par(c, 0.3, () => { for (let i = 0; i < 7; i++) K.cloud(c, K.mod(i * 230 + t * 40, W + 500) - 250, 80 + (i % 3) * 30, 1.4, '#4A5576', storm); });
    K.par(c, 1, () => {
      sea(c, t * 1.6, 470, Am * 0.6, 0.8, ['#3F6F8F', '#2A4F6C']);
      const y0 = 500 - Am * 0.8 * Math.sin(t * 1.6);
      ship(c, 640, y0, 0.78, t, { roll: 0.04 + 0.1 * storm, wind: storm, people: deckPeople(t, { glow: 0.85, shake: A(t, kh - 0.2, 0.4) }) });
      sea(c, t * 1.6 + 1.3, 560, Am, 0.9);
      K.spray(c, t, 2501, 30, 200, 1100, 540, 40 + 60 * storm, '#E8F6F8', 0.7 * storm);
    });
    K.par(c, 1.12, () => K.rain(c, t, 2502, 220, 0.38 * storm, -160, 900, 26));
  },
};

// ---- 6. They drew lots to lighten the ship; the lot fell on Yunus (37:141) ----
// A clay jar with marked sticks; one stick lights on «فوقعت القرعة».
const s6 = {
  cam: (p, t, d) => [K.lerp(1.5, 1.3, E(p)), K.lerp(620, 600, E(p)), K.lerp(470, 450, E(p)), Math.sin(t * 0.9) * 0.02],
  draw(c, t, d, p) {
    const qr = B(6, 'فوقعت', 2.72), yu = B(6, 'يونس', 4.72);
    const lit = A(t, qr - 0.1, 0.6);
    K.par(c, 0, () => K.sky(c, ['#2E3856', '#4E5A78', '#7E8AA2'], 0, 460));
    K.par(c, 1, () => {
      sea(c, t * 1.6, 470, 30, 0.8, ['#3F6F8F', '#2A4F6C']);
      ship(c, 640, 520, 0.9, t, { roll: 0.1, wind: 1, people: (cc) => {
        SAILORS.forEach(([x, k, cl], i) => K.person(cc, x, 0, 0.95, { phase: t * 2 + i, robe: ROBES[k], cloth: CLOTH[cl], dir: x < 0 ? 1 : -1 }));
        // the jar of lots on the deck between them
        cc.fillStyle = '#9A5E3A'; cc.beginPath(); cc.ellipse(0, -18, 22, 18, 0, 0, TAU); cc.fill();
        cc.fillRect(-12, -40, 24, 10);
        for (let i = 0; i < 3; i++) {
          const up = i === 1 ? 26 * lit : 0;
          cc.strokeStyle = i === 1 ? K.mix('#C8A070', '#FFE2A0', lit) : '#C8A070'; cc.lineWidth = 4;
          cc.beginPath(); cc.moveTo(-8 + i * 8, -36); cc.lineTo(-10 + i * 10, -66 - up); cc.stroke();
        }
        if (lit > 0) K.glow(cc, 0, -80, 40, '#FFE2A0', 0.6 * lit);
        K.presence(cc, -150, -46, 24 + 6 * A(t, yu - 0.2, 0.5), t, 0.9);
      } });
      sea(c, t * 1.6 + 1.3, 580, 30, 0.9);
    });
    K.par(c, 1.12, () => K.rain(c, t, 2601, 200, 0.32, -160, 900, 26));
  },
};

// ---- 7. He was cast into the sea, and the whale swallowed him (37:142) ----
const s7 = {
  cam: (p, t, d) => {
    const bh = B(7, 'البحر', 1.6);
    const under = A(t, bh - 0.1, 0.9);
    return [1.1, 640, K.lerp(380, 560, under), 0];
  },
  draw(c, t, d, p) {
    const bh = B(7, 'البحر', 1.6), ib = B(7, 'فبتلعه', 2.32), ht = B(7, 'الحوت', 3.44);
    const under = A(t, bh - 0.1, 0.9);
    K.par(c, 0, () => K.sky(c, ['#2E3856', '#4E5A78', '#7E8AA2'], 0, 460));
    K.par(c, 1, () => {
      sea(c, t * 1.6, 470, 22, 0.8, ['#3F6F8F', '#2A4F6C']);
      // below the surface: the sea in depth (clipped under the moving surface)
      const surf7 = (x) => 470 - 22 * (Math.sin(x * 0.009 - t * 1.6 * 1.1) + 0.4 * Math.sin(x * 0.021 + t * 1.6 * 1.7));
      c.save(); c.beginPath(); c.moveTo(-420, H + 800); for (let x = -420; x <= W + 420; x += 8) c.lineTo(x, surf7(x) + 6); c.lineTo(W + 420, H + 800); c.closePath(); c.clip();
      const g = c.createLinearGradient(0, 470, 0, H + 400);
      g.addColorStop(0, '#2E6E90'); g.addColorStop(1, '#0C2440'); c.fillStyle = g; c.fillRect(-420, 470, W + 840, 1200);
      bubbles(c, t, 2701, 30, 0.45);
      // the light sinks
      const gy = K.lerp(470, 612, A(t, bh - 0.2, 1.6));
      // the whale glides in and closes its mouth around it on «فابتلعه»
      const wx = K.lerp(-400, 470, A(t, ib - 1.3, 1.5, K.easeOut));
      const mouth = A(t, ib - 0.6, 0.4) * (1 - A(t, ib + 0.4, 0.4));
      whale(c, wx, 600, 0.6, t, { mouth, inner: A(t, ib + 0.3, 0.6) });
      K.presence(c, 640, gy, 22, t, 1 - A(t, ib + 0.1, 0.4));
      c.restore();
      // the ship sails on above; the splash on «البحر»
      ship(c, K.lerp(560, 900, p), 450, 0.6, t, { roll: 0.08, wind: 1, people: deckPeople(t) });
      K.spray(c, t, 2702, 30, 600, 680, 470, 90 * A(t, bh - 0.2, 0.2) * (1 - A(t, bh + 0.6, 0.6)), '#E8F6F8', 0.85);
    });
    // darkening as the whale's mouth closes
    K.par(c, 0, () => { c.fillStyle = K.rgba('#040A18', 0.55 * A(t, ht - 0.3, 0.9)); c.fillRect(-420, -420, W + 840, H + 840); });
  },
};

// ---- 8. In the darkness of night, sea and the whale's belly he called his Lord (21:87) ----
const s8 = {
  cam: (p, t, d) => {
    const bh = B(8, 'والبحر', 2.24), bt = B(8, 'وبطن', 3.12);
    return [K.lerp(1.0, 1.0, p) + 0.25 * A(t, bt - 0.2, 1.6), 640, K.lerp(260, 470, A(t, bh - 0.4, 1.2)), 0];
  },
  draw(c, t, d, p) {
    const ly = B(8, 'الليل', 1.6), bt = B(8, 'وبطن', 3.12), nd = B(8, 'نادى', 4.88);
    // 1) night above the sea
    K.par(c, 0, () => {
      K.sky(c, SKY.night, 0, 460);
      K.stars(c, 2801, 60, 0.35 * (1 - A(t, ly + 0.5, 1)), t, 380);
    });
    K.par(c, 1, () => {
      // 2) the dark sea below
      const g = c.createLinearGradient(0, 470, 0, H + 300);
      g.addColorStop(0, '#13304E'); g.addColorStop(1, '#030914'); c.fillStyle = g; c.fillRect(-420, 470, W + 840, 1200);
      bubbles(c, t, 2802, 16, 0.2);
      sea(c, t, 470, 6, 0.35, ['#1E3E5E', '#0E2440']);
      // 3) the whale's belly closes the view: darkness all round; only his light
      const close = A(t, bt - 0.2, 1.4);
      c.fillStyle = K.rgba('#020610', close * 0.92); c.fillRect(-420, -420, W + 840, H + 840);
      const call = A(t, nd - 0.1, 0.4);
      K.presence(c, 640, 520, 16 + 10 * call, t, 0.35 + 0.65 * close);
      // the call: soft rings of light going out from it
      for (let i = 0; i < 3; i++) {
        const q = K.fract((t - nd) / 1.6 + i / 3);
        if (t < nd) break;
        c.strokeStyle = K.rgba('#FFE2A0', 0.45 * (1 - q) * call); c.lineWidth = 2.5;
        c.beginPath(); c.arc(640, 520, 30 + q * 220, 0, TAU); c.stroke();
      }
    });
  },
};

// ---- 9. Recitation: al-Anbiya 21:87 (Minshawi). The whale swims slowly in the
// deep; the light inside it brightens on «فنادى» and with the words of the du'a.
const s9 = {
  cam: (p, t, d) => [K.lerp(1.08, 1.18, E(p)), K.lerp(560, 720, E(p)), K.lerp(420, 380, E(p)), 0],
  draw(c, t, d, p) {
    const fn = B(9, 'فنادى', 13.04), la = B(9, 'إله', 17.76), sb = B(9, 'سبحانك', 22.24), zl = B(9, 'الظالمين', 26.24);
    const lightUp = Math.max(0.35, 0.35 + 0.25 * A(t, fn - 0.2, 1) + 0.2 * A(t, la - 0.2, 1) + 0.2 * A(t, sb - 0.2, 1));
    deep(c, t, K.lerp(0.85, 0.6, A(t, zl, 3)));
    K.par(c, 0.7, () => bubbles(c, t, 2901, 24, 0.3));
    K.par(c, 1, () => {
      const wx = K.lerp(380, 860, p), wy = 430 + Math.sin(t * 0.5) * 20;
      whale(c, wx, wy, 1.05, t, { inner: lightUp, rot: Math.sin(t * 0.4) * 0.03 });
      // rings of light from inside on each part of the du'a
      for (const at of [fn, la, sb]) {
        const q = K.clamp((t - at) / 2.2);
        if (q <= 0 || q >= 1) continue;
        c.strokeStyle = K.rgba('#FFE2A0', 0.4 * (1 - q)); c.lineWidth = 3;
        c.beginPath(); c.ellipse(wx - 10, wy + 20, 120 + q * 360, 60 + q * 200, 0, 0, TAU); c.stroke();
      }
    });
    K.par(c, 1.2, () => bubbles(c, t + 4, 2902, 12, 0.35));
  },
};

// ---- 10. God answered him; the whale cast him onto bare land, weak (21:88, 37:145) ----
const s10 = {
  cam: (p, t, d) => {
    const al = B(10, 'وألقاه', 2.8);
    const up = A(t, al - 1.2, 1.6);
    return [K.lerp(1.1, 1.08, up), K.lerp(640, 600, up), K.lerp(520, 380, up), 0];
  },
  draw(c, t, d, p) {
    const fs = B(10, 'فاستجاب', 0.32), al = B(10, 'وألقاه', 2.8), ar = B(10, 'أرض', 4.72), df = B(10, 'ضعيف', 6.8);
    const bright = A(t, fs - 0.2, 1.4);
    K.par(c, 0, () => {
      K.sky(c, skyAt(K.lerp(0.6, 0.95, bright)), 0, 470);
      K.rays(c, 1020, 120, 10, 1000, Math.PI * 0.55, Math.PI * 0.95, '#FFF0C8', 0.12 * bright, t);
      K.sun(c, 1020, 120, 34, '#FFF1C4', '#FFD68A', 0.45, bright);
    });
    K.par(c, 0.4, () => { c.fillStyle = '#9DB8C4'; c.fillRect(-420, 440, W + 840, 30); });
    K.par(c, 1, () => {
      sea(c, t, 470, 5, K.lerp(0.7, 1, bright));
      // the bare shore: sand, nothing growing, no building
      c.fillStyle = '#E6CFA0';
      c.beginPath(); c.moveTo(-420, 560); c.quadraticCurveTo(300, 520, 700, 540); c.quadraticCurveTo(1000, 556, W + 420, 620); c.lineTo(W + 420, H + 420); c.lineTo(-420, H + 420); c.fill();
      c.strokeStyle = K.rgba('#FFFFFF', 0.6); c.lineWidth = 3;
      c.beginPath(); for (let x = -420; x <= W + 420; x += 10) { const y = (x < 700 ? 560 - (x + 420) / 1120 * 20 : 540 + (x - 700) / 1000 * 80) + 2 * Math.sin(x * 0.05 + t * 2); x === -420 ? c.moveTo(x, y) : c.lineTo(x, y); } c.stroke();
      // the whale comes up to the shallows, lets go, and turns back to the sea
      const come = A(t, fs, al - fs, K.easeOut), go = A(t, al + 1.2, 2.4, K.easeIn);
      const wx = K.lerp(1500, 980, come) + 700 * go;
      c.save(); c.beginPath(); c.rect(-420, 440, W + 840, 1000); c.clip();
      whale(c, wx, 540, 0.55, t, { dir: -1, mouth: A(t, al - 0.2, 0.3) * (1 - A(t, al + 0.6, 0.4)) });
      c.restore();
      // he is on the sand: the light, small and dim («ضعيف»)
      const onSand = A(t, al, 0.8);
      const lx = K.lerp(wx - 150, 560, onSand);
      K.presence(c, lx, 560, K.lerp(22, 14, A(t, df - 0.3, 0.8)), t, K.lerp(0.9, 0.6, A(t, df - 0.3, 0.8)) * (t < al - 0.3 ? 0 : 1));
    });
  },
};

// ---- 11. God made a gourd vine grow over him, shading him (37:146) ----
const s11 = {
  cam: (p, t, d) => [K.lerp(1.4, 1.25, E(p)), K.lerp(540, 580, E(p)), K.lerp(500, 470, E(p)), 0],
  draw(c, t, d, p) {
    const nb = B(11, 'وأنبت', 0.32), sj = B(11, 'شجرة', 2.24), qr = B(11, 'القرع', 3.52), tz = B(11, 'تظله', 4.16);
    const grow = A(t, nb - 0.1, sj + 1 - nb, (x) => x), leaf = A(t, sj - 0.3, 1.4), gourd = A(t, qr - 0.2, 0.8, K.easeOutBack);
    K.par(c, 0, () => {
      K.sky(c, skyAt(0.95), 0, 470);
      K.sun(c, 1020, 120, 34, '#FFF1C4', '#FFD68A', 0.45);
    });
    K.par(c, 0.4, () => { c.fillStyle = '#9DB8C4'; c.fillRect(-420, 440, W + 840, 30); sea(c, t, 470, 4, 1); });
    K.par(c, 1, () => {
      c.fillStyle = '#E6CFA0';
      c.beginPath(); c.moveTo(-420, 540); c.quadraticCurveTo(300, 520, 700, 530); c.quadraticCurveTo(1000, 546, W + 420, 600); c.lineTo(W + 420, H + 420); c.lineTo(-420, H + 420); c.fill();
      // shade falls on the sand under the leaves on «تظله»
      c.fillStyle = K.rgba('#8A6A40', 0.28 * A(t, tz - 0.3, 0.8)); c.beginPath(); c.ellipse(560, 580, 170, 26, 0, 0, TAU); c.fill();
      K.presence(c, 560, 560, K.lerp(14, 22, A(t, tz - 0.2, 1)), t, K.lerp(0.6, 1, A(t, tz - 0.2, 1)));
      // the vine: stems climb a low arch and spread broad leaves over him
      const r = K.rng(3711);
      c.lineCap = 'round';
      for (let s = 0; s < 3; s++) {
        const x0 = 470 + s * 90, len = grow * (240 + s * 30);
        c.strokeStyle = '#5E8A3A'; c.lineWidth = 5;
        c.beginPath(); c.moveTo(x0, 590);
        const pts = [];
        for (let k = 0; k <= 20; k++) {
          const u = (k / 20) * len / 260;
          if (u > 1) break;
          const x = x0 + Math.sin(u * 3 + s) * 30 + (s - 1) * 60 * u, y = 590 - Math.sin(u * Math.PI * 0.9) * 150 - u * 20 + Math.sin(t * 1.5 + k) * 1.5;
          c.lineTo(x, y); pts.push([x, y, u]);
        }
        c.stroke();
        pts.forEach(([x, y, u], k) => {
          if (k % 3 !== 1) return;
          const ls = leaf * K.clamp((grow * 1.2 - u) * 3) * (34 + r() * 16);
          if (ls <= 1) return;
          c.save(); c.translate(x, y); c.rotate(Math.sin(t * 1.2 + k) * 0.08 + (r() - 0.5));
          c.fillStyle = k % 2 ? '#6FA046' : '#7FB252';
          c.beginPath(); for (let j = 0; j < 5; j++) { const a = -Math.PI / 2 + (j - 2) * 0.55; c.moveTo(0, 0); c.quadraticCurveTo(Math.cos(a - 0.3) * ls * 0.7, Math.sin(a - 0.3) * ls * 0.7, Math.cos(a) * ls, Math.sin(a) * ls); c.quadraticCurveTo(Math.cos(a + 0.3) * ls * 0.7, Math.sin(a + 0.3) * ls * 0.7, 0, 0); } c.fill();
          c.restore();
          if (k % 6 === 4 && gourd > 0) { c.fillStyle = '#E3B04A'; c.beginPath(); c.ellipse(x, y + 18, 11 * gourd, 15 * gourd, 0.2, 0, TAU); c.fill(); c.fillStyle = '#F6E2A0'; c.beginPath(); c.ellipse(x - 3, y + 13, 3 * gourd, 5 * gourd, 0.2, 0, TAU); c.fill(); }
        });
      }
    });
    K.par(c, 1.08, () => K.dust(c, t, 3712, 24, '#FFF4D8', 0.35, -100, W + 100, 300, 700, 3));
  },
};

// ---- 12. He was sent to a hundred thousand or more, and they all believed (37:147-148) ----
const s12 = {
  cam: (p, t, d) => {
    const mi = B(12, 'مائة', 2.72);
    return [K.lerp(1.3, 1.02, A(t, mi - 0.8, 2.2)), K.lerp(560, 640, A(t, mi - 0.8, 2.2)), K.lerp(470, 380, A(t, mi - 0.8, 2.2)), 0];
  },
  draw(c, t, d, p) {
    const mi = B(12, 'مائة', 2.72), am = B(12, 'فآمنوا', 6.24);
    const believe = A(t, am - 0.2, 1.2);
    K.par(c, 0, () => {
      K.sky(c, skyAt(0.95), 0, 480);
      K.rays(c, 640, -80, 12, 1000, Math.PI * 0.25, Math.PI * 0.75, '#FFF0C8', 0.1 * believe, t);
      for (const [x, y, s, v] of [[200, 120, 0.9, 6], [640, 80, 0.7, 4], [1100, 150, 1.0, 5]]) K.cloud(c, K.mod(x + t * v + 200, W + 500) - 250, y, s, '#FFF8EC', 0.9);
    });
    K.par(c, 0.12, () => K.birds(c, t, 3801, 7, 400, 200, 200, 30, 9, '#4A3A40', 0.6));
    town(c, t, 0.95, 0.2);
    K.par(c, 1, () => {
      // the crowd fills the plain as «مائة ألف» is said - countless, small
      crowd(c, 3802, 90, 80, 1200, 590, 0.6, t, { appear: A(t, mi - 0.6, 2.4, (x) => x) * 1.6, face: -1 });
      // belief: a warm light rises over all of them
      K.glow(c, 640, 600, 600, '#FFD58A', 0.18 * believe);
      K.presence(c, 640, 560, 26, t, 1);
    });
    K.par(c, 1.08, () => K.dust(c, t, 3803, 36, '#FFF1D2', 0.4 + 0.3 * believe, -100, W + 100, 300, 700, 3));
    foreGrass(c, t, 0.95);
  },
};

// ---- 13. The lesson. Calm sea at sunset, the vine, the lower third left clear ----
const s13 = {
  cam: (p, t, d) => [K.lerp(1.12, 1.02, E(p)), 640, K.lerp(390, 362, E(p)), 0],
  draw(c, t, d, p) {
    const up = E(K.seg(p, 0, 0.8));
    K.par(c, 0, () => {
      K.sky(c, ['#5E7EB0', '#C69AA6', '#F7C99A', '#F3B080'], 0, 470);
      const sy = K.lerp(400, 440, up);
      K.rays(c, 640, sy, 12, 950, Math.PI + 0.2, TAU - 0.2, '#FFE6C0', 0.06, t);
      K.sun(c, 640, sy, 38, '#FFF0C2', '#FFB36B', 0.55);
      for (const [x, y, s, v] of [[250, 120, 0.8, 4], [600, 90, 0.6, 3], [1100, 140, 0.7, 5]]) K.cloud(c, K.mod(x + t * v + 200, W + 500) - 250, y, s, '#FFE6D4', 0.8);
    });
    K.par(c, 0.15, () => K.birds(c, t, 3901, 6, 200, 200, 170, 30, 9, '#4A3A48', 0.6));
    K.par(c, 0.6, () => {
      sea(c, t, 470, 4, 1, ['#E8A982', '#7C6E98']);
      c.strokeStyle = K.rgba('#FFE8C8', 0.6); c.lineWidth = 3;
      for (let i = 0; i < 8; i++) { const w = 120 - i * 12, y = 480 + i * 14; c.beginPath(); c.moveTo(640 - w / 2 + Math.sin(t + i) * 6, y); c.lineTo(640 + w / 2 + Math.sin(t + i) * 6, y); c.stroke(); }
    });
    K.par(c, 1, () => {
      c.fillStyle = '#E2C08E';
      c.beginPath(); c.moveTo(-420, 600); c.quadraticCurveTo(640, 570, W + 420, 600); c.lineTo(W + 420, H + 420); c.lineTo(-420, H + 420); c.fill();
      // small gourd leaves at the sides only; the centre of the lower third stays clear
      const r = K.rng(3902);
      for (let i = 0; i < 14; i++) {
        const side = i % 2 ? 1 : -1, x = side < 0 ? 40 + r() * 240 : 1000 + r() * 240, y = 620 + r() * 80, ls = 14 + r() * 10;
        c.save(); c.translate(x, y); c.rotate(Math.sin(t * 1.3 + i) * 0.1);
        c.fillStyle = i % 3 ? '#6FA046' : '#7FB252';
        c.beginPath(); c.ellipse(0, -ls * 0.5, ls * 0.8, ls * 0.5, 0, 0, TAU); c.fill();
        c.restore();
      }
    });
    K.par(c, 1.08, () => K.dust(c, t, 3903, 30, '#FFF0D8', 0.35, -100, W + 100, 200, 650, 3));
  },
};

window.STORY_SCENES = [s1, s2, s3, s4, s5, s6, s7, s8, s9, s10, s11, s12, s13];
})();
