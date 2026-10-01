// The People of the Elephant (surah 105). VISUALS ONLY.
// Narration: docs/kids_stories/fil_narration.md (105:1-5 + al-Muyassar).
// The army and the elephant are drawn (no prophet in the story); soldiers are
// flat featureless figures. NO ONE is shown being hit: birds and small stones
// cross the sky, then an empty field of dry leaves blowing, and the House far
// off, whole (plain stone, no covering or writing).
'use strict';
(() => {
const { W, H } = K;
const TAU = Math.PI * 2;
const E = K.easeInOut, B = K.beat, A = K.after;
const land = (c, t, light, o = {}) => {
  KIT.sky(c, t, light, { sun: o.sun, cols: o.cols, seed: 111 });
  K.par(c, 0.35, () => { K.ridge(c, 400, 70, 11.1, 0.9, K.tone('#7A6458', light)); K.haze(c, 300, 480, '#F2D8B8', 0.2); });
  K.par(c, 0.55, () => { if (o.house) { const x = o.hx || 1000; c.fillStyle = K.tone('#5E5650', light); c.fillRect(x - 40, 420, 60, 70); c.fillStyle = K.tone('#4A433E', light); c.fillRect(x + 20, 420, 22, 70); } KIT.ground(c, 490, light, '#C9A877'); });
};
const army = (c, t, x0, n, walk, light, o = {}) => {
  K.animal(c, 'elephant', x0 + 260, 640, 1.3, walk ? t * 2 : 0, 0, light < 0.7 ? 0.25 : 0);
  KIT.crowd(c, 11102, n, x0 - 200, x0 + 220, 660, 1.0, t, { face: 1, walk: walk ? 1 : 0, robes: ['#6E4E3A', '#5E5048', '#7A5A44'], ...o });
};
const birdsBig = (c, t, n, k) => {
  if (k <= 0.01) return;
  const r = K.rng(11103);
  for (let i = 0; i < n; i++) {
    const x = K.mod(r() * 1600 - t * (60 + r() * 40) * 1.0, 1700) - 200, y = 90 + r() * 220 + Math.sin(t * 2 + i) * 6, s = 10 + r() * 8, f = Math.sin(t * 10 + i) * 0.8;
    c.strokeStyle = K.rgba('#2E2A30', k); c.lineWidth = 3; c.lineCap = 'round';
    c.beginPath(); c.moveTo(x - s, y - f * s * 0.6); c.quadraticCurveTo(x - s * 0.4, y - s * 0.4, x, y); c.quadraticCurveTo(x + s * 0.4, y - s * 0.4, x + s, y - f * s * 0.6); c.stroke();
  }
};

const S = [];
S.push({ // 1 Abraha came with an army and the elephant, wanting to destroy the Ka'ba
  cam: (p) => [K.lerp(1.0, 1.08, E(p)), K.lerp(500, 700, E(p)), 440, 0], draw(c, t, d) {
  land(c, t, 0.9, { sun: [1080, 160], house: true });
  K.par(c, 1, () => army(c, t, -40 + A(t, 0, d, (x) => x) * 260, 12, true, 0.9));
  K.par(c, 1.08, () => K.dust(c, t, 11104, 40, '#E8D3B0', 0.4, -100, W + 100, 520, 720, 20));
} });
S.push({ // 2 Allah made their plot come to nothing - the elephant will not go on
  cam: (p) => [K.lerp(1.15, 1.25, E(p)), 520, 520, 0], draw(c, t, d) {
  land(c, t, 0.85, { sun: [1080, 200], house: true });
  K.par(c, 1, () => army(c, t, 220, 12, false, 0.85, { point: A(t, d * 0.3, 0.6) * 0.6 }));
} });
S.push({ // 3 Allah sent birds in flocks, one after another
  cam: (p) => [K.lerp(1.0, 1.06, E(p)), 640, K.lerp(420, 340, E(p)), 0], draw(c, t, d) {
  land(c, t, 0.8, { sun: [1080, 200], house: true });
  K.par(c, 0.4, () => birdsBig(c, t, 60, A(t, 0.2, 1.5)));
  K.par(c, 1, () => army(c, t, 220, 12, false, 0.8));
} });
S.push({ // 4 throwing at them stones of hardened clay - small stones in the sky, no one shown hit
  cam: (p) => [1.0, 640, 300, 0], draw(c, t, d) {
  land(c, t, 0.75, { sun: [1080, 220] });
  K.par(c, 0.4, () => {
    birdsBig(c, t, 60, 1);
    const r = K.rng(11105);
    for (let i = 0; i < 50; i++) { const x = r() * W, q = K.fract(t * 0.7 + r()); c.fillStyle = K.rgba('#5A4A3A', 0.8 * (1 - q)); c.beginPath(); c.arc(x + q * 20, 140 + q * 260, 2.5, 0, TAU); c.fill(); }
  });
} });
S.push({ // 5 they became like dry leaves of crops; Allah protected His House - an empty field, the House whole
  cam: (p) => [K.lerp(1.1, 1.0, E(p)), 640, 440, 0], draw(c, t, d) {
  land(c, t, 0.85, { sun: [1080, 180], house: true });
  K.par(c, 1, () => {
    const r = K.rng(11106);
    for (let i = 0; i < 60; i++) { const x = K.mod(r() * 1600 + t * (40 + r() * 60), 1700) - 200, y = 560 + r() * 160 + Math.sin(t * 2 + i) * 6; c.save(); c.translate(x, y); c.rotate(t * 2 + i); c.fillStyle = K.rgba(['#C8A860', '#B8904A', '#D8C080'][i % 3], 0.85); c.beginPath(); c.ellipse(0, 0, 9, 3.5, 0, 0, TAU); c.fill(); c.restore(); }
  });
  K.par(c, 0.55, () => K.glow(c, 1000, 450, 120, '#FFF0C8', 0.25 * A(t, d * 0.5, 1.5)));
} });
S.push({ // 6 Allah is able; He protects His House; the oppressor is weak however strong
  cam: (p) => [K.lerp(1.0, 1.08, E(p)), 900, 400, 0], draw(c, t, d) {
  land(c, t, 0.95, { sun: [1080, 160], house: true });
  K.par(c, 0.55, () => K.rays(c, 1000, 440, 10, 700, -Math.PI * 0.9, -Math.PI * 0.1, '#FFF0C8', 0.1, t));
  K.par(c, 0.12, () => K.birds(c, t, 11107, 6, 400, 170, 160, 26, 9, '#4A3A40', 0.6));
} });
S.push({ // 7 recitation of the whole surah 105 - the valley at dusk, still
  cam: (p) => [K.lerp(1.0, 1.06, E(p)), 640, K.lerp(420, 380, E(p)), 0], draw(c, t, d, p) {
  land(c, t, K.lerp(0.75, 0.45, E(p)), { sun: [K.lerp(1080, 1160, E(p)), K.lerp(200, 400, E(p))], house: true });
  K.par(c, 0.12, () => K.birds(c, t, 11108, 5, 600, 180, 160, 22, 8, '#4A3A40', 0.5));
} });
window.STORY_SCENES = S;
})();
