// Story - Ayyub, peace be upon him, and patience. VISUALS ONLY.
// Narration: docs/kids_stories/ayyub_narration.md (21:83-84, 38:41-44 +
// al-Muyassar). Ayyub is NEVER drawn - only a warm light (K.presence). His
// family are flat featureless figures. The illness is NOT drawn: it is told by
// what is around him (empty fold, dry land, long nights); the healing by the
// spring and the green coming back. Beats fall back to a fraction of the scene
// (d * f) until words.json exists.
'use strict';
(() => {
const { W, H } = K;
const TAU = Math.PI * 2;
const E = K.easeInOut, B = K.beat, A = K.after;
const GREEN = ['#7E9A55', '#6E8A4A'], DRY = ['#A08A64', '#8E7550'];
// the valley: far ridges, a house with a fold, ground that is green (g=1) or dry (g=0)
const valley = (c, t, light, g, o = {}) => {
  KIT.sky(c, t, light, { sun: o.sun, moon: o.moon, cols: o.cols, seed: 31 });
  KIT.land(c, light, { seed: 2.3, farCol: K.mix('#B49A86', '#9FB08E', g), midCol: K.mix('#B88F68', '#8FA56A', g) });
  K.par(c, 0.8, () => {
    KIT.ground(c, 520, light, K.mix('#C9A877', '#A9BC7C', g));
    K.house(c, 760, 560, 130, 92, K.tone('#E2BC8C', light), K.tone('#B98E64', light), K.tone('#5A3A2A', light), o.glow || 0);
    // the fold: a low fence of posts
    c.strokeStyle = K.tone('#7A5A3E', light); c.lineWidth = 4;
    for (let x = 920; x <= 1160; x += 30) { c.beginPath(); c.moveTo(x, 600); c.lineTo(x, 572); c.stroke(); }
    c.beginPath(); c.moveTo(920, 582); c.lineTo(1160, 582); c.stroke();
    for (const [x, h, ph] of [[640, 170, 1], [1210, 150, 2], [260, 160, 3]]) {
      if (g > 0.05) KIT.palm(c, x, 590, h * (0.75 + 0.25 * g), light, t, ph, g);
      else { c.strokeStyle = K.tone('#6B4A34', light); c.lineWidth = 9; c.beginPath(); c.moveTo(x, 590); c.quadraticCurveTo(x + 4, 590 - h * 0.5, x + 14, 590 - h * 0.62); c.stroke(); }
    }
    for (const [x, s] of [[200, 1.1], [520, 0.9], [1020, 1.0]]) K.shrub(c, x, 640, s * (0.6 + 0.4 * g), K.tone(K.mix(DRY[0], GREEN[0], g), light));
  });
};
// sheep in the fold (n of them, fading with a)
const flock = (c, t, n, a, light, x0 = 940, walk = 0) => {
  if (a <= 0.01) return;
  c.save(); c.globalAlpha *= a;
  for (let i = 0; i < n; i++) K.animal(c, 'sheep', x0 + (i % 4) * 52 + (i > 3 ? 22 : 0), 612 + (i > 3 ? 22 : 0), 0.62, walk ? t * 3 + i : 0, 0, light < 0.7 ? 0.3 : 0);
  c.restore();
};
const night = (light) => (light < 0.5 ? { moon: [1040, 140] } : {});

const s1 = { // a righteous servant: family, children, wealth
  cam: (p) => [K.lerp(1.0, 1.1, E(p)), K.lerp(600, 740, E(p)), 420, 0], draw(c, t, d) {
  const ah = B(1, 'أهلًا', d * 0.55), ml = B(1, 'ومالًا', d * 0.8);
  valley(c, t, 0.95, 1, { sun: [1080, 150] });
  K.par(c, 1, () => {
    K.presence(c, 700, 610, 26, t, 1);
    KIT.crowd(c, 3101, 6, 380, 640, 650, 0.9, t, { face: 1, appear: A(t, ah - 0.4, 1, (x) => x) });
    flock(c, t, 7, A(t, ml - 0.4, 0.8), 0.95);
  });
  K.par(c, 0.12, () => K.birds(c, t, 3102, 5, 400, 170, 160, 26, 9, '#4A3A40', 0.6));
  KIT.foreGrass(c, t, 0.95);
} };
const s2 = { // then the trial: illness, and he lost family, wealth and children
  cam: (p) => [K.lerp(1.1, 1.0, E(p)), 700, 420, 0], draw(c, t, d) {
  const ib = B(2, 'ابتلاه', d * 0.2), fq = B(2, 'وفقد', d * 0.55);
  const dry = A(t, ib, 2.5);
  const gone = A(t, fq - 0.3, 1.8);
  valley(c, t, K.lerp(0.95, 0.62, dry), 1 - dry, { cols: [K.mix('#5DA9D6', '#6E6A86', dry), K.mix('#A3D2E6', '#B49A9A', dry), K.mix('#F4E3C0', '#D8B48E', dry)] });
  K.par(c, 1, () => {
    K.presence(c, 700, 610, 26 - 6 * dry, t, 1 - 0.35 * dry);
    KIT.crowd(c, 3101, 6, 380, 640, 650, 0.9, t, { face: 1, appear: 1 - gone });
    flock(c, t, 7, 1 - gone, 0.8);
  });
  K.par(c, 1.08, () => K.dust(c, t, 3103, 30, '#E8D3B0', 0.35 * dry, -100, W + 100, 420, 720, 18));
} };
const s3 = { // he was patient, content, complained only to his Lord - night, a steady light
  cam: (p) => [K.lerp(1.15, 1.25, E(p)), 700, 480, 0], draw(c, t, d) {
  const sb = B(3, 'فصبر', d * 0.15);
  valley(c, t, 0.32, 0, { ...night(0.32), glow: 0.6 });
  K.par(c, 1, () => {
    K.presence(c, 700, 610, 22 + 6 * A(t, sb, 1.5), t, 0.9);
    K.rays(c, 700, 600, 6, 520, -Math.PI * 0.62, -Math.PI * 0.38, '#FFE6B0', 0.08 * A(t, d * 0.6, 1.5), t);
  });
} };
const s4 = { // days pass and he remains patient: day and night over the dry land (<= 0.6 cycle/s)
  cam: (p) => [1.04, K.lerp(560, 720, E(p)), 410, 0], draw(c, t, d) {
  const u = A(t, 0.6, d - 1.2, (x) => x) * 2.5;
  const ph = K.fract(u + 0.25);
  const light = 0.15 + 0.75 * K.smooth(0.5 + Math.sin(ph * TAU) * 0.9);
  valley(c, t, light, 0, { sun: ph < 0.5 ? [K.lerp(-60, W + 60, ph * 2), 200] : [-200, -200], moon: ph >= 0.5 ? [K.lerp(-60, W + 60, ph * 2 - 1), 170] : null, glow: K.clamp(1 - light * 1.5) });
  K.par(c, 1, () => K.presence(c, 700, 610, 24, t, 1));
} };
const s5 = { // he called his Lord: hardship and pain have touched me, You are the Most Merciful
  cam: (p) => [K.lerp(1.0, 1.18, E(p)), 700, K.lerp(380, 460, E(p)), 0], draw(c, t, d) {
  const ar = B(5, 'أرحمُ', d * 0.75);
  valley(c, t, 0.26, 0, { moon: [1040, 130], glow: 0.7 });
  K.par(c, 1, () => {
    K.presence(c, 700, 610, 26, t, 1);
    K.rays(c, 700, 600, 9, 700, -Math.PI * 0.7, -Math.PI * 0.3, '#FFF0C8', 0.06 + 0.08 * A(t, ar - 0.4, 1.2), t);
  });
  K.par(c, 0.2, () => K.dust(c, t, 3104, 40, '#FFF4D8', 0.5 * A(t, ar - 0.4, 1.2), 400, 1000, 80, 560, 2));
} };
const s6 = { // recitation 21:83 - a still night sky, the light rising
  cam: (p) => [K.lerp(1.0, 1.08, E(p)), 640, K.lerp(420, 330, E(p)), 0], draw(c, t, d, p) {
  valley(c, t, 0.22, 0, { moon: [1040, 130], glow: 0.7 });
  K.par(c, 1, () => {
    K.presence(c, 700, 610, 24, t, 1);
    for (let i = 0; i < 4; i++) { const q = K.fract(t * 0.08 + i / 4); K.glow(c, 700 + Math.sin(i * 2.1 + t * 0.3) * 30, 600 - q * 520, 10, '#FFE9B8', 0.5 * (1 - q) * Math.sin(q * Math.PI)); }
  });
} };
const s7 = { // God answered him: strike the ground with your foot
  cam: (p) => [K.lerp(1.2, 1.32, E(p)), 700, 520, 0], draw(c, t, d) {
  const ad = B(7, 'اضرِبِ', d * 0.72);
  const dawn = A(t, 0, d * 0.6);
  valley(c, t, K.lerp(0.3, 0.6, dawn), 0, { cols: KIT.skyAt(K.lerp(0.3, 0.6, dawn)), glow: 0.4 });
  K.par(c, 1, () => {
    K.presence(c, 700, 610, 24, t, 1);
    const k = K.clamp((t - ad) / 1.2);
    if (k > 0 && k < 1) { c.strokeStyle = K.rgba('#FFF1C8', 0.7 * (1 - k)); c.lineWidth = 3; c.beginPath(); c.ellipse(700, 640, 30 + 160 * k, 8 + 40 * k, 0, 0, TAU); c.stroke(); }
    K.puff(c, 700, 640, K.clamp((t - ad) / 1.0), 1.4);
  });
} };
const s8 = { // a cold spring gushed; he drank and washed, the harm went away - and the land greens
  cam: (p) => [K.lerp(1.25, 1.05, E(p)), 700, K.lerp(500, 430, E(p)), 0], draw(c, t, d) {
  const nb = B(8, 'فنبعَ', d * 0.05), dh = B(8, 'فذهبَ', d * 0.75);
  const flow = A(t, nb, 1.2), green = A(t, dh - 0.6, 2.5);
  valley(c, t, K.lerp(0.62, 0.95, green), green, { sun: [1080, K.lerp(260, 150, green)] });
  K.par(c, 1, () => {
    const r = 40 + 110 * A(t, nb + 0.4, d * 0.6);
    c.fillStyle = K.rgba('#7FC2D0', 0.9 * flow); c.beginPath(); c.ellipse(700, 652, r, r * 0.18, 0, 0, TAU); c.fill();
    c.strokeStyle = K.rgba('#E8F8FA', 0.6 * flow); c.lineWidth = 2;
    for (let i = 0; i < 3; i++) { const q = K.fract(t * 0.6 + i / 3); c.beginPath(); c.ellipse(700, 652, r * q, r * 0.18 * q, 0, 0, TAU); c.stroke(); }
    K.spray(c, t, 3105, 40, 680, 720, 650, 70, '#DFF4F8', 0.9 * flow);
    K.presence(c, 610, 615, 24 + 6 * green, t, 1);
  });
  K.par(c, 1.32, () => K.grass(c, 3106, -380, W + 380, 746, 46 * green, K.tone('#5E7A3A', 0.8), t));
} };
const s9 = { // God returned his family and as many again with them, a mercy
  cam: (p) => [K.lerp(1.05, 1.0, E(p)), K.lerp(560, 660, E(p)), 410, 0], draw(c, t, d) {
  const rd = B(9, 'وردَّ', d * 0.1), mt = B(9, 'مثلَهُم', d * 0.45);
  valley(c, t, 0.97, 1, { sun: [1080, 150] });
  K.par(c, 1, () => {
    K.presence(c, 700, 610, 30, t, 1);
    KIT.crowd(c, 3101, 6, 380, 640, 650, 0.9, t, { face: 1, appear: A(t, rd - 0.2, 1.2, (x) => x) });
    KIT.crowd(c, 3107, 6, 130, 380, 660, 0.9, t, { face: 1, appear: A(t, mt - 0.2, 1.2, (x) => x) });
    flock(c, t, 8, A(t, mt + 0.6, 1), 0.97);
  });
  K.par(c, 0.12, () => K.birds(c, t, 3108, 7, 300, 170, 200, 30, 9, '#4A3A40', 0.6));
  KIT.foreGrass(c, t, 0.97);
} };
const s10 = { // God praised him: We found him patient - what an excellent servant
  cam: (p) => [K.lerp(1.0, 1.15, E(p)), 700, K.lerp(420, 380, E(p)), 0], draw(c, t, d) {
  const ni = B(10, 'نِعمَ', d * 0.75);
  valley(c, t, 1, 1, { sun: [1040, 140] });
  K.par(c, 1, () => {
    K.presence(c, 700, 610, 28 + 8 * A(t, ni - 0.3, 1), t, 1);
    K.rays(c, 1040, 140, 12, 900, Math.PI * 0.55, Math.PI * 0.95, '#FFF1C8', 0.08, t);
  });
  KIT.foreGrass(c, t, 1);
} };
const s11 = { // an example for everyone patient who hopes for his Lord's mercy - a wide green valley
  cam: (p) => [K.lerp(1.12, 1.0, E(p)), 640, K.lerp(440, 400, E(p)), 0], draw(c, t, d) {
  KIT.sky(c, t, 1, { sun: [1040, 140] });
  KIT.land(c, 1, { seed: 2.3, farCol: '#9FB08E', midCol: '#8FA56A' });
  K.par(c, 0.8, () => {
    KIT.ground(c, 520, 1, '#A9BC7C');
    K.town(c, 3109, 14, 120, 1160, 560, 0.7, 1, 0);
    for (const [x, h, ph] of [[180, 150, 1], [480, 170, 2], [900, 160, 3], [1180, 140, 4]]) KIT.palm(c, x, 600, h, 1, t, ph);
  });
  K.par(c, 1, () => K.presence(c, 640, 640, 24, t, 0.9));
  K.par(c, 0.12, () => K.birds(c, t, 3110, 8, 500, 160, 300, 24, 8, '#4A3A40', 0.6));
  KIT.foreGrass(c, t, 1);
} };
const s12 = { cam: (p) => [K.lerp(1.1, 1.02, E(p)), 640, K.lerp(390, 362, E(p)), 0], draw(c, t, d, p) {
  KIT.lesson(c, t, p, { seed: 3111 });
} };
window.STORY_SCENES = [s1, s2, s3, s4, s5, s6, s7, s8, s9, s10, s11, s12];
})();
