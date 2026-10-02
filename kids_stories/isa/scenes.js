// 'Isa, peace be upon him, and his mother Maryam. VISUALS ONLY.
// Narration: docs/kids_stories/isa_narration.md (19:16-34, 3:45-49, 5:110 +
// al-Muyassar). 'Isa is NEVER drawn - a small light in the cradle, then a
// light. Maryam is not drawn (caution): a soft light. Jibril is NEVER drawn -
// a light coming down onto the screened place, no human form. No sick or dead
// person is drawn: healing is light spreading, flowers opening.
'use strict';
(() => {
const { W, H } = K;
const TAU = Math.PI * 2;
const E = K.easeInOut, B = K.beat, A = K.after;
const MARYAM = '#FFE6C0';
const land = (c, t, light, o = {}) => {
  KIT.sky(c, t, light, { sun: o.sun, moon: o.moon, cols: o.cols, seed: 121 });
  KIT.land(c, light, { seed: 12.1, farCol: '#B0A090', midCol: '#A89870' });
  K.par(c, 0.8, () => {
    KIT.ground(c, 540, light, '#C9B07A');
    if (o.town) K.town(c, 12102, 16, 700, 1260, 560, 0.9, light, 0);
    if (o.palm) { const x = o.palm; KIT.palm(c, x, 610, 230, light, t, 2, 0.6); }
  });
};
const soft = (c, x, y, r, t, a = 1) => { // Maryam (not drawn): a soft pale light
  if (a <= 0.01) return;
  c.save(); c.globalCompositeOperation = 'lighter';
  K.glow(c, x, y, r * 2.4, MARYAM, 0.18 * a); K.glow(c, x, y, r, '#FFF8EC', 0.5 * a);
  c.restore();
};
const curtain = (c, x, light, t) => {
  c.fillStyle = K.tone('#8A6E8A', light); c.fillRect(x - 6, 430, 6, 190); c.fillRect(x + 200, 430, 6, 190); c.fillRect(x - 10, 426, 220, 8);
  c.fillStyle = K.tone('#C8B4D0', light);
  c.beginPath(); c.moveTo(x, 434); for (let i = 0; i <= 20; i++) c.lineTo(x + i * 10, 434 + 4 * Math.sin(i * 1.3 + t)); c.lineTo(x + 200, 620); for (let i = 20; i >= 0; i--) c.lineTo(x + i * 10, 620 + 3 * Math.sin(i * 1.7 + t * 0.8)); c.fill();
};
const cradle = (c, x, y, t) => { c.save(); c.translate(x, y); c.rotate(Math.sin(t * 1.4) * 0.08); c.fillStyle = '#8A6A4C'; c.beginPath(); c.arc(0, -10, 34, 0, Math.PI); c.fill(); c.fillStyle = '#EADCC4'; c.fillRect(-28, -20, 56, 10); c.restore(); };

const S = [];
S.push({ // 1 Maryam, a righteous woman, chosen above the women of the worlds
  cam: (p) => [K.lerp(1.0, 1.1, E(p)), 640, 420, 0], draw(c, t, d) {
  land(c, t, 0.9, { sun: [1060, 160] });
  K.par(c, 1, () => { soft(c, 560, 600, 30, t); K.rays(c, 560, 590, 9, 600, -Math.PI * 0.85, -Math.PI * 0.15, '#FFF0D8', 0.1 * A(t, d * 0.4, 1.5), t); });
  KIT.foreGrass(c, t, 0.9);
} });
S.push({ // 2 she withdrew from her family to a place toward the east, and set a screen
  cam: (p) => [K.lerp(1.0, 1.15, E(p)), K.lerp(500, 660, E(p)), 470, 0], draw(c, t, d) {
  const st = B(2, 'سِترًا', d * 0.8);
  land(c, t, 0.85, { sun: [1080, 220], town: true });
  K.par(c, 1, () => { soft(c, K.lerp(1000, 640, A(t, 0, d * 0.6)), 600, 26, t); c.save(); c.globalAlpha *= A(t, st - 0.5, 1); curtain(c, 540, 0.85, t); c.restore(); });
} });
S.push({ // 3 Allah sent the angel Jibril to her; she sought refuge in the Most Merciful - light comes down, no form
  cam: (p) => [K.lerp(1.1, 1.2, E(p)), 640, 480, 0], draw(c, t, d) {
  const ns = B(3, 'جبريلَ', d * 0.4), ad = B(3, 'فاستعاذَتْ', d * 0.7);
  land(c, t, 0.75, { sun: [1100, 300] });
  K.par(c, 1, () => {
    curtain(c, 540, 0.75, t);
    const k = A(t, ns - 0.5, 1.4);
    K.rays(c, 760, -40, 7, 760, Math.PI * 0.42, Math.PI * 0.58, '#FFFFFF', 0.14 * k, t);
    K.glow(c, 760, K.lerp(-40, 560, k), 70, '#FFFFFF', 0.35 * k);
    soft(c, K.lerp(640, 600, A(t, ad - 0.3, 0.8)), 600, 26, t);
  });
} });
S.push({ // 4 I am only a messenger of your Lord, to give you a pure boy
  cam: (p) => [K.lerp(1.2, 1.3, E(p)), 660, 520, 0], draw(c, t, d) {
  const gl = B(4, 'بغلامٍ', d * 0.8);
  land(c, t, 0.75, { sun: [1100, 300] });
  K.par(c, 1, () => { curtain(c, 540, 0.75, t); K.glow(c, 760, 560, 70, '#FFFFFF', 0.3); soft(c, 620, 600, 26, t); K.presence(c, 690, 560, 8, t, A(t, gl - 0.3, 1)); });
} });
S.push({ // 5 how, when I have no husband? It is easy for Allah: He says Be, and it is
  cam: (p) => [K.lerp(1.0, 1.1, E(p)), 640, 400, 0], draw(c, t, d) {
  const kn = B(5, 'كُنْ', d * 0.75);
  land(c, t, 0.4, { moon: [1040, 140] });
  K.par(c, 1, () => {
    curtain(c, 540, 0.4, t);
    const q = K.clamp((t - kn) / 1.6);
    if (q > 0 && q < 1) { c.strokeStyle = K.rgba('#FFF6DA', 0.7 * (1 - q)); c.lineWidth = 4; c.beginPath(); c.arc(640, 400, 40 + q * 700, 0, TAU); c.stroke(); }
    K.glow(c, 640, 400, 200, '#FFF6DA', 0.25 * A(t, kn, 0.4) * (1 - A(t, kn + 1, 1.5)));
    soft(c, 620, 600, 24, t);
  });
} });
S.push({ // 6 created without a father, a sign of Allah's power and a mercy
  cam: (p) => [1.0, 640, K.lerp(380, 300, E(p)), 0], draw(c, t, d) {
  land(c, t, 0.15, { moon: [1040, 140] });
  K.par(c, 0.1, () => K.stars(c, 12103, 200, 0.9 * A(t, d * 0.3, 2), t, 600));
  K.par(c, 0.2, () => K.presence(c, 640, 240, 10, t, A(t, d * 0.2, 1.5)));
} });
S.push({ // 7 birth by the trunk of a palm; called: do not grieve, your Lord has put a stream beneath you
  cam: (p) => [K.lerp(1.1, 1.0, E(p)), 640, 460, 0], draw(c, t, d) {
  const jd = B(7, 'جدولَ', d * 0.85);
  land(c, t, 0.7, { sun: [1100, 300], palm: 640 });
  K.par(c, 1, () => {
    soft(c, 600, 610, 22, t); K.presence(c, 625, 625, 8, t, 1);
    const w = A(t, jd - 0.6, 1.4);
    c.fillStyle = K.rgba('#7FC2D0', 0.9 * w); c.beginPath(); c.moveTo(-200, 690);
    for (let x = -200; x <= W + 200; x += 20) c.lineTo(x, 680 + 10 * Math.sin(x * 0.02 + t)); c.lineTo(W + 200, 720); c.lineTo(-200, 720); c.fill();
  });
} });
S.push({ // 8 shake the palm trunk: fresh ripe dates will fall; eat, drink, be glad
  cam: (p) => [K.lerp(1.2, 1.3, E(p)), 660, 430, 0], draw(c, t, d) {
  const hz = B(8, 'وحرِّكي', d * 0.1);
  land(c, t, 0.85, { sun: [1100, 260], palm: 640 });
  K.par(c, 1, () => {
    const r = K.rng(12104);
    for (let i = 0; i < 16; i++) { const q = K.clamp((t - hz - 0.4 - r() * 3) / 0.9); if (q <= 0) continue; const x = 640 + 70 + (r() - 0.5) * 140, y = K.lerp(390, 640 + r() * 20, K.easeIn(Math.min(1, q))); c.fillStyle = '#8A3E22'; c.beginPath(); c.ellipse(x, y, 5, 8, 0.3, 0, TAU); c.fill(); }
    soft(c, 600, 610, 22, t); K.presence(c, 625, 625, 8, t, 1);
    c.fillStyle = '#7FC2D0'; c.fillRect(-200, 680, W + 400, 60);
  });
} });
S.push({ // 9 she came to her people carrying him; they objected; she pointed to him
  cam: (p) => [1.04, K.lerp(560, 760, E(p)), 440, 0], draw(c, t, d) {
  const sh = B(9, 'فأشارَتْ', d * 0.75);
  land(c, t, 0.9, { sun: [1080, 170], town: true });
  K.par(c, 1, () => { KIT.crowd(c, 12105, 12, 760, 1220, 660, 1.0, t, { face: -1, shake: 0.3 * (1 - A(t, sh, 1)) }); soft(c, 560, 610, 24, t); cradle(c, 640, 650, t); K.presence(c, 640, 630, 9, t, 1); K.rays(c, 640, 630, 5, 200, -Math.PI * 0.6, -Math.PI * 0.4, '#FFF0C8', 0.2 * A(t, sh - 0.2, 0.6), t); });
} });
S.push({ // 10 how can we speak to a baby in the cradle? And 'Isa spoke as a nursing baby
  cam: (p) => [K.lerp(1.2, 1.4, E(p)), 660, 560, 0], draw(c, t, d) {
  const tk = B(10, 'فتكلَّمَ', d * 0.65);
  land(c, t, 0.9, { sun: [1080, 170], town: true });
  K.par(c, 1, () => {
    KIT.crowd(c, 12105, 12, 760, 1220, 660, 1.0, t, { face: -1 });
    cradle(c, 640, 650, t); K.presence(c, 640, 630, 9 + 4 * A(t, tk, 0.6), t, 1);
    for (let i = 0; i < 3; i++) { const q = K.fract(t * 0.6 + i / 3) * A(t, tk, 0.4); c.strokeStyle = K.rgba('#FFF6DA', 0.6 * (1 - q) * A(t, tk, 0.4)); c.lineWidth = 2.5; c.beginPath(); c.arc(640, 625, 14 + q * 90, -Math.PI * 0.9, -Math.PI * 0.1); c.stroke(); }
  });
} });
S.push({ // 11 recitation 19:30 - the cradle's light under the evening sky
  cam: (p) => [K.lerp(1.2, 1.05, E(p)), 640, K.lerp(560, 440, E(p)), 0], draw(c, t, d, p) {
  land(c, t, K.lerp(0.75, 0.35, E(p)), { sun: [1100, K.lerp(300, 460, E(p))], town: true });
  K.par(c, 1, () => { cradle(c, 640, 650, t); K.presence(c, 640, 630, 12, t, 1); K.glow(c, 640, 630, 200, '#FFE6A8', 0.12 * E(p)); });
} });
S.push({ // 12 blessed wherever he is; prayer and zakah; dutiful to his mother
  cam: (p) => [K.lerp(1.0, 1.1, E(p)), 640, 440, 0], draw(c, t, d) {
  land(c, t, 0.9, { sun: [1060, 160] });
  K.par(c, 1, () => { K.presence(c, 660, 615, 14, t, 1); soft(c, 600, 610, 22, t); K.rays(c, 640, 600, 9, 600, -Math.PI * 0.85, -Math.PI * 0.15, '#FFF0C8', 0.1, t); });
  KIT.foreGrass(c, t, 0.9);
} });
S.push({ // 13 grown, sent to the Children of Israel; taught the Torah and the Injil - two blank scrolls
  cam: (p) => [K.lerp(1.15, 1.05, E(p)), 640, 480, 0], draw(c, t, d) {
  land(c, t, 0.92, { sun: [1060, 160], town: true });
  K.par(c, 1, () => {
    for (const [x, k] of [[560, A(t, d * 0.4, 1)], [720, A(t, d * 0.6, 1)]]) { c.save(); c.globalAlpha *= k; c.fillStyle = '#EFE3C4'; c.fillRect(x - 40, 560, 80, 30); c.fillStyle = '#B08A5C'; c.beginPath(); c.ellipse(x - 40, 575, 7, 18, 0, 0, TAU); c.ellipse(x + 40, 575, 7, 18, 0, 0, TAU); c.fill(); K.glow(c, x, 575, 60, '#FFF2C8', 0.2); c.restore(); }
    K.presence(c, 640, 620, 26, t, 1);
    KIT.crowd(c, 12106, 8, 820, 1200, 665, 1.0, t, { face: -1 });
  });
} });
S.push({ // 14 from clay the shape of a bird; he breathes into it and it is a bird, by Allah's leave
  cam: (p) => [K.lerp(1.4, 1.1, E(p)), 640, K.lerp(560, 440, E(p)), 0], draw(c, t, d) {
  const tr = B(14, 'طيرًا', d * 0.75, 2);
  land(c, t, 0.92, { sun: [1060, 160] });
  K.par(c, 1, () => {
    K.presence(c, 560, 620, 24, t, 1);
    const k = A(t, tr - 0.3, 1), fx = 660 + 200 * K.easeIn(K.clamp((t - tr) / 2)), fy = 600 - 300 * K.easeIn(K.clamp((t - tr) / 2));
    const f = k > 0.5 ? Math.sin(t * 12) * 0.8 : 0.1;
    c.fillStyle = K.mix('#A88A6A', '#F4F0E8', k);
    c.beginPath(); c.ellipse(fx, fy, 16, 9, 0, 0, TAU); c.fill(); c.beginPath(); c.arc(fx + 14, fy - 6, 6, 0, TAU); c.fill();
    c.beginPath(); c.moveTo(fx - 4, fy - 4); c.quadraticCurveTo(fx - 14, fy - 24 * f - 6, fx - 26, fy - 18 * f); c.lineTo(fx + 4, fy - 2); c.fill();
    c.fillStyle = '#E0A030'; c.beginPath(); c.moveTo(fx + 19, fy - 7); c.lineTo(fx + 26, fy - 5); c.lineTo(fx + 19, fy - 3); c.fill();
  });
} });
S.push({ // 15 he healed the one born blind and the leper, and raised the dead, by Allah's leave - light and flowers only
  cam: (p) => [K.lerp(1.0, 1.08, E(p)), 640, 440, 0], draw(c, t, d) {
  land(c, t, 0.92, { sun: [1060, 160] });
  K.par(c, 1, () => {
    K.presence(c, 640, 615, 26, t, 1);
    const q = A(t, d * 0.15, d * 0.7, (x) => x);
    c.strokeStyle = K.rgba('#FFF6DA', 0.4 * (1 - q)); c.lineWidth = 3; c.beginPath(); c.ellipse(640, 640, 40 + 600 * q, 10 + 120 * q, 0, 0, TAU); c.stroke();
    const r = K.rng(12107);
    for (let i = 0; i < 30; i++) { const x = r() * W, y = 600 + r() * 110, dd = Math.hypot((x - 640) / 600, (y - 640) / 120); const o = K.clamp((q - dd) * 4); if (o <= 0) continue; c.fillStyle = ['#E86A8A', '#F0C040', '#F4F0E8', '#C88AE0'][i % 4]; for (let j = 0; j < 5; j++) { const a = j * TAU / 5; c.beginPath(); c.arc(x + Math.cos(a) * 6 * o, y + Math.sin(a) * 6 * o, 4 * o, 0, TAU); c.fill(); } c.fillStyle = '#FFE070'; c.beginPath(); c.arc(x, y, 3 * o, 0, TAU); c.fill(); }
  });
} });
S.push({ // 16 all that is proof he is Allah's prophet and messenger - and Allah's servant
  cam: (p) => [K.lerp(1.0, 1.1, E(p)), 640, K.lerp(420, 360, E(p)), 0], draw(c, t, d) {
  land(c, t, 0.7, { sun: [1100, 300] });
  K.par(c, 1, () => { K.presence(c, 640, 615, 26, t, 1); K.rays(c, 640, -40, 7, 760, Math.PI * 0.42, Math.PI * 0.58, '#FFF6DA', 0.1, t); });
} });
S.push({ cam: (p) => [K.lerp(1.1, 1.02, E(p)), 640, K.lerp(390, 362, E(p)), 0], draw(c, t, d, p) {
  KIT.lesson(c, t, p, { seed: 12108 });
} });
window.STORY_SCENES = S;
})();
