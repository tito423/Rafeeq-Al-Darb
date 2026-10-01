// Dhul-Qarnayn and the barrier. VISUALS ONLY.
// Narration: docs/kids_stories/dhulqarnayn_narration.md (18:83-98 + al-Muyassar).
// Dhul-Qarnayn is NOT drawn (caution: his prophethood is disputed) - a warm
// light travelling. Peoples and workers are flat featureless figures. Ya'juj
// and Ma'juj are NEVER drawn - dust and shadow beyond the mountains only.
'use strict';
(() => {
const { W, H } = K;
const TAU = Math.PI * 2;
const E = K.easeInOut, B = K.beat, A = K.after;
const road = (c, t, light, o = {}) => {
  KIT.sky(c, t, light, { sun: o.sun, moon: o.moon, cols: o.cols, seed: 131 });
  KIT.land(c, light, { seed: 13.1, farCol: o.far || '#A8A0A0', midCol: o.mid || '#B09878' });
  K.par(c, 0.8, () => { KIT.ground(c, 540, light, o.ground || '#C9B07A'); c.fillStyle = K.rgba('#E8D8B0', 0.5); c.beginPath(); c.moveTo(-420, 700); c.quadraticCurveTo(640, 560, W + 420, 600); c.lineTo(W + 420, 640); c.quadraticCurveTo(640, 600, -420, 760); c.fill(); });
};
// two steep mountains with a gap, and the barrier filling it to fraction h
const pass = (c, t, light, h = 0, o = {}) => {
  KIT.sky(c, t, light, { sun: o.sun, cols: o.cols, seed: 132 });
  K.par(c, 0.6, () => {
    if (o.beyond) { K.dust(c, t, 13101, 50, '#5A4A40', o.beyond, 520, 760, 260, 560, 8); K.glow(c, 640, 420, 140, '#3A2E28', 0.4 * o.beyond); }
    for (const [x0, x1] of [[-420, 560], [720, W + 420]]) {
      c.fillStyle = K.tone('#6E5E52', light); c.beginPath(); c.moveTo(x0, 600);
      for (let x = x0; x <= x1; x += 12) { const edge = Math.min(Math.abs(x - 560), Math.abs(x - 720)); c.lineTo(x, 600 - Math.min(460, 140 + edge * 1.4) + 18 * Math.sin(x * 0.05)); }
      c.lineTo(x1, 600); c.fill();
    }
    if (h > 0) {
      const top = 600 - 430 * h;
      c.fillStyle = K.tone(o.molten ? K.mix('#4A4A52', '#E86A2A', o.molten) : '#4A4A52', light); c.fillRect(556, top, 168, 600 - top);
      c.strokeStyle = K.rgba(o.copper ? '#C87A3A' : '#2E2E36', 0.6); c.lineWidth = 2; for (let y = 600; y > top; y -= 26) { c.beginPath(); c.moveTo(556, y); c.lineTo(724, y); c.stroke(); }
      if (o.copper) { c.fillStyle = K.rgba('#C87A3A', 0.85 * o.copper); c.fillRect(556, top, 168, (600 - top) * o.copper); }
    }
    KIT.ground(c, 600, light, '#9A8A6A');
  });
};

const S = [];
S.push({ // 1 a righteous king, established in the land, given a way to everything
  cam: (p) => [K.lerp(1.0, 1.08, E(p)), 640, 420, 0], draw(c, t, d) {
  road(c, t, 0.95, { sun: [1060, 150] });
  K.par(c, 1, () => { K.presence(c, 640, 620, 28, t, 1); for (let i = 0; i < 5; i++) { const a = -Math.PI * (0.15 + 0.7 * i / 4); c.strokeStyle = K.rgba('#FFF0C8', 0.3 * A(t, d * 0.3 + i * 0.3, 0.8)); c.lineWidth = 3; c.setLineDash([10, 12]); c.beginPath(); c.moveTo(640, 620); c.lineTo(640 + Math.cos(a) * 500, 620 + Math.sin(a) * 160); c.stroke(); } c.setLineDash([]); });
} });
S.push({ // 2 he followed those ways with effort
  cam: (p) => [1.04, K.lerp(400, 880, E(p)), 440, 0], draw(c, t, d) {
  road(c, t, 0.9, { sun: [1080, 180] });
  K.par(c, 1, () => K.presence(c, K.lerp(300, 980, A(t, 0, d, (x) => x)), 610, 26, t, 1));
  K.par(c, 1.08, () => K.dust(c, t, 13102, 30, '#E8D3B0', 0.3, -100, W + 100, 520, 720, 14));
} });
S.push({ // 3 at the setting of the sun: it seemed to set in a dark spring of hot mud; a people there
  cam: (p) => [K.lerp(1.0, 1.1, E(p)), 640, 420, 0], draw(c, t, d, p) {
  const sy = K.lerp(330, 470, E(p));
  KIT.sky(c, t, 0.45, { sun: [640, sy], cols: ['#2F2B5C', '#B05A5A', '#F2A56B'], seed: 133 });
  K.par(c, 0.7, () => { KIT.sea(c, t, 480, 4, 0.5, ['#3A2E2A', '#1E1814']); K.glow(c, 640, 480, 160, '#F2A56B', 0.25); });
  K.par(c, 1, () => { KIT.ground(c, 600, 0.45, '#8A7A5A'); KIT.crowd(c, 13103, 8, 820, 1180, 650, 1.0, t, { face: -1 }); K.presence(c, 300, 620, 26, t, 1); });
} });
S.push({ // 4 he ruled with justice: whoever believed and did good, he treated well and spoke gently
  cam: (p) => [K.lerp(1.15, 1.25, E(p)), 640, 520, 0], draw(c, t, d) {
  KIT.sky(c, t, 0.6, { sun: [1100, 360], cols: ['#3F3B6C', '#C07A6A', '#F2C08B'], seed: 133 });
  K.par(c, 0.7, () => KIT.sea(c, t, 480, 4, 0.6, ['#4A3E3A', '#2E2420']));
  K.par(c, 1, () => { KIT.ground(c, 600, 0.6, '#8A7A5A'); KIT.crowd(c, 13103, 8, 700, 1060, 650, 1.0, t, { face: -1 }); K.presence(c, 520, 620, 26, t, 1); K.glow(c, 700, 610, 220, '#FFE6A8', 0.15 * A(t, d * 0.4, 1)); });
} });
S.push({ // 5 to the rising of the sun: a people with no building and no tree to shade them
  cam: (p) => [K.lerp(1.0, 1.08, E(p)), 640, 420, 0], draw(c, t, d, p) {
  KIT.sky(c, t, 0.9, { sun: [640, K.lerp(470, 300, E(p))], cols: ['#8EC3DE', '#F6D8A8', '#FFE8B8'], seed: 134 });
  K.par(c, 0.5, () => K.ridge(c, 480, 10, 13.4, 0.5, '#E8C898'));
  K.par(c, 1, () => { KIT.ground(c, 560, 1, '#E8C88A'); KIT.crowd(c, 13104, 8, 760, 1160, 640, 1.0, t, { face: -1 }); K.presence(c, 300, 620, 26, t, 1); });
  K.par(c, 1.1, () => { for (let i = 0; i < 6; i++) { const y = 700 - i * 30, ph = t * 2 + i; c.strokeStyle = K.rgba('#FFFFFF', 0.06); c.lineWidth = 2; c.beginPath(); for (let x = -100; x < W + 100; x += 20) c.lineTo(x, y + Math.sin(x * 0.03 + ph) * 3); c.stroke(); } });
} });
S.push({ // 6 between two mountains: a people who could hardly understand speech
  cam: (p) => [K.lerp(1.0, 1.1, E(p)), 640, 440, 0], draw(c, t, d) {
  pass(c, t, 0.85, 0, { sun: [1060, 160] });
  K.par(c, 1, () => { KIT.crowd(c, 13105, 10, 700, 1150, 660, 1.0, t, { face: -1 }); K.presence(c, K.lerp(100, 420, A(t, 0, d * 0.6)), 620, 26, t, 1); });
} });
S.push({ // 7 Ya'juj and Ma'juj spread corruption; shall we pay you to build a barrier? - dust beyond, never them
  cam: (p) => [K.lerp(1.1, 1.0, E(p)), 640, 420, 0], draw(c, t, d) {
  pass(c, t, 0.7, 0, { sun: [1080, 220], beyond: A(t, d * 0.2, 1.5) });
  K.par(c, 1, () => { KIT.crowd(c, 13105, 10, 700, 1150, 660, 1.0, t, { face: -1, point: A(t, d * 0.6, 0.6) * 0.7 }); K.presence(c, 420, 620, 26, t, 1); });
} });
S.push({ // 8 what my Lord gave me is better than your money; help me with strength
  cam: (p) => [K.lerp(1.15, 1.25, E(p)), 520, 520, 0], draw(c, t, d) {
  pass(c, t, 0.8, 0, { sun: [1080, 200] });
  K.par(c, 1, () => { KIT.crowd(c, 13105, 10, 700, 1150, 660, 1.0, t, { face: -1 }); K.presence(c, 420, 620, 28, t, 1); K.rays(c, 420, 610, 7, 520, -Math.PI * 0.62, -Math.PI * 0.38, '#FFF0C8', 0.1, t); });
} });
S.push({ // 9 they brought blocks of iron and set them between the two mountains, level with them
  cam: (p) => [K.lerp(1.0, 1.06, E(p)), 640, 400, 0], draw(c, t, d) {
  const h = A(t, 0.5, d - 1, (x) => x);
  pass(c, t, 0.85, 0.05 + 0.95 * h, { sun: [1080, 180] });
  K.par(c, 1, () => { KIT.crowd(c, 13106, 10, 300, 1000, 665, 1.0, t, { walk: 0.5 }); K.presence(c, 200, 620, 26, t, 1); });
} });
S.push({ // 10 they lit the fire until the iron glowed, then poured copper over it
  cam: (p) => [K.lerp(1.1, 1.2, E(p)), 640, 400, 0], draw(c, t, d) {
  const nh = B(10, 'النحاسَ', d * 0.7);
  const glow = A(t, 0.3, d * 0.4) * (1 - A(t, nh + 0.5, 1.5) * 0.6);
  pass(c, t, 0.6, 1, { cols: ['#3A2E4A', '#8A4A4A', '#E8905A'], molten: glow, copper: A(t, nh - 0.3, 1.6) });
  K.par(c, 0.6, () => { K.glow(c, 640, 420, 260, '#FF8A3A', 0.35 * glow); K.spray(c, t, 13107, 40, 560, 720, 600, 60, '#FFB060', 0.8 * glow); });
  K.par(c, 1, () => K.presence(c, 200, 620, 26, t, 1));
} });
S.push({ // 11 a barrier high and smooth: they could neither climb it nor pierce it
  cam: (p) => [K.lerp(1.0, 1.1, E(p)), 640, K.lerp(420, 360, E(p)), 0], draw(c, t, d) {
  pass(c, t, 0.85, 1, { sun: [1060, 160], copper: 1, beyond: 0.5 });
  K.par(c, 0.6, () => K.rays(c, 1060, 160, 4, 700, Math.PI * 0.7, Math.PI * 0.8, '#FFF0C8', 0.1, t));
} });
S.push({ // 12 he was not proud: this is a mercy from my Lord
  cam: (p) => [K.lerp(1.1, 1.0, E(p)), 640, 440, 0], draw(c, t, d) {
  const rh = B(12, 'رحمةٌ', d * 0.8);
  pass(c, t, 0.9, 1, { sun: [1060, 160], copper: 1 });
  K.par(c, 1, () => { K.presence(c, 640, 640, 26, t, 1); K.rays(c, 640, 630, 9, 600, -Math.PI * 0.85, -Math.PI * 0.15, '#FFF0C8', 0.12 * A(t, rh - 0.4, 1), t); KIT.crowd(c, 13105, 10, 760, 1180, 665, 1.0, t, { face: -1 }); });
} });
S.push({ // 13 recitation 18:98 - the barrier at dusk
  cam: (p) => [K.lerp(1.0, 1.06, E(p)), 640, K.lerp(420, 380, E(p)), 0], draw(c, t, d, p) {
  pass(c, t, K.lerp(0.8, 0.4, E(p)), 1, { sun: [K.lerp(1060, 1160, E(p)), K.lerp(200, 420, E(p))], copper: 1 });
} });
S.push({ cam: (p) => [K.lerp(1.1, 1.02, E(p)), 640, K.lerp(390, 362, E(p)), 0], draw(c, t, d, p) {
  KIT.lesson(c, t, p, { seed: 13108 });
} });
window.STORY_SCENES = S;
})();
