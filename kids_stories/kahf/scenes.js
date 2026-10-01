// Story - the People of the Cave. VISUALS ONLY.
// Narration: docs/kids_stories/kahf_narration.md (18:9-26 + al-Muyassar).
// The youths are not prophets: flat featureless figures (brief rule 1); their
// number is never made countable on screen (18:22 «my Lord knows best their
// number») - they are shown as an unclear group in shade. The dog is drawn,
// calm, stretched at the entrance. No stoning, no mosque over them.
'use strict';
(() => {
const { W, H } = K;
const TAU = Math.PI * 2;
const E = K.easeInOut, B = K.beat, A = K.after;
const town = (c, t, light, o = {}) => {
  KIT.sky(c, t, light, { sun: o.sun, moon: o.moon, seed: 61 });
  KIT.land(c, light, { seed: 6.1, farCol: '#A8A0A0', midCol: '#B09878' });
  KIT.town(c, light, o.glow || 0, { seed: 6102, n: 26, ty: 545 });
};
// the mountain with the cave mouth at (cx, cy)
const mountain = (c, t, light, o = {}) => {
  KIT.sky(c, t, light, { sun: o.sun, moon: o.moon, cols: o.cols, seed: 62 });
  K.par(c, 0.3, () => { K.ridge(c, 440, 60, 6.3, 0.8, K.tone('#9A9AA8', light)); K.haze(c, 340, 520, '#E8D8C8', 0.25); });
  K.par(c, 0.7, () => {
    // a rugged mountain (irregular crest, not a pyramid)
    const crest = (x) => 640 - 420 * Math.exp(-Math.pow((x - 600) / 380, 2)) + 26 * Math.sin(x * 0.031) + 14 * Math.sin(x * 0.083) + 8 * Math.sin(x * 0.17);
    c.fillStyle = K.tone('#8E7A68', light); c.beginPath(); c.moveTo(-420, 660);
    for (let x = -420; x <= W + 420; x += 10) c.lineTo(x, Math.min(640, crest(x))); c.lineTo(W + 420, 660); c.closePath(); c.fill();
    c.fillStyle = K.tone('#76644F', light); c.beginPath(); c.moveTo(620, 660);
    for (let x = 620; x <= W + 420; x += 10) c.lineTo(x, Math.min(640, crest(x) + 0.16 * (x - 620))); c.lineTo(W + 420, 660); c.closePath(); c.fill();
    c.fillStyle = K.tone('#2A2018', light); c.beginPath(); c.moveTo(560, 600); c.quadraticCurveTo(560, 470, 640, 465); c.quadraticCurveTo(720, 470, 720, 600); c.fill();
    KIT.ground(c, 600, light, '#9A8A6A');
    for (const [x, s] of [[300, 1.1], [980, 1.0], [1120, 0.9]]) K.shrub(c, x, 620, s, K.tone('#6E8A4A', light));
  });
};
// inside the cave, looking out: a dark vault, a bright opening at (ox, oy)
const inside = (c, t, light, o = {}) => {
  K.par(c, 0, () => {
    c.fillStyle = K.tone('#3A3028', light); c.fillRect(-420, -420, W + 840, H + 840);
    const sk = c.createLinearGradient(0, 120, 0, 560); sk.addColorStop(0, K.tone('#8EC3DE', o.sky ?? 1)); sk.addColorStop(1, K.tone('#F2DCB8', o.sky ?? 1));
    c.fillStyle = sk; c.beginPath(); c.moveTo(380, 600); c.quadraticCurveTo(380, 150, 640, 140); c.quadraticCurveTo(900, 150, 900, 600); c.fill();
  });
  K.par(c, 0.9, () => {
    c.fillStyle = K.tone('#4E4236', light); c.fillRect(-420, 580, W + 840, 600);
    c.fillStyle = K.tone('#2E261F', light);
    c.beginPath(); c.moveTo(-420, -420); c.lineTo(-420, 760); c.lineTo(300, 760); c.quadraticCurveTo(250, 300, 420, 60); c.lineTo(860, 60); c.quadraticCurveTo(1030, 300, 980, 760); c.lineTo(W + 420, 760); c.lineTo(W + 420, -420); c.fill();
  });
};
const dog = (c, x, y, s, t, light = 1) => {
  const col = K.tone('#B08A5A', light), dark = K.tone('#7A5A3A', light);
  c.save(); c.translate(x, y); c.scale(s, s);
  c.fillStyle = col;
  c.beginPath(); c.ellipse(0, -14, 34, 13, 0, 0, TAU); c.fill(); // body lying
  c.fillRect(22, -8, 40, 8); // forelegs stretched (18:18)
  c.beginPath(); c.ellipse(34, -30, 13, 11, 0, 0, TAU); c.fill(); // head
  c.beginPath(); c.ellipse(46, -26, 9, 6, 0, 0, TAU); c.fill(); // snout
  c.fillStyle = dark; c.beginPath(); c.moveTo(26, -38); c.lineTo(22, -52); c.lineTo(34, -40); c.fill(); // ear
  c.beginPath(); c.arc(54, -27, 2.5, 0, TAU); c.fill();
  c.strokeStyle = col; c.lineWidth = 5; c.lineCap = 'round';
  c.beginPath(); c.moveTo(-32, -14); c.quadraticCurveTo(-48, -10 + Math.sin(t * 0.8) * 2, -54, -18); c.stroke(); // tail
  c.restore();
};
// sleepers: featureless figures lying in a row in shade; side = 1 / -1 (turned)
// The count must not be readable (18:22): figures overlap, and those at both
// ends fade into the cave's darkness, so the eye cannot tell where the row ends.
const veil = (c, light = 1) => {
  const dark = K.tone('#2E261F', light);
  const g = c.createLinearGradient(0, 0, W, 0);
  g.addColorStop(0, K.rgba(dark, 1)); g.addColorStop(0.3, K.rgba(dark, 1)); g.addColorStop(0.44, K.rgba(dark, 0));
  g.addColorStop(0.56, K.rgba(dark, 0)); g.addColorStop(0.7, K.rgba(dark, 1)); g.addColorStop(1, K.rgba(dark, 1));
  c.fillStyle = g; c.fillRect(-420, 600, W + 840, 300);
  c.fillStyle = dark; c.fillRect(-420, 600, 420, 300); c.fillRect(W, 600, 420, 300);
};
const sleepers = (c, t, side, light = 1, a = 1) => {
  c.save(); c.globalAlpha *= a;
  K.glow(c, 640, 690, 330, '#120E0A', 0.45);
  for (let i = 0; i < 8; i++) {
    const x = 300 + i * 92;
    c.save(); c.translate(x, 690 - (i % 2) * 12); c.rotate(side * Math.PI / 2 * 0.98); c.globalAlpha *= 0.8 - (i % 3) * 0.1;
    K.person(c, 0, 0, 1.05, { robe: K.tone(KIT.ROBES[i % 7], light * 0.7), cloth: K.tone(KIT.CLOTH[i % 4], light * 0.7), dir: 1 });
    c.restore();
  }
  veil(c, light);
  c.restore();
};
const S = [];
S.push({ // 1 youths who believed in their Lord; He increased them in guidance
  cam: (p) => [K.lerp(1.05, 1.15, E(p)), 640, 430, 0], draw(c, t, d) {
  town(c, t, 0.9, { sun: [1080, 160] });
  K.par(c, 1, () => { KIT.crowd(c, 6103, 5, 520, 760, 650, 1.0, t, { face: 1 }); K.rays(c, 640, 600, 8, 500, -Math.PI * 0.8, -Math.PI * 0.2, '#FFF0C8', 0.08 * A(t, d * 0.5, 1.5), t); });
  KIT.foreGrass(c, t, 0.9);
} });
S.push({ // 2 their people worshipped idols and wanted to force them
  cam: (p) => [K.lerp(1.1, 1.0, E(p)), 640, 420, 0], draw(c, t, d) {
  town(c, t, 0.75, { sun: [1100, 240] });
  K.par(c, 1, () => {
    for (const [k, x, h] of [['slab', 860, 150], ['obelisk', 960, 190], ['stepped', 1080, 140]]) K.stone(c, k, x, 640, h, '#9A8A7A', '#B8A898', '#6E6052');
    KIT.crowd(c, 6104, 12, 700, 1200, 660, 1.0, t, { face: -1, point: A(t, d * 0.5, 0.6) });
    KIT.crowd(c, 6103, 5, 240, 420, 655, 1.0, t, { face: 1 });
  });
} });
S.push({ // 3 Allah strengthened their hearts: our Lord is Lord of the heavens and the earth
  cam: (p) => [K.lerp(1.15, 1.25, E(p)), 360, 470, 0], draw(c, t, d) {
  const rb = B(3, 'ربُّ', d * 0.45);
  town(c, t, 0.75, { sun: [1100, 240] });
  K.par(c, 1, () => {
    KIT.crowd(c, 6103, 5, 240, 420, 655, 1.0, t, { face: 1 });
    K.rays(c, 330, 600, 10, 700, -Math.PI * 0.85, -Math.PI * 0.15, '#FFF0C8', 0.12 * A(t, rb - 0.4, 1), t);
    K.glow(c, 330, 600, 200, '#FFE6A8', 0.15 * A(t, rb - 0.4, 1));
  });
} });
S.push({ // 4 they left their people for a cave in the mountain
  cam: (p) => [K.lerp(1.0, 1.1, E(p)), K.lerp(500, 640, E(p)), 430, 0], draw(c, t, d) {
  mountain(c, t, 0.7, { sun: [1100, 260] });
  K.par(c, 1, () => KIT.crowd(c, 6105, 5, 120, 300, 650, 0.9, t, { face: 1, walk: 1, shift: 380 * A(t, 0, d, (x) => x) }));
} });
S.push({ // 5 they prayed for mercy and right guidance - dusk at the cave mouth
  cam: (p) => [K.lerp(1.1, 1.3, E(p)), 640, K.lerp(480, 520, E(p)), 0], draw(c, t, d) {
  mountain(c, t, 0.4, { moon: [1040, 140] });
  K.par(c, 1, () => { KIT.crowd(c, 6106, 5, 580, 700, 612, 0.7, t, { face: -1 }); K.rays(c, 640, 560, 7, 520, -Math.PI * 0.65, -Math.PI * 0.35, '#FFE6B0', 0.08, t); });
} });
S.push({ // 6 recitation 18:10 - the night over the mountain
  cam: (p) => [K.lerp(1.0, 1.08, E(p)), 640, K.lerp(420, 360, E(p)), 0], draw(c, t, d) {
  mountain(c, t, 0.2, { moon: [1040, 140] });
  K.par(c, 0.7, () => { K.glow(c, 640, 540, 90, '#FFC869', 0.18); for (let i = 0; i < 4; i++) { const q = K.fract(t * 0.08 + i / 4); K.glow(c, 640 + Math.sin(i * 2.3 + t * 0.3) * 24, 520 - q * 400, 8, '#FFE9B8', 0.5 * Math.sin(q * Math.PI)); } });
} });
S.push({ // 7 Allah put them into a deep sleep in the cave
  cam: (p) => [K.lerp(1.0, 1.1, E(p)), 640, 430, 0], draw(c, t, d) {
  inside(c, t, 0.6, { sky: 0.3 });
  K.par(c, 1, () => sleepers(c, t, 1, 0.6, A(t, 0.3, 1.5)));
  K.par(c, 0.5, () => K.dust(c, t, 6107, 24, '#FFF0D0', 0.25, 420, 860, 200, 560, 1));
} });
S.push({ // 8 the sun when rising turned away from their cave, and when setting passed them by
  cam: (p) => [1.0, 640, 360, 0], draw(c, t, d, p) {
  const u = A(t, 0.5, d - 1, (x) => x);
  const sx = K.lerp(-60, W + 60, u), sy = 520 - 380 * Math.sin(u * Math.PI);
  mountain(c, t, K.lerp(0.55, 0.95, Math.sin(u * Math.PI)), { sun: [sx, sy] });
  K.par(c, 0.7, () => { // the light passes beside the cave mouth, never into it
    const side = u < 0.5 ? 1 : -1;
    K.rays(c, sx, sy, 6, 900, Math.atan2(470 - sy, 640 + side * 260 - sx) - 0.08, Math.atan2(470 - sy, 640 + side * 260 - sx) + 0.08, '#FFF0C8', 0.1, t);
    K.glow(c, 640, 540, 70, '#1A140E', 0.3);
  });
} });
S.push({ // 9 Allah turned them on their right and left sides
  cam: (p) => [K.lerp(1.2, 1.3, E(p)), 640, 560, 0], draw(c, t, d) {
  const tn = B(9, 'الأيسرِ', d * 0.75);
  inside(c, t, 0.6, { sky: 0.7 });
  K.par(c, 1, () => sleepers(c, t, A(t, tn - 1, 1.2) > 0.5 ? -1 : 1, 0.6));
} });
S.push({ // 10 their dog that accompanied them stretched its forelegs at the entrance
  cam: (p) => [K.lerp(1.3, 1.45, E(p)), 640, 560, 0], draw(c, t, d) {
  inside(c, t, 0.6, { sky: 0.8 });
  K.par(c, 1, () => { sleepers(c, t, 1, 0.6, 0.7); dog(c, 600, 610, 1.3, t, 0.9); });
} });
S.push({ // 11 they slept three hundred years and nine - many days and nights (<= 1.2 cycles/s)
  cam: (p) => [1.0, 640, 380, 0], draw(c, t, d) {
  const u = A(t, 0.8, d - 1.6, (x) => x) * Math.min(1.2 * (d - 1.6), 12);
  const ph = K.fract(u);
  const light = 0.25 + 0.6 * K.smooth(0.5 + Math.sin(ph * TAU) * 0.8);
  mountain(c, t, light, { sun: ph < 0.5 ? [K.lerp(-60, W + 60, ph * 2), 220] : [-200, -200], moon: ph >= 0.5 ? [K.lerp(-60, W + 60, ph * 2 - 1), 180] : null });
  K.par(c, 0.8, () => { // seasons: the shrubs grow and the tree at the mouth thickens
    const g = A(t, 0.8, d - 1.6, (x) => x);
    KIT.palm(c, 860, 610, 60 + 140 * g, light, t, 3);
  });
} });
S.push({ // 12 Allah woke them unchanged: how long did we stay? A day or part of a day
  cam: (p) => [K.lerp(1.2, 1.1, E(p)), 640, 520, 0], draw(c, t, d) {
  const sa = B(12, 'فسألَ', d * 0.4);
  inside(c, t, 0.75, { sky: 1 });
  K.par(c, 1, () => {
    const up = A(t, 0.4, 1.4);
    sleepers(c, t, 1, 0.7, 1 - up);
    c.save(); c.globalAlpha *= up; KIT.crowd(c, 6108, 8, 300, 980, 680, 1.0, t, { face: 1, point: A(t, sa, 0.6) * 0.5 }); veil(c, 0.75); c.restore();
  });
  K.par(c, 0.5, () => K.dust(c, t, 6109, 30, '#FFF0D0', 0.4, 420, 860, 200, 560, 1));
} });
S.push({ // 13 others said: your Lord knows best how long you slept
  cam: (p) => [K.lerp(1.1, 1.0, E(p)), 640, 440, 0], draw(c, t, d) {
  inside(c, t, 0.75, { sky: 1 });
  K.par(c, 1, () => { KIT.crowd(c, 6108, 8, 300, 980, 680, 1.0, t, { face: 1 }); veil(c, 0.75); K.rays(c, 640, 140, 6, 520, Math.PI * 0.35, Math.PI * 0.65, '#FFF6DA', 0.1, t); });
} });
S.push({ // 14 one went with their silver coins to the city, quietly, to buy pure food
  cam: (p) => [K.lerp(1.0, 1.15, E(p)), K.lerp(560, 760, E(p)), 440, 0], draw(c, t, d) {
  const nq = B(14, 'بنقودِهِم', d * 0.35);
  town(c, t, 0.95, { sun: [1080, 160] });
  K.par(c, 1, () => {
    // a market stall
    c.fillStyle = '#8A6A4C'; c.fillRect(860, 560, 220, 70); c.fillStyle = '#C8553D'; c.beginPath(); c.moveTo(840, 560); c.lineTo(1100, 560); c.lineTo(1080, 520); c.lineTo(860, 520); c.fill();
    for (let i = 0; i < 6; i++) { c.fillStyle = ['#E0A030', '#C8A860', '#E8D8B0'][i % 3]; c.beginPath(); c.arc(885 + i * 34, 556, 12, 0, TAU); c.fill(); }
    KIT.crowd(c, 6110, 1, 1110, 1111, 650, 1.0, t, { face: -1 });
    KIT.crowd(c, 6111, 1, 380, 381, 650, 1.0, t, { face: 1, walk: 1, shift: 360 * A(t, 0, d * 0.8, (x) => x) });
    const k = A(t, nq - 0.3, 0.8); // coins glint
    for (let i = 0; i < 3; i++) K.glow(c, 400 + 360 * A(t, 0, d * 0.8, (x) => x) + 12 + i * 5, 610 - i * 3, 8, '#E8E8F0', 0.8 * k);
  });
} });
S.push({ // 15 the seller saw their old coins; their matter was uncovered, people learned the story
  cam: (p) => [K.lerp(1.2, 1.0, E(p)), 900, K.lerp(500, 430, E(p)), 0], draw(c, t, d) {
  const qd = B(15, 'القديمةَ', d * 0.3);
  town(c, t, 0.95, { sun: [1080, 160] });
  K.par(c, 1, () => {
    c.fillStyle = '#8A6A4C'; c.fillRect(860, 560, 220, 70); c.fillStyle = '#C8553D'; c.beginPath(); c.moveTo(840, 560); c.lineTo(1100, 560); c.lineTo(1080, 520); c.lineTo(860, 520); c.fill();
    for (let i = 0; i < 3; i++) K.glow(c, 950 + i * 10, 550, 10, '#E8E8F0', 0.9 * A(t, qd - 0.3, 0.6));
    KIT.crowd(c, 6110, 1, 1110, 1111, 650, 1.0, t, { face: -1, point: A(t, qd, 0.5) });
    KIT.crowd(c, 6111, 1, 760, 761, 650, 1.0, t, { face: 1 });
    KIT.crowd(c, 6112, 14, 300, 700, 665, 1.0, t, { face: 1, appear: A(t, d * 0.5, d * 0.4, (x) => x) });
  });
} });
S.push({ // 16 people knew Allah's promise is true; He raises after death as He woke the youths
  cam: (p) => [K.lerp(1.0, 1.1, E(p)), 640, K.lerp(420, 380, E(p)), 0], draw(c, t, d, p) {
  const l = K.lerp(0.35, 0.95, E(p));
  mountain(c, t, l, { sun: [1000, K.lerp(560, 200, E(p))], cols: KIT.skyAt(l) });
  K.par(c, 0.7, () => K.rays(c, 1000, K.lerp(560, 200, E(p)), 12, 1100, Math.PI * 0.55, Math.PI * 1.0, '#FFF0C8', 0.08 * E(p), t));
} });
S.push({ cam: (p) => [K.lerp(1.1, 1.02, E(p)), 640, K.lerp(390, 362, E(p)), 0], draw(c, t, d, p) {
  KIT.lesson(c, t, p, { seed: 6113 });
} });
window.STORY_SCENES = S;
})();
