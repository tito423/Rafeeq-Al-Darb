// Musa as a baby in the basket on the Nile. VISUALS ONLY.
// Narration: docs/kids_stories/musa_baby_narration.md (28:7-13 + al-Muyassar).
// Musa is NEVER drawn, even as a baby - a small warm light in the basket. His
// mother, his sister and Pharaoh's wife are not drawn (caution): a light at
// the home, footprints along the bank, a glow at a palace window. Pharaoh's
// servants are flat featureless figures. No killing is drawn or told.
'use strict';
(() => {
const { W, H } = K;
const TAU = Math.PI * 2;
const E = K.easeInOut, B = K.beat, A = K.after;
const nile = (c, t, light, o = {}) => {
  KIT.sky(c, t, light, { sun: o.sun, moon: o.moon, cols: o.cols, seed: 101 });
  K.par(c, 0.3, () => { K.ridge(c, 430, 22, 10.1, 0.6, K.tone('#D8B888', light)); K.haze(c, 340, 470, '#F4DCB8', 0.3); });
  K.par(c, 0.6, () => {
    if (o.palace) { const x = 900; c.fillStyle = K.tone('#E8D2A8', light); c.fillRect(x, 330, 300, 140); c.fillStyle = K.tone('#F2E2C0', light); for (let i = 0; i < 6; i++) c.fillRect(x + 14 + i * 48, 344, 14, 126); c.fillStyle = o.win ? K.mix('#6E5038', '#FFC869', o.win) : K.tone('#6E5038', light); c.fillRect(x + 200, 370, 30, 40); }
    if (o.home) K.house(c, 160, 470, 110, 70, K.tone('#E2BC8C', light), K.tone('#B98E64', light), K.tone('#5A3A2A', light), o.home);
    KIT.ground(c, 460, light, '#B8A870');
  });
  K.par(c, 0.85, () => {
    KIT.sea(c, t, 520, 5, light, ['#4E8EA6', '#2E5E78']);
    // reeds along the near bank
    c.strokeStyle = K.tone('#6E8A4A', light); c.lineWidth = 3;
    for (let x = -300; x < W + 300; x += 26) { const h = 50 + 30 * Math.sin(x * 0.7); c.beginPath(); c.moveTo(x, 700); c.quadraticCurveTo(x + 4 + Math.sin(t + x) * 4, 700 - h * 0.6, x + 8 + Math.sin(t * 1.1 + x) * 6, 700 - h); c.stroke(); }
  });
};
const basket = (c, x, y, t, a = 1) => {
  c.save(); c.globalAlpha *= a; c.translate(x, y + Math.sin(t * 1.6) * 3); c.rotate(Math.sin(t * 1.1) * 0.05);
  c.fillStyle = '#A8824C'; c.beginPath(); c.moveTo(-50, -10); c.lineTo(50, -10); c.lineTo(40, 14); c.lineTo(-40, 14); c.closePath(); c.fill();
  c.strokeStyle = '#7A5A30'; c.lineWidth = 2; for (let i = -40; i <= 40; i += 10) { c.beginPath(); c.moveTo(i, -10); c.lineTo(i * 0.8, 14); c.stroke(); }
  c.fillStyle = '#8A6A3C'; c.fillRect(-52, -16, 104, 7);
  c.restore();
  K.presence(c, x, y - 18 + Math.sin(t * 1.6) * 3, 12, t, a);
};

const S = [];
S.push({ // 1 Musa was born; his mother feared Pharaoh for him
  cam: (p) => [K.lerp(1.1, 1.2, E(p)), 260, 440, 0], draw(c, t, d) {
  nile(c, t, 0.3, { moon: [700, 120], home: 1, palace: true });
  K.par(c, 0.6, () => { K.presence(c, 215, 455, 9, t, 1); K.glow(c, 215, 450, 60, '#FFC869', 0.25); });
} });
S.push({ // 2 Allah inspired her: nurse him calmly; if you fear, put him in a chest and cast it into the Nile
  cam: (p) => [K.lerp(1.2, 1.1, E(p)), 300, 440, 0], draw(c, t, d) {
  const sn = B(2, 'صندوقٍ', d * 0.6);
  nile(c, t, 0.3, { moon: [700, 120], home: 1, palace: true });
  K.par(c, 0.6, () => { K.rays(c, 215, -40, 6, 520, Math.PI * 0.44, Math.PI * 0.56, '#FFF6DA', 0.1, t); K.presence(c, 215, 455, 9, t, 1); });
  K.par(c, 0.85, () => basket(c, 300, 512, t, A(t, sn - 0.3, 1)));
} });
S.push({ // 3 do not fear nor grieve: We will return him to you and make him a messenger
  cam: (p) => [K.lerp(1.0, 1.08, E(p)), 640, K.lerp(380, 320, E(p)), 0], draw(c, t, d) {
  nile(c, t, 0.25, { moon: [700, 120], home: 1, palace: true });
  K.par(c, 0.2, () => K.glow(c, 640, 200, 260, '#FFF0C8', 0.15 * A(t, d * 0.3, 1.5)));
  K.par(c, 0.85, () => basket(c, 330, 512, t));
} });
S.push({ // 4 recitation 28:7 - the basket on the night water, the moon on the river
  cam: (p) => [K.lerp(1.0, 1.1, E(p)), K.lerp(420, 640, E(p)), 420, 0], draw(c, t, d, p) {
  nile(c, t, 0.22, { moon: [760, 120] });
  K.par(c, 0.85, () => { c.fillStyle = K.rgba('#FFF4D6', 0.25); for (let i = 0; i < 8; i++) c.fillRect(730 + Math.sin(t + i) * 10, 530 + i * 18, 60 - i * 5, 3); basket(c, K.lerp(330, 760, E(p)), 512, t); });
} });
S.push({ // 5 she put him in the chest, cast it into the Nile, and told his sister: follow him
  cam: (p) => [K.lerp(1.05, 1.0, E(p)), K.lerp(360, 560, E(p)), 430, 0], draw(c, t, d) {
  nile(c, t, 0.55, { sun: [1100, 330], home: 1 });
  K.par(c, 0.6, () => K.presence(c, 215, 455, 9, t, 1));
  K.par(c, 0.85, () => basket(c, K.lerp(300, 620, A(t, 0, d, (x) => x)), 512, t));
} });
S.push({ // 6 his sister followed from afar - footprints along the bank, unseen by them
  cam: (p) => [1.05, K.lerp(500, 760, E(p)), 440, 0], draw(c, t, d) {
  nile(c, t, 0.85, { sun: [1080, 170], palace: true });
  K.par(c, 0.6, () => { const n = Math.floor(A(t, 0, d, (x) => x) * 14); c.fillStyle = K.rgba('#7A6040', 0.6); for (let i = 0; i < n; i++) { c.beginPath(); c.ellipse(260 + i * 40, 474 + (i % 2) * 6, 6, 3, 0, 0, TAU); c.fill(); } });
  K.par(c, 0.85, () => basket(c, K.lerp(620, 900, A(t, 0, d, (x) => x)), 512, t));
} });
S.push({ // 7 Pharaoh's servants found him and took him
  cam: (p) => [K.lerp(1.0, 1.15, E(p)), 940, 460, 0], draw(c, t, d) {
  const ak = B(7, 'وأخذوهُ', d * 0.6);
  nile(c, t, 0.9, { sun: [1080, 170], palace: true });
  K.par(c, 0.6, () => KIT.crowd(c, 10102, 3, 880, 1040, 470, 0.7, t, { face: -1, point: A(t, d * 0.2, 0.5) }));
  K.par(c, 0.85, () => basket(c, K.lerp(900, 960, A(t, ak - 0.6, 1)), K.lerp(512, 470, A(t, ak - 0.3, 1)), t));
} });
S.push({ // 8 Pharaoh's wife: Allah put love of him in her heart - do not kill him, perhaps we adopt him
  cam: (p) => [K.lerp(1.1, 1.25, E(p)), 1040, 400, 0], draw(c, t, d) {
  const hb = B(8, 'محبَّتَهُ', d * 0.35);
  nile(c, t, 0.85, { sun: [1080, 180], palace: true, win: A(t, hb - 0.3, 1.2) });
  K.par(c, 0.6, () => { K.glow(c, 1115, 390, 90, '#FFC869', 0.3 * A(t, hb - 0.3, 1.2)); K.presence(c, 1060, 455, 10, t, 1); });
} });
S.push({ // 9 his mother's heart was empty of all but him; Allah steadied her and she was patient
  cam: (p) => [K.lerp(1.25, 1.15, E(p)), 230, 440, 0], draw(c, t, d) {
  nile(c, t, 0.45, { sun: [1140, 380], home: 0.6 });
  K.par(c, 0.6, () => { K.glow(c, 215, 450, 80, '#FFC869', 0.2 + 0.15 * A(t, d * 0.5, 1.5)); K.rays(c, 215, 450, 6, 360, -Math.PI * 0.65, -Math.PI * 0.35, '#FFF0C8', 0.1 * A(t, d * 0.5, 1.5), t); });
} });
S.push({ // 10 he would not nurse from any woman they brought - small lights come and go
  cam: (p) => [K.lerp(1.2, 1.3, E(p)), 1060, 420, 0], draw(c, t, d) {
  nile(c, t, 0.85, { sun: [1080, 180], palace: true, win: 0.6 });
  K.par(c, 0.6, () => {
    K.presence(c, 1060, 455, 10, t, 1);
    for (let i = 0; i < 3; i++) { const q = K.clamp((t - i * d / 3) / (d / 3)); const a = Math.sin(q * Math.PI); if (a > 0) KIT.crowd(c, 10103 + i, 1, 980, 981, 470, 0.6, t, { face: 1, appear: a }); }
  });
} });
S.push({ // 11 his sister: shall I show you a household who will raise him well? They agreed
  cam: (p) => [K.lerp(1.0, 1.08, E(p)), K.lerp(900, 640, E(p)), 440, 0], draw(c, t, d) {
  nile(c, t, 0.85, { sun: [1080, 180], palace: true, home: 0.5 });
  K.par(c, 0.6, () => { c.fillStyle = K.rgba('#7A6040', 0.6); for (let i = 0; i < 16; i++) { c.beginPath(); c.ellipse(900 - i * 42, 474 + (i % 2) * 6, 6, 3, 0, 0, TAU); c.fill(); } K.presence(c, 1060, 455, 10, t, 1); });
} });
S.push({ // 12 Allah returned him to his mother, to comfort her eyes - Allah's promise is true
  cam: (p) => [K.lerp(1.2, 1.1, E(p)), 230, 430, 0], draw(c, t, d) {
  const rd = B(12, 'فردَّهُ', d * 0.1);
  nile(c, t, 0.9, { sun: [1080, 170], home: 1 });
  K.par(c, 0.6, () => {
    const k = A(t, rd, 1.6);
    K.presence(c, K.lerp(480, 230, k), 455, 10, t, 1);
    K.glow(c, 215, 450, 140, '#FFC869', 0.3 * k);
    K.rays(c, 215, 450, 10, 520, -Math.PI * 0.95, -Math.PI * 0.05, '#FFF0C8', 0.12 * k, t);
  });
} });
S.push({ cam: (p) => [K.lerp(1.1, 1.02, E(p)), 640, K.lerp(390, 362, E(p)), 0], draw(c, t, d, p) {
  KIT.lesson(c, t, p, { seed: 10104 });
} });
window.STORY_SCENES = S;
})();
