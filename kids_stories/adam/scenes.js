// Adam, peace be upon him. VISUALS ONLY.
// Narration: docs/kids_stories/adam_narration.md (2:30-38, 7:19-23,
// 20:115-122 + al-Muyassar). Adam is NEVER drawn - a warm light; Hawwa is not
// drawn (caution) - a soft pale light. Angels are NEVER drawn: a ring of small
// white lights. Iblis is NOT drawn at all, not even as a shadow: his refusal is
// told by the voice only, and the whispering is a cold wind that dims the
// colours. The tree is an ordinary tree with no particular fruit. No nakedness.
'use strict';
(() => {
const { W, H } = K;
const TAU = Math.PI * 2;
const E = K.easeInOut, B = K.beat, A = K.after;
const HAWWA = '#FFE6C0';
const soft = (c, x, y, r, t, a = 1) => { if (a <= 0.01) return; c.save(); c.globalCompositeOperation = 'lighter'; K.glow(c, x, y, r * 2.4, HAWWA, 0.18 * a); K.glow(c, x, y, r, '#FFF8EC', 0.5 * a); c.restore(); };
const heaven = (c, t, k = 1) => {
  K.par(c, 0, () => { K.sky(c, ['#1A2350', '#3A4A8A', '#8A9AD0'], 0, 720); K.stars(c, 161, 160, 0.8, t, 720); K.glow(c, 640, 360, 420, '#FFF6E0', 0.15 * k); });
};
// a ring of small white lights (the angels - never drawn)
const angels = (c, t, cx, cy, R, dip = 0, a = 1) => {
  c.save(); c.globalCompositeOperation = 'lighter';
  for (let i = 0; i < 28; i++) { const ang = i / 28 * TAU + t * 0.05, x = cx + Math.cos(ang) * R, y = cy + Math.sin(ang) * R * 0.32 + dip * 26; K.glow(c, x, y, 14, '#FFFFFF', 0.35 * a); c.fillStyle = K.rgba('#FFFFFF', 0.9 * a); c.beginPath(); c.arc(x, y, 2.4, 0, TAU); c.fill(); }
  c.restore();
};
// the garden: lush, rivers, fruit; dim 0..1 cools it (the whisper / the slip)
const garden = (c, t, light, dim = 0, o = {}) => {
  const cols = [K.mix('#7FC8E8', '#6A7A9A', dim), K.mix('#C8E8E0', '#9AA0B0', dim), K.mix('#F8F0D0', '#C8C0B0', dim)];
  KIT.sky(c, t, light, { sun: o.sun ?? [1060, 150], cols, seed: 162 });
  K.par(c, 0.4, () => { K.ridge(c, 440, 40, 16.2, 0.8, K.tone(K.mix('#8AC08A', '#8A9A8A', dim), light)); K.haze(c, 360, 500, '#F0FAF0', 0.25); });
  K.par(c, 0.8, () => {
    KIT.ground(c, 520, light, K.mix('#8CC070', '#8A9A70', dim));
    c.fillStyle = K.tone(K.mix('#6EC0D8', '#6A8A9A', dim), light); c.beginPath(); c.moveTo(-420, 600); c.quadraticCurveTo(400, 560, 700, 640); c.quadraticCurveTo(1000, 720, W + 420, 660); c.lineTo(W + 420, 700); c.quadraticCurveTo(1000, 760, 700, 680); c.quadraticCurveTo(400, 600, -420, 640); c.fill();
    for (const [x, s, ph] of [[120, 1.1, 1], [300, 0.9, 2], [1000, 1.0, 3], [1180, 1.2, 4]]) {
      c.fillStyle = K.tone('#6B4A34', light); c.fillRect(x - 6, 470, 12, 100 * s);
      c.fillStyle = K.tone(K.mix('#4E9A4A', '#5E7A5A', dim), light); c.beginPath(); c.arc(x, 450, 60 * s, 0, TAU); c.fill();
      if (!o.bare) for (let i = 0; i < 6; i++) { c.fillStyle = ['#E0503A', '#F0B030', '#B04A8A'][i % 3]; c.beginPath(); c.arc(x - 34 * s + (i % 3) * 30 * s, 430 + Math.floor(i / 3) * 34, 6, 0, TAU); c.fill(); }
    }
  });
};
// THE tree: plain, fruit not of any particular kind
const tree = (c, x, light, dim = 0, fruitFall = 0) => {
  c.fillStyle = K.tone('#5A3E2C', light); c.fillRect(x - 10, 450, 20, 160);
  c.fillStyle = K.tone(K.mix('#3E7A4A', '#4A5A4A', dim), light); for (const [dx, dy, r] of [[0, 410, 80], [-60, 440, 50], [60, 440, 54]]) { c.beginPath(); c.arc(x + dx, dy, r, 0, TAU); c.fill(); }
  c.fillStyle = K.tone('#E8C060', light); for (let i = 0; i < 4; i++) { c.beginPath(); c.arc(x - 40 + i * 26, 440 + (i % 2) * 14, 7, 0, TAU); c.fill(); }
  if (fruitFall > 0) { c.beginPath(); c.arc(x + 20, K.lerp(450, 600, K.easeIn(fruitFall)), 7, 0, TAU); c.fill(); }
};
const icons = (c, t, k, hi = -1) => { // the names of things: a tree, a bird, a fish, a mountain, a flower, the moon
  const items = [
    (x, y) => { c.fillStyle = '#4E9A4A'; c.beginPath(); c.arc(x, y - 10, 18, 0, TAU); c.fill(); c.fillStyle = '#6B4A34'; c.fillRect(x - 3, y, 6, 18); },
    (x, y) => { c.fillStyle = '#D8945A'; c.beginPath(); c.ellipse(x, y, 16, 9, 0, 0, TAU); c.fill(); c.beginPath(); c.arc(x + 12, y - 7, 6, 0, TAU); c.fill(); },
    (x, y) => { c.fillStyle = '#6EB0D0'; c.beginPath(); c.ellipse(x, y, 18, 8, 0, 0, TAU); c.fill(); c.beginPath(); c.moveTo(x - 16, y); c.lineTo(x - 28, y - 8); c.lineTo(x - 28, y + 8); c.fill(); },
    (x, y) => { c.fillStyle = '#8A7A6A'; c.beginPath(); c.moveTo(x - 22, y + 14); c.lineTo(x, y - 18); c.lineTo(x + 22, y + 14); c.fill(); },
    (x, y) => { c.fillStyle = '#E86A8A'; for (let j = 0; j < 5; j++) { const a = j * TAU / 5; c.beginPath(); c.arc(x + Math.cos(a) * 8, y + Math.sin(a) * 8, 6, 0, TAU); c.fill(); } c.fillStyle = '#FFE070'; c.beginPath(); c.arc(x, y, 5, 0, TAU); c.fill(); },
    (x, y) => { c.fillStyle = '#FFF4D6'; c.beginPath(); c.arc(x, y, 14, 0, TAU); c.fill(); },
  ];
  items.forEach((f, i) => { const a = i / items.length * TAU - Math.PI / 2, x = 640 + Math.cos(a) * 220, y = 400 + Math.sin(a) * 140; const kk = K.clamp(k * items.length - i); if (kk <= 0) return; c.save(); c.globalAlpha *= kk; if (i === hi) K.glow(c, x, y, 50, '#FFF6DA', 0.6); f(x, y); c.restore(); });
};

const S = [];
S.push({ // 1 Allah told the angels: I will place on earth people succeeding one another
  cam: (p) => [K.lerp(1.0, 1.08, E(p)), 640, K.lerp(360, 400, E(p)), 0], draw(c, t, d) {
  heaven(c, t);
  K.par(c, 0.5, () => { angels(c, t, 640, 260, 420); c.fillStyle = '#3A6A4A'; c.beginPath(); c.arc(640, 1180, 600, 0, TAU); c.fill(); K.glow(c, 640, 620, 300, '#8AC0FF', 0.2); });
} });
S.push({ // 2 the angels asked about the wisdom; I know what you do not know
  cam: (p) => [K.lerp(1.08, 1.0, E(p)), 640, 360, 0], draw(c, t, d) {
  const al = B(2, 'أعلمُ', d * 0.75);
  heaven(c, t, 1 + A(t, al - 0.3, 1));
  K.par(c, 0.5, () => { angels(c, t, 640, 260, 420); K.glow(c, 640, 120, 240, '#FFF6E0', 0.25 * A(t, al - 0.3, 1)); });
} });
S.push({ // 3 He taught Adam the names of all things; showed them to the angels: we know only what You taught us
  cam: (p) => [K.lerp(1.0, 1.06, E(p)), 640, 400, 0], draw(c, t, d) {
  heaven(c, t);
  K.par(c, 0.7, () => { icons(c, t, A(t, 0.3, d * 0.6, (x) => x)); K.presence(c, 640, 400, 28, t, 1); });
  K.par(c, 0.4, () => angels(c, t, 640, 160, 520, 0, 0.7));
} });
S.push({ // 4 Adam told them their names - each lights in turn
  cam: (p) => [K.lerp(1.06, 1.0, E(p)), 640, 400, 0], draw(c, t, d) {
  heaven(c, t);
  K.par(c, 0.7, () => { icons(c, t, 1, Math.floor(A(t, 0.2, d - 0.4, (x) => x) * 5.99)); K.presence(c, 640, 400, 30, t, 1); });
  K.par(c, 0.4, () => angels(c, t, 640, 160, 520, 0, 0.7));
} });
S.push({ // 5 the angels prostrated in honour; Iblis refused out of pride - only the voice tells it
  cam: (p) => [K.lerp(1.0, 1.1, E(p)), 640, 420, 0], draw(c, t, d) {
  const sj = B(5, 'فسجدوا', d * 0.35);
  heaven(c, t);
  K.par(c, 0.6, () => { K.presence(c, 640, 470, 32, t, 1); angels(c, t, 640, 420, 360, A(t, sj - 0.3, 1.2), 1); });
} });
S.push({ // 6 dwell, you and your wife Hawwa, in the Garden; eat freely; do not approach this tree
  cam: (p) => [1.04, K.lerp(500, 760, E(p)), 440, 0], draw(c, t, d) {
  const sh = B(6, 'الشجرةَ', d * 0.85);
  garden(c, t, 0.95);
  K.par(c, 0.8, () => { tree(c, 860, 0.95); K.glow(c, 860, 430, 130, '#FFFFFF', 0.12 * A(t, sh - 0.3, 1)); });
  K.par(c, 1, () => { K.presence(c, 440, 620, 26, t, 1); soft(c, 510, 625, 22, t); });
  K.par(c, 0.12, () => K.birds(c, t, 163, 7, 400, 170, 200, 26, 9, '#4A3A40', 0.6));
} });
S.push({ // 7 there you will not hunger nor be bare, nor thirst nor suffer the sun's heat
  cam: (p) => [K.lerp(1.1, 1.2, E(p)), 400, 520, 0], draw(c, t, d) {
  garden(c, t, 0.95);
  K.par(c, 0.8, () => { K.spray(c, t, 164, 40, 380, 420, 600, 70, '#DFF4F8', 0.9); c.fillStyle = '#6EC0D8'; c.beginPath(); c.ellipse(400, 604, 60, 12, 0, 0, TAU); c.fill(); });
  K.par(c, 1, () => { K.presence(c, 520, 625, 26, t, 1); soft(c, 580, 630, 22, t); });
} });
S.push({ // 8 Allah warned: Iblis is an enemy to you and your wife; let him not drive you out
  cam: (p) => [K.lerp(1.2, 1.1, E(p)), 640, 480, 0], draw(c, t, d) {
  garden(c, t, 0.85, 0.1, { sun: [1100, 260] });
  K.par(c, 0.8, () => tree(c, 860, 0.85, 0.1));
  K.par(c, 1, () => { K.presence(c, 440, 620, 26, t, 1); soft(c, 510, 625, 22, t); K.rays(c, 640, -40, 7, 760, Math.PI * 0.42, Math.PI * 0.58, '#FFF6DA', 0.1, t); });
} });
S.push({ // 9 Satan whispered: shall I show you the tree of everlasting life? He swore he was sincere, and lied - a cold wind only
  cam: (p) => [K.lerp(1.0, 1.08, E(p)), 760, 460, 0], draw(c, t, d) {
  const wind = A(t, d * 0.15, d * 0.5);
  garden(c, t, K.lerp(0.85, 0.7, wind), 0.5 * wind, { sun: [1100, 300] });
  K.par(c, 0.8, () => tree(c, 860, 0.8, 0.5 * wind));
  K.par(c, 1, () => {
    K.presence(c, 600, 620, 24, t, 1); soft(c, 660, 625, 20, t);
    for (let i = 0; i < 9; i++) { const y = 380 + i * 30, q = K.fract(t * 0.4 + i * 0.13); c.strokeStyle = K.rgba('#C8D0E0', 0.3 * wind * Math.sin(q * Math.PI)); c.lineWidth = 2; c.beginPath(); c.moveTo(-200 + q * 1600, y); c.quadraticCurveTo(-120 + q * 1600, y - 14, -40 + q * 1600, y); c.stroke(); }
  });
} });
S.push({ // 10 they ate from the tree; Adam forgot the command
  cam: (p) => [K.lerp(1.15, 1.3, E(p)), 820, 500, 0], draw(c, t, d) {
  const ak = B(10, 'فأكلا', d * 0.2);
  garden(c, t, 0.65, 0.6, { sun: [1120, 340] });
  K.par(c, 0.8, () => tree(c, 860, 0.7, 0.6, A(t, ak, 1.2)));
  K.par(c, 1, () => { K.presence(c, 720, 620, 24, t, 1 - 0.4 * A(t, ak + 1, 1.5)); soft(c, 780, 625, 20, t, 1 - 0.4 * A(t, ak + 1, 1.5)); });
} });
S.push({ // 11 they regretted and called: our Lord, we have wronged ourselves...
  cam: (p) => [K.lerp(1.1, 1.2, E(p)), 640, 480, 0], draw(c, t, d) {
  garden(c, t, 0.4, 0.6, { sun: [1140, 440] });
  K.par(c, 1, () => { K.presence(c, 600, 640, 24, t, 0.75); soft(c, 670, 645, 20, t, 0.75); K.rays(c, 630, 630, 6, 520, -Math.PI * 0.62, -Math.PI * 0.38, '#FFE6B0', 0.08 * A(t, d * 0.4, 1.5), t); });
} });
S.push({ // 12 recitation 7:23 - stillness, the lights rising
  cam: (p) => [K.lerp(1.0, 1.08, E(p)), 640, K.lerp(440, 360, E(p)), 0], draw(c, t, d) {
  garden(c, t, 0.3, 0.5, { sun: [-200, -200] });
  K.par(c, 0.1, () => K.stars(c, 165, 120, 0.7, t, 500));
  K.par(c, 1, () => { K.presence(c, 600, 640, 24, t, 0.8); soft(c, 670, 645, 20, t, 0.8); for (let i = 0; i < 4; i++) { const q = K.fract(t * 0.08 + i / 4); K.glow(c, 635 + Math.sin(i * 2.3 + t * 0.3) * 30, 630 - q * 500, 9, '#FFE9B8', 0.5 * Math.sin(q * Math.PI)); } });
} });
S.push({ // 13 Allah accepted his repentance and forgave him; He is the Accepter of repentance, the Merciful
  cam: (p) => [K.lerp(1.08, 1.0, E(p)), 640, 420, 0], draw(c, t, d, p) {
  const l = K.lerp(0.35, 0.9, E(p));
  garden(c, t, l, K.lerp(0.5, 0, E(p)), { sun: [1000, K.lerp(480, 180, E(p))] });
  K.par(c, 1, () => { K.presence(c, 600, 640, 24 + 6 * E(p), t, 1); soft(c, 670, 645, 20, t); K.glow(c, 640, 600, 300, '#FFE6A8', 0.15 * E(p)); });
} });
S.push({ // 14 then Allah chose him, brought him near, and guided him
  cam: (p) => [K.lerp(1.0, 1.1, E(p)), 640, 440, 0], draw(c, t, d) {
  garden(c, t, 0.95, 0);
  K.par(c, 1, () => { K.presence(c, 600, 640, 32, t, 1); K.rays(c, 600, 630, 12, 700, -Math.PI * 0.95, -Math.PI * 0.05, '#FFF0C8', 0.14, t); soft(c, 680, 645, 20, t); });
} });
S.push({ // 15 sent down to the earth, with a promise of guidance: whoever follows it shall not fear nor grieve
  cam: (p) => [1.0, 640, K.lerp(300, 420, E(p)), 0], draw(c, t, d, p) {
  KIT.sky(c, t, 0.85, { sun: [1060, 160], seed: 166 });
  KIT.land(c, 0.85, { seed: 16.6 });
  K.par(c, 0.8, () => { KIT.ground(c, 540, 0.85, '#B8B07A'); for (const [x, s] of [[200, 1.1], [520, 0.9], [1020, 1.0]]) K.shrub(c, x, 620, s, '#7E9A55'); });
  K.par(c, 1, () => { const y = K.lerp(-60, 620, K.easeOut(A(t, 0.3, d * 0.6))); K.presence(c, 600, y, 26, t, 1); soft(c, 680, y + 6, 20, t); });
} });
S.push({ cam: (p) => [K.lerp(1.1, 1.02, E(p)), 640, K.lerp(390, 362, E(p)), 0], draw(c, t, d, p) {
  KIT.lesson(c, t, p, { seed: 167 });
} });
window.STORY_SCENES = S;
})();
