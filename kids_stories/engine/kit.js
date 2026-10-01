// Shared scene pieces for the story files (loaded after lib.js). Same rules:
// deterministic, no human features drawn, prophets only as K.presence light.
'use strict';
(() => {
const { W, H } = K;
const TAU = Math.PI * 2;
const KIT = {};
KIT.SKY = {
  night: ['#0E1534', '#1B2550', '#2E3A66'],
  dusk: ['#2F2B5C', '#9A537A', '#F2A56B'],
  day: ['#5DA9D6', '#A3D2E6', '#F4E3C0'],
};
KIT.skyAt = (light) => {
  const S = KIT.SKY;
  const [a, b, t] = light < 0.5 ? [S.night, S.dusk, light * 2] : [S.dusk, S.day, (light - 0.5) * 2];
  return a.map((c, i) => K.mix(c, b[i], t));
};
KIT.ground = (c, y, light, col = '#D9A86C') => {
  const g = c.createLinearGradient(0, y, 0, H + 60);
  g.addColorStop(0, K.tone(col, light)); g.addColorStop(1, K.tone(K.mix(col, '#8A5A3C', 0.35), light));
  c.fillStyle = g; c.fillRect(-420, y, W + 840, H - y + 420);
};
KIT.palm = (c, x, gy, h, light, t, ph = 0, wind = 1) =>
  K.palm(c, x, gy, h, K.tone('#6B4A34', light), K.tone('#5E7A45', light), wind * (Math.sin(t * 0.9 + ph) + 0.35 * Math.sin(t * 2.3 + ph * 2)));
KIT.ROBES = ['#7A5A48', '#5E6A7A', '#8A6E3E', '#6E4E5A', '#4E6A58', '#8C5A4A', '#6A5E7E'];
KIT.CLOTH = ['#E9DCC4', '#D8CBB0', '#EFE4CC', '#DCCFB8'];
// Sky with sun/moon and drifting clouds, as layer 0.
KIT.sky = (c, t, light, o = {}) => K.par(c, 0, () => {
  K.sky(c, o.cols || KIT.skyAt(light), 0, o.horizon || 480);
  if (light < 0.5) K.stars(c, o.seed || 7, 90, K.clamp(1 - light * 2) * 0.85, t, 380);
  if (o.sun) K.sun(c, o.sun[0], o.sun[1], 34, '#FFF1C4', '#FFC46B', 0.5, o.sunA ?? 1);
  if (o.moon) K.moon(c, o.moon[0], o.moon[1], 28, '#FFF4D6', o.moonA ?? 1);
  if (o.extra) o.extra();
  const cc = o.cloud || K.tone('#FFF8EC', light);
  for (const [x, y, s, v] of [[200, 120, 0.9, 7], [640, 80, 0.7, 5], [1100, 150, 1.0, 6]]) K.cloud(c, K.mod(x + t * v + 200, W + 500) - 250, y, s, cc, o.cloudA ?? 0.85);
});
// Far ridges with haze, then a mid ground: layers 0.3 / 0.55.
KIT.land = (c, light, o = {}) => {
  K.par(c, 0.3, () => { K.ridge(c, o.far || 420, 50, o.seed || 1.7, 0.7, K.tone(o.farCol || '#BFA08E', light)); K.haze(c, (o.far || 420) - 100, (o.far || 420) + 60, o.haze || '#F2DCC0', 0.28); });
  K.par(c, 0.55, () => K.ridge(c, o.mid || 470, 30, (o.seed || 1.7) * 3, 1.1, K.tone(o.midCol || '#C49A72', light)));
};
KIT.town = (c, light, glow, o = {}) => K.par(c, 0.8, () => {
  KIT.ground(c, o.gy || 520, light, o.col);
  K.town(c, o.seed || 147, o.n || 24, o.x0 ?? 120, o.x1 ?? 1160, o.ty || 540, o.scale || 1.05, light, glow);
});
KIT.foreGrass = (c, t, light, y = 746, wind = 1) => K.par(c, 1.32, () => {
  const col = K.tone('#5E6B3A', light * 0.7);
  K.grass(c, 391, -380, 260, y, 46, col, t, wind);
  K.grass(c, 392, 1040, 1680, y, 52, col, t + 0.7, wind);
});
// A group of featureless people. o: face (1/-1), walk 0..1, vx (px/s walking),
// shake, point, appear 0..1 (fade in left to right), shift (px), dir
KIT.crowd = (c, seed, n, x0, x1, gy, s, t, o = {}) => {
  const r = K.rng(seed), list = [];
  for (let i = 0; i < n; i++) list.push({ x: x0 + r() * (x1 - x0), row: r(), k: Math.floor(r() * 7), cl: Math.floor(r() * 4), ph: r() * TAU, d: r() < 0.5 ? 1 : -1 });
  list.sort((a, b) => a.row - b.row);
  for (const p of list) {
    const ss = s * (0.85 + p.row * 0.35), y = gy + p.row * 28 * s;
    const vis = o.appear === undefined ? 1 : K.clamp((o.appear * 1.4 - (p.x - x0) / Math.max(1, x1 - x0) * 0.4) / 0.25);
    if (vis <= 0.01) continue;
    c.save(); c.globalAlpha *= vis;
    K.person(c, p.x + (o.shift || 0), y, ss, {
      phase: t * 5 + p.ph, walk: o.walk || 0, robe: o.robes ? o.robes[p.k % o.robes.length] : KIT.ROBES[p.k],
      cloth: o.cloths ? o.cloths[p.cl % o.cloths.length] : KIT.CLOTH[p.cl], dir: o.face || p.d, shake: o.shake || 0, point: o.point || 0,
    });
    c.restore();
  }
};
// A plain sea from a level down, gently moving.
KIT.sea = (c, t, level, Am, light = 1, cols) => {
  const [a, b] = cols || ['#3F86A2', '#1F4F6A'];
  K.water(c, (x) => level - Am * (Math.sin(x * 0.009 - t * 1.1) + 0.4 * Math.sin(x * 0.021 + t * 1.7)), level - Am - 10, H + 200, K.tone(a, light), K.tone(b, light), K.rgba('#E3F2F4', 0.8), 3);
};
KIT.lesson = (c, t, p, o = {}) => {
  const up = K.easeInOut(K.seg(p, 0, 0.8));
  K.par(c, 0, () => {
    K.sky(c, o.sky || ['#8EC3DE', '#CFE0E2', '#F7D6A8', '#F3B98A'], 0, 470);
    const sy = K.lerp(460, 360, up), sx = o.sunX || 820;
    K.rays(c, sx, sy, 12, 950, Math.PI + 0.2, TAU - 0.2, '#FFF1C8', 0.06, t);
    K.sun(c, sx, sy, 38, '#FFF0C2', '#FFB36B', 0.55);
    for (const [x, y, s, v] of [[250, 120, 0.8, 4], [600, 90, 0.6, 3], [1100, 140, 0.7, 5]]) K.cloud(c, K.mod(x + t * v + 200, W + 500) - 250, y, s, '#FFF3E4', 0.85);
  });
  K.par(c, 0.15, () => K.birds(c, t, o.seed || 4141, 6, 300, 200, 170, 34, 9, '#5A4A50', 0.6));
  K.par(c, 0.45, () => { K.ridge(c, 480, 50, 3.1, 0.8, o.far || '#C8A88E'); K.haze(c, 380, 560, '#FBE6CC', 0.3); });
  if (o.mid) o.mid();
  K.par(c, 1, () => {
    const g = c.createLinearGradient(0, 600, 0, H);
    g.addColorStop(0, o.g1 || '#B9C98A'); g.addColorStop(1, o.g2 || '#A9BC7C');
    c.fillStyle = g; c.fillRect(-420, 600, W + 840, 600);
    for (const [x, s] of [[120, 1.0], [260, 0.8], [1010, 0.9], [1180, 1.1]]) K.shrub(c, x, 604, s, '#86A060');
  });
  K.par(c, 1.08, () => K.dust(c, t, (o.seed || 4141) + 1, 30, '#FFF4D8', 0.4, -100, W + 100, 200, 650, 4));
};
window.KIT = KIT;
})();
