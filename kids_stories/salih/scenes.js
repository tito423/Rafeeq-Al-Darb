// Story 6 - Salih, peace be upon him, and the she-camel. VISUALS ONLY.
// Narration: docs/kids_stories/salih_narration.md (11:61-68, 26:141-158,
// 91:11-15 + al-Muyassar). Salih is NEVER drawn - only a warm light. Thamud are
// flat featureless figures. The hamstringing is NOT drawn: the scene darkens
// and the camel fades away. The end shows empty houses only.
'use strict';
(() => {
const { W, H } = K;
const TAU = Math.PI * 2;
const E = K.easeInOut, B = K.beat, A = K.after;
const DOORS = [[260, 470], [420, 440], [600, 455], [790, 430], [960, 460], [1120, 445]];
// a cliff with houses carved into the rock («وتنحتون من الجبال بيوتًا»)
const cliff = (c, light, carve = 1, lit = 0) => {
  c.fillStyle = K.tone('#B98A64', light);
  c.beginPath(); c.moveTo(-420, 560);
  for (let x = -420; x <= W + 420; x += 20) c.lineTo(x, 300 + 40 * Math.sin(x * 0.006) + 18 * Math.sin(x * 0.021));
  c.lineTo(W + 420, 560); c.closePath(); c.fill();
  c.fillStyle = K.tone('#A0744F', light);
  for (let x = -400; x < W + 400; x += 90) c.fillRect(x, 330 + 30 * Math.sin(x * 0.01), 6, 200);
  DOORS.forEach(([x, y], i) => {
    const k = K.clamp(carve * DOORS.length - i);
    if (k <= 0) return;
    c.save(); c.globalAlpha *= k;
    c.fillStyle = K.tone('#D8B08A', light); c.fillRect(x - 40, y - 70, 80, 110);
    c.beginPath(); c.moveTo(x - 48, y - 70); c.lineTo(x, y - 100); c.lineTo(x + 48, y - 70); c.fill();
    c.fillStyle = lit > 0 ? K.mix('#3A2418', '#FFC869', lit) : '#3A2418';
    c.beginPath(); c.moveTo(x - 16, y + 40); c.lineTo(x - 16, y - 10); c.arc(x, y - 10, 16, Math.PI, 0); c.lineTo(x + 16, y + 40); c.fill();
    c.restore();
  });
};
const oasis = (c, t, light, o = {}) => {
  KIT.sky(c, t, light, { sun: o.sun || [1080, 150], cols: o.cols });
  K.par(c, 0.5, () => cliff(c, light, o.carve ?? 1, o.lit || 0));
  K.par(c, 0.85, () => {
    KIT.ground(c, 540, light, '#C9B47A');
    // a spring with palms and green fields
    c.fillStyle = K.tone('#7FB2B8', light); c.beginPath(); c.ellipse(360, 604, 120, 22, 0, 0, TAU); c.fill();
    c.strokeStyle = K.rgba('#E8F6F6', 0.6); c.lineWidth = 2;
    for (let i = 0; i < 3; i++) { const q = K.fract(t * 0.5 + i / 3); c.beginPath(); c.ellipse(360, 604, 120 * q, 22 * q, 0, 0, TAU); c.stroke(); }
    if (!o.bare) for (const [x, h] of [[540, 170], [830, 190], [150, 150], [1110, 160]]) KIT.palm(c, x, 600, h, light, t, x);
    if (!o.bare) for (const [x, s] of [[320, 1.2], [960, 1.1], [520, 0.9]]) K.shrub(c, x, 640, s, K.tone('#7E9A55', light));
  });
};
const camel = (c, x, y, s, t, o = {}) => {
  c.save(); c.globalAlpha *= o.alpha ?? 1;
  K.animal(c, 'camel', x, y, s, o.walk ? t * 3 : 0, o.ang || 0, 0);
  c.restore();
};

const s1 = { cam: (p) => [K.lerp(1.0, 1.12, E(p)), K.lerp(560, 700, E(p)), K.lerp(370, 410, E(p)), 0], draw(c, t, d, p) {
  const nh = B(1, 'نحت', 6.64);
  oasis(c, t, 0.95, { carve: A(t, nh - 0.5, 2, (x) => x) });
  K.par(c, 0.12, () => K.birds(c, t, 2801, 6, 400, 190, 180, 28, 9, '#4A3A40', 0.6));
  KIT.foreGrass(c, t, 0.95);
} };
const s2 = { cam: (p) => [K.lerp(1.08, 1.18, E(p)), 640, K.lerp(410, 440, E(p)), 0], draw(c, t, d, p) {
  const sl = B(2, 'صالح', 3.28);
  oasis(c, t, 0.94);
  K.par(c, 1, () => { KIT.crowd(c, 2802, 10, 760, 1180, 660, 1.0, t, { face: -1 }); K.presence(c, 520, 630, 28, t, A(t, sl - 0.3, 1)); });
  KIT.foreGrass(c, t, 0.94);
} };
const s3 = { cam: (p) => [K.lerp(1.18, 1.26, E(p)), 620, 450, 0], draw(c, t, d, p) {
  const qr = B(3, 'قريب', 5.6);
  oasis(c, t, 0.94, { cols: undefined });
  K.par(c, 1, () => {
    KIT.crowd(c, 2802, 10, 760, 1180, 660, 1.0, t, { face: -1 });
    K.presence(c, 520, 630, 30 + 10 * A(t, qr - 0.3, 0.8), t, 1);
    K.rays(c, 520, 630, 10, 600, -Math.PI * 0.95, -Math.PI * 0.05, '#FFF0C8', 0.1 * A(t, qr - 0.3, 0.8), t);
  });
  KIT.foreGrass(c, t, 0.94);
} };
const s4 = { cam: (p) => [1.22, K.lerp(820, 760, E(p)), 450, 0], draw(c, t, d, p) {
  const ql = B(4, 'فقالوا', 0.32), at = B(4, 'فأ', 4.24);
  oasis(c, t, 0.92);
  K.par(c, 1, () => {
    KIT.crowd(c, 2802, 10, 760, 1180, 660, 1.0, t, { face: -1, shake: 0.6 * A(t, ql, 0.4), point: A(t, at - 0.2, 0.4) });
    K.presence(c, 520, 630, 28, t, 1);
  });
} };
const s5 = { cam: (p) => [K.lerp(1.2, 1.08, E(p)), 640, K.lerp(450, 420, E(p)), 0], draw(c, t, d, p) {
  const nq = B(5, 'ناقة', 2.0), al = B(5, 'علامة', 3.2);
  oasis(c, t, 0.95);
  K.par(c, 1, () => {
    const show = A(t, nq - 0.4, 1.2);
    K.glow(c, 700, 600, 220, '#FFF0C8', 0.35 * show * (1 - A(t, al + 1.2, 1)));
    camel(c, 700, 640, 1.5, t, { alpha: show });
    K.dust(c, t, 2803, 24, '#FFF4C8', 0.6 * A(t, al - 0.2, 0.6), 560, 860, 460, 660, 2);
    KIT.crowd(c, 2802, 10, 900, 1260, 680, 1.0, t, { face: -1 });
    K.presence(c, 440, 630, 28, t, 1);
  });
} };
const s6 = { // recitation 11:64 - the camel grazes freely on God's earth
  cam: (p) => [K.lerp(1.04, 1.14, E(p)), K.lerp(500, 760, E(p)), 420, 0], draw(c, t, d, p) {
  const tk = B(6, 'تأكل', 18.16);
  oasis(c, t, 0.95);
  K.par(c, 1, () => {
    const x = K.lerp(640, 980, A(t, 6, d - 8, (q) => q));
    const grazing = A(t, tk - 1, 1);
    camel(c, x, 650, 1.4, t, { walk: true, ang: 0.15 * grazing * (0.5 + 0.5 * Math.sin(t * 0.8)) });
    KIT.crowd(c, 2804, 8, 1000, 1300, 690, 0.95, t, { face: -1 });
    K.presence(c, 230, 640, 28, t, 1);
  });
  KIT.foreGrass(c, t, 0.95);
} };
const s7 = { // one day of water for her, one for them
  cam: (p) => [1.12, 640, 440, 0], draw(c, t, d, p) {
  const lk = B(7, 'ولك', 5.6);
  const sw = A(t, lk - 0.5, 1);
  oasis(c, t, 0.95, { sun: [K.lerp(1080, 300, sw), 150] });
  K.par(c, 1, () => {
    camel(c, 470, 618, 1.3, t, { alpha: 1 - sw, ang: 0.3 });
    // the people's day: they come with jars to the water
    c.save(); c.globalAlpha *= sw;
    KIT.crowd(c, 2805, 8, 240, 560, 640, 1.0, t, { face: 1 });
    c.restore();
  });
} };
const s8 = { // they denied him; the most wretched of them hamstrung her - not drawn
  cam: (p) => [K.lerp(1.1, 1.0, E(p)), 640, 420, 0], draw(c, t, d, p) {
  const aq = B(8, 'فعقر', 4.32);
  const dark = A(t, aq - 0.6, 1.2);
  oasis(c, t, K.lerp(0.8, 0.5, dark), { cols: [K.mix('#5DA9D6', '#5A2E3A', dark), K.mix('#A3D2E6', '#A0505A', dark), K.mix('#F4E3C0', '#D08A6A', dark)] });
  K.par(c, 1, () => {
    camel(c, 720, 640, 1.2, t, { alpha: 1 - dark });
    KIT.crowd(c, 2806, 10, 860, 1240, 680, 1.0, t, { face: -1 });
  });
  K.par(c, 0, () => { c.fillStyle = K.rgba('#1A0E18', 0.25 * dark); c.fillRect(-420, -420, W + 840, H + 840); });
} };
const s9 = { // three days in your homes, then the punishment comes
  cam: (p) => [1.04, 640, 400, 0], draw(c, t, d, p) {
  const th = B(9, 'ثلاثة', 4.0);
  // three days and nights pass over the houses (0.6 cycles a second at most)
  const u = A(t, th - 1.2, 4.5, (x) => x) * 3;
  const light = K.smooth(0.5 + 0.9 * Math.sin(K.fract(u + 0.15) * TAU)) * 0.7 + 0.1;
  oasis(c, t, light, { lit: K.clamp(1 - light * 1.6), sun: K.fract(u + 0.15) < 0.5 ? [K.lerp(-60, W + 60, K.fract(u + 0.15) * 2), 200] : [-200, -200] });
  K.par(c, 1, () => K.presence(c, 200, 640, 26, t, 1));
} };
const s10 = { // they became regretful; regret did not help them
  cam: (p) => [K.lerp(1.15, 1.25, E(p)), 760, 460, 0], draw(c, t, d, p) {
  oasis(c, t, 0.55, { cols: ['#3E3A5A', '#8A6A7A', '#C8987A'] });
  K.par(c, 1, () => KIT.crowd(c, 2807, 10, 620, 1100, 668, 1.0, t, { face: -1 }));
} };
const s11 = { // God saved Salih and those who believed with him
  cam: (p) => [K.lerp(1.1, 1.0, E(p)), K.lerp(640, 420, E(p)), 420, 0], draw(c, t, d, p) {
  const nj = B(11, 'أنج', 2.96);
  const go = A(t, nj - 0.5, d - nj + 0.5, (x) => x);
  oasis(c, t, 0.7, { cols: ['#4E5A7A', '#B08A8A', '#E8C09A'] });
  K.par(c, 1, () => {
    KIT.crowd(c, 2808, 6, 500, 760, 650, 1.0, t, { face: -1, walk: 1, shift: -520 * go });
    K.presence(c, K.lerp(440, -60, go), 620, 28, t, 1);
  });
} };
const s12 = { // the blast took the wrongdoers; their homes stood empty
  cam: (p, t, d) => { const sy = B(12, 'الصيحة', 1.28); return [K.lerp(1.02, 1.1, E(p)), 640, 410, Math.sin(t * 30) * 0.004 * A(t, sy, 0.1) * (1 - A(t, sy + 0.8, 0.6))]; },
  draw(c, t, d, p) {
  const sy = B(12, 'الصيحة', 1.28), kh = B(12, 'خال', 4.72);
  oasis(c, t, 0.6, { cols: ['#4A4A62', '#9A8A8A', '#D8B898'], bare: t > kh - 0.5 });
  K.par(c, 1, () => {
    const q = K.clamp((t - sy) / 1.6);
    if (q > 0 && q < 1) { c.strokeStyle = K.rgba('#FFFFFF', 0.6 * (1 - q)); c.lineWidth = 6; c.beginPath(); c.arc(640, 300, 80 + q * 900, 0, TAU); c.stroke(); }
    K.dust(c, t, 2809, 50, '#E8D8C0', 0.5 * A(t, sy, 0.5), -100, W + 100, 300, 720, 30);
  });
} };
const s13 = { cam: (p) => [K.lerp(1.1, 1.02, E(p)), 640, K.lerp(390, 362, E(p)), 0], draw(c, t, d, p) {
  KIT.lesson(c, t, p, { seed: 2810 });
} };
window.STORY_SCENES = [s1, s2, s3, s4, s5, s6, s7, s8, s9, s10, s11, s12, s13];
})();
