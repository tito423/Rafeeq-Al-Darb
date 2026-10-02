// Ibrahim and Isma'il, peace be upon them, and the ransom. VISUALS ONLY.
// Narration: docs/kids_stories/dhabih_narration.md (37:99-113 + al-Muyassar).
// Both are NEVER drawn - lights (Isma'il smaller). NO knife and no slaughter
// are drawn or shown: the submission is two still lights on a rock under a
// light from the sky; the ram is drawn standing, alive.
'use strict';
(() => {
const { W, H } = K;
const TAU = Math.PI * 2;
const E = K.easeInOut, B = K.beat, A = K.after;
const hills = (c, t, light, o = {}) => {
  KIT.sky(c, t, light, { sun: o.sun, moon: o.moon, cols: o.cols, seed: 181 });
  K.par(c, 0.35, () => { K.ridge(c, 420, 70, 18.1, 0.9, K.tone('#8A7262', light)); K.haze(c, 320, 500, '#F2D8B8', 0.2); });
  K.par(c, 0.8, () => {
    KIT.ground(c, 560, light, '#C2A87A');
    if (o.rock) { c.fillStyle = K.tone('#8A7A6A', light); c.beginPath(); c.moveTo(520, 640); c.quadraticCurveTo(540, 560, 640, 556); c.quadraticCurveTo(740, 560, 760, 640); c.fill(); }
    for (const [x, s] of [[200, 1.0], [1060, 1.1]]) K.shrub(c, x, 640, s, K.tone('#7E9A55', light));
  });
};
const ram = (c, x, y, s, t, a = 1) => {
  if (a <= 0.01) return;
  c.save(); c.globalAlpha *= a;
  K.animal(c, 'sheep', x, y, s, 0, 0);
  c.strokeStyle = '#A8885A'; c.lineWidth = 4 * s; c.beginPath(); c.arc(x + 28 * s, y - 40 * s, 9 * s, -Math.PI * 0.2, Math.PI * 1.3); c.stroke(); // a curled horn
  c.restore();
};

const S = [];
S.push({ // 1 Ibrahim prayed: my Lord, grant me a righteous child
  cam: (p) => [K.lerp(1.0, 1.1, E(p)), 640, 440, 0], draw(c, t, d) {
  hills(c, t, 0.35, { moon: [1040, 140] });
  K.par(c, 1, () => { K.presence(c, 640, 620, 28, t, 1); K.rays(c, 640, 610, 7, 560, -Math.PI * 0.62, -Math.PI * 0.38, '#FFE6B0', 0.1, t); });
} });
S.push({ // 2 Allah answered and gave him glad news of a forbearing boy - Isma'il
  cam: (p) => [K.lerp(1.1, 1.0, E(p)), 640, 440, 0], draw(c, t, d) {
  const gl = B(2, 'بغلامٍ', d * 0.6);
  hills(c, t, 0.85, { sun: [1060, 180] });
  K.par(c, 1, () => { K.presence(c, 600, 620, 28, t, 1); K.presence(c, 680, 628, 14, t, A(t, gl - 0.3, 1.2)); });
} });
S.push({ // 3 when he was old enough to walk with him: I see in a dream that I sacrifice you - what do you think?
  cam: (p) => [1.04, K.lerp(420, 700, E(p)), 450, 0], draw(c, t, d) {
  hills(c, t, 0.85, { sun: [1080, 220] });
  K.par(c, 1, () => { const k = A(t, 0, d, (x) => x); K.presence(c, 360 + 320 * k, 620, 28, t, 1); K.presence(c, 430 + 320 * k, 630, 16, t, 1); });
} });
S.push({ // 4 the dreams of prophets are true - a command from Allah
  cam: (p) => [K.lerp(1.0, 1.1, E(p)), 640, K.lerp(400, 340, E(p)), 0], draw(c, t, d) {
  hills(c, t, 0.25, { moon: [1040, 140] });
  K.par(c, 0.2, () => K.glow(c, 640, 180, 200, '#FFF6DA', 0.2 * A(t, d * 0.3, 1.5)));
  K.par(c, 1, () => { K.presence(c, 600, 620, 26, t, 1); K.presence(c, 680, 628, 15, t, 1); });
} });
S.push({ // 5 Isma'il, dutiful: father, do what Allah commands; you will find me patient, Allah willing
  cam: (p) => [K.lerp(1.2, 1.3, E(p)), 660, 540, 0], draw(c, t, d) {
  const sb = B(5, 'صابرًا', d * 0.85);
  hills(c, t, 0.8, { sun: [1080, 240] });
  K.par(c, 1, () => { K.presence(c, 600, 620, 26, t, 1); K.presence(c, 680, 628, 15 + 4 * A(t, sb - 0.4, 1), t, 1); K.glow(c, 640, 620, 140, '#FFE6A8', 0.2 * A(t, sb - 0.4, 1)); });
} });
S.push({ // 6 when both submitted, Allah called: Ibrahim, you have fulfilled the dream - two still lights on a rock, light from the sky
  cam: (p) => [K.lerp(1.0, 1.12, E(p)), 640, 460, 0], draw(c, t, d) {
  const nd = B(6, 'ناداهُ', d * 0.4);
  hills(c, t, 0.7, { sun: [1100, 300], rock: true });
  K.par(c, 1, () => {
    K.presence(c, 600, 545, 24, t, 1); K.presence(c, 670, 550, 14, t, 1);
    const k = A(t, nd - 0.5, 1.4);
    K.rays(c, 640, -40, 9, 760, Math.PI * 0.4, Math.PI * 0.6, '#FFF6DA', 0.16 * k, t);
    K.glow(c, 640, 540, 180, '#FFFFFF', 0.25 * k);
  });
} });
S.push({ // 7 this was a great trial that showed the truth of his faith
  cam: (p) => [K.lerp(1.1, 1.0, E(p)), 640, 420, 0], draw(c, t, d) {
  hills(c, t, 0.8, { sun: [1080, 220], rock: true });
  K.par(c, 1, () => { K.presence(c, 600, 545, 26, t, 1); K.presence(c, 670, 550, 15, t, 1); K.rays(c, 630, 540, 10, 600, -Math.PI * 0.9, -Math.PI * 0.1, '#FFF0C8', 0.1, t); });
} });
S.push({ // 8 Allah saved Isma'il and put a great ram in his place - alive, standing
  cam: (p) => [K.lerp(1.2, 1.1, E(p)), 700, 520, 0], draw(c, t, d) {
  const kb = B(8, 'كبشًا', d * 0.75);
  hills(c, t, 0.9, { sun: [1060, 180], rock: true });
  K.par(c, 1, () => { K.presence(c, 560, 600, 26, t, 1); K.presence(c, 620, 610, 16, t, 1); ram(c, 800, 600, 1.4, t, A(t, kb - 0.6, 1)); K.glow(c, 800, 570, 90, '#FFF6DA', 0.25 * A(t, kb - 0.6, 1)); });
} });
S.push({ // 9 recitation 37:107 - the ram standing in the evening light
  cam: (p) => [K.lerp(1.05, 1.12, E(p)), 700, 480, 0], draw(c, t, d, p) {
  hills(c, t, K.lerp(0.85, 0.5, E(p)), { sun: [K.lerp(1060, 1140, E(p)), K.lerp(200, 380, E(p))], rock: true });
  K.par(c, 1, () => { K.presence(c, 560, 600, 26, t, 1); K.presence(c, 620, 610, 16, t, 1); ram(c, 800, 600, 1.4, t); });
} });
S.push({ // 10 so Allah rewards the doers of good, rescuing them from hardship
  cam: (p) => [K.lerp(1.0, 1.08, E(p)), 640, 420, 0], draw(c, t, d, p) {
  const l = K.lerp(0.5, 0.95, E(p));
  hills(c, t, l, { sun: [1000, K.lerp(420, 180, E(p))], cols: KIT.skyAt(l) });
  K.par(c, 1, () => { K.presence(c, 600, 620, 28, t, 1); K.presence(c, 680, 628, 16, t, 1); });
  K.par(c, 0.12, () => K.birds(c, t, 18102, 6, 400, 170, 160, 26, 9, '#4A3A40', 0.6 * E(p)));
} });
S.push({ // 11 a good name for Ibrahim among later nations; peace be upon Ibrahim
  cam: (p) => [1.0, 640, K.lerp(420, 340, E(p)), 0], draw(c, t, d) {
  hills(c, t, 0.9, { sun: [1060, 160] });
  K.par(c, 0.6, () => { for (let i = 0; i < 6; i++) { const q = K.fract(t * 0.12 + i / 6); K.glow(c, 200 + i * 180, 520 - q * 300, 14, '#FFF0C8', 0.45 * Math.sin(q * Math.PI)); } });
  K.par(c, 1, () => K.presence(c, 640, 620, 28, t, 1));
} });
S.push({ // 12 glad news of Ishaq, a prophet among the righteous; blessing on them both
  cam: (p) => [K.lerp(1.1, 1.0, E(p)), 640, 440, 0], draw(c, t, d) {
  const is = B(12, 'إسحاقَ', d * 0.4);
  hills(c, t, 0.9, { sun: [1060, 180] });
  K.par(c, 1, () => { K.presence(c, 560, 620, 28, t, 1); K.presence(c, 640, 628, 16, t, 1); K.presence(c, 720, 628, 13, t, A(t, is - 0.3, 1.2)); K.glow(c, 640, 600, 260, '#FFE6A8', 0.15 * A(t, d * 0.6, 1)); });
} });
S.push({ // 13 that ram became an offering and a Sunnah until the Day of Judgement - Eid al-Adha morning: a town, people, a sheep standing (no slaughter)
  cam: (p) => [K.lerp(1.0, 1.08, E(p)), 640, 440, 0], draw(c, t, d) {
  KIT.sky(c, t, 0.95, { sun: [1000, 170], seed: 182 });
  KIT.land(c, 0.95, { seed: 18.2, farCol: '#B0A08E', midCol: '#A8A070' });
  KIT.town(c, 0.95, 0, { seed: 18201, n: 22, ty: 545 });
  K.par(c, 1, () => {
    KIT.crowd(c, 18202, 10, 160, 560, 665, 1.0, t, { face: 1, robes: ['#E8E0D0', '#D8D0C0', '#C8D8E0'] });
    for (const [x, ph] of [[760, 0], [860, 1], [960, 2]]) K.animal(c, 'sheep', x, 650, 0.9, 0, 0);
    K.glow(c, 640, 560, 300, '#FFE6A8', 0.12);
  });
  K.par(c, 0.12, () => K.birds(c, t, 18203, 7, 400, 170, 200, 26, 9, '#4A3A40', 0.6));
} });
S.push({ cam: (p) => [K.lerp(1.1, 1.02, E(p)), 640, K.lerp(390, 362, E(p)), 0], draw(c, t, d, p) {
  KIT.lesson(c, t, p, { seed: 18103 });
} });
window.STORY_SCENES = S;
})();
