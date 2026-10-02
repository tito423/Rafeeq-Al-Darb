// Ibrahim's guests and the good news of Ishaq. VISUALS ONLY.
// Narration: docs/kids_stories/dayf_narration.md (11:69-73, 51:24-30 +
// al-Muyassar). Ibrahim is NEVER drawn - a warm light. The angels are NEVER
// drawn, not even «as guests»: three white lights at the tent door. Sara is
// not drawn: the tent screen moving, a soft light behind it. The calf is a
// covered dish - no slaughter.
'use strict';
(() => {
const { W, H } = K;
const TAU = Math.PI * 2;
const E = K.easeInOut, B = K.beat, A = K.after;
const camp = (c, t, light, o = {}) => {
  KIT.sky(c, t, light, { sun: o.sun, moon: o.moon, cols: o.cols, seed: 211 });
  KIT.land(c, light, { seed: 21.1, farCol: '#A8A08A', midCol: '#A49A6A' });
  K.par(c, 0.8, () => {
    KIT.ground(c, 540, light, '#C2B07A');
    // a large tent with a screen (sitr)
    c.fillStyle = K.tone('#8A6A52', light); c.beginPath(); c.moveTo(380, 620); c.lineTo(520, 470); c.lineTo(800, 470); c.lineTo(900, 620); c.fill();
    c.fillStyle = K.tone('#6A4A3A', light); c.fillRect(470, 520, 120, 100);
    c.fillStyle = K.tone('#C8B48A', light); const sw = Math.sin(t * 1.3) * 4 * (o.stir || 0);
    c.beginPath(); c.moveTo(640, 500); c.lineTo(780, 500); c.lineTo(780 + sw, 620); c.lineTo(640 + sw * 0.5, 620); c.fill();
    for (const [x, h, ph] of [[180, 150, 1], [1120, 160, 2]]) KIT.palm(c, x, 610, h, light, t, ph);
  });
};
const guests = (c, t, a = 1, x0 = 300) => { // three white lights - never figures
  if (a <= 0.01) return;
  c.save(); c.globalCompositeOperation = 'lighter';
  for (let i = 0; i < 3; i++) { const x = x0 + i * 46, y = 600 + Math.sin(t * 1.2 + i) * 3; K.glow(c, x, y, 40, '#E8F0FF', 0.25 * a); K.glow(c, x, y, 12, '#FFFFFF', 0.6 * a); }
  c.restore();
};
const sara = (c, t, a = 1) => { c.save(); c.globalCompositeOperation = 'lighter'; K.glow(c, 720, 560, 50, '#FFE6C0', 0.22 * a); K.glow(c, 720, 560, 16, '#FFF8EC', 0.4 * a); c.restore(); };
const dish = (c, x, y, a = 1) => { if (a <= 0.01) return; c.save(); c.globalAlpha *= a; c.fillStyle = '#B8904A'; c.beginPath(); c.ellipse(x, y, 46, 10, 0, 0, TAU); c.fill(); c.fillStyle = '#D8C8A8'; c.beginPath(); c.arc(x, y - 4, 36, Math.PI, TAU); c.fill(); c.fillStyle = '#8A6A3C'; c.beginPath(); c.arc(x, y - 40, 5, 0, TAU); c.fill(); c.restore(); };

const S = [];
S.push({ // 1 guests came to Ibrahim: «Peace» - and he answered «Peace»
  cam: (p) => [K.lerp(1.0, 1.12, E(p)), 520, 480, 0], draw(c, t, d) {
  const sl = B(1, 'سلامٌ', d * 0.85);
  camp(c, t, 0.9, { sun: [1080, 180] });
  K.par(c, 1, () => { guests(c, t, A(t, 0.2, 1.2), K.lerp(140, 300, A(t, 0.2, d * 0.5))); K.presence(c, 560, 615, 26, t, 1); K.glow(c, 450, 600, 160, '#FFF0C8', 0.15 * A(t, sl - 0.3, 1)); });
} });
S.push({ // 2 he did not know they were noble angels
  cam: (p) => [K.lerp(1.2, 1.3, E(p)), 460, 540, 0], draw(c, t, d) {
  camp(c, t, 0.9, { sun: [1080, 180] });
  K.par(c, 1, () => { guests(c, t, 1); K.presence(c, 560, 615, 26, t, 1); });
} });
S.push({ // 3 he hurried to his family and brought a fat roasted calf, offering it gently: will you not eat?
  cam: (p) => [K.lerp(1.1, 1.2, E(p)), 480, 520, 0], draw(c, t, d) {
  const ij = B(3, 'بعجلٍ', d * 0.45);
  camp(c, t, 0.9, { sun: [1080, 200] });
  K.par(c, 1, () => { guests(c, t, 1); const k = A(t, ij - 0.6, 1.4); K.presence(c, K.lerp(620, 470, k), 615, 26, t, 1); dish(c, K.lerp(600, 430, k), 640, A(t, ij - 0.6, 0.6)); });
} });
S.push({ // 4 seeing them not eat, he felt fear of them
  cam: (p) => [K.lerp(1.25, 1.35, E(p)), 440, 560, 0], draw(c, t, d) {
  camp(c, t, 0.8, { sun: [1100, 280] });
  K.par(c, 1, () => { guests(c, t, 1); dish(c, 430, 640); K.presence(c, 500, 615, 22 + Math.sin(t * 6) * 1.5 * A(t, d * 0.3, 0.6), t, 1); });
} });
S.push({ // 5 do not fear - we are your Lord's angels, sent to the people of Lut
  cam: (p) => [K.lerp(1.3, 1.15, E(p)), 460, 520, 0], draw(c, t, d) {
  camp(c, t, 0.8, { sun: [1100, 280] });
  K.par(c, 1, () => { guests(c, t, 1 + 0.6 * A(t, d * 0.2, 1)); dish(c, 430, 640); K.presence(c, 520, 615, 26, t, 1); K.rays(c, 346, 600, 8, 520, -Math.PI * 0.8, -Math.PI * 0.2, '#E8F0FF', 0.1 * A(t, d * 0.2, 1), t); });
} });
S.push({ // 6 Sara behind the screen heard; good news of Ishaq, and after him Ya'qub
  cam: (p) => [K.lerp(1.1, 1.25, E(p)), 640, 520, 0], draw(c, t, d) {
  const is = B(6, 'إسحاقُ', d * 0.6), yq = B(6, 'يعقوبُ', d * 0.9);
  camp(c, t, 0.85, { sun: [1100, 260], stir: 1 });
  K.par(c, 1, () => { guests(c, t, 1); K.presence(c, 520, 615, 26, t, 1); sara(c, t); K.presence(c, 760, 470, 10, t, A(t, is - 0.3, 1)); K.presence(c, 800, 440, 8, t, A(t, yq - 0.3, 1)); });
} });
S.push({ // 7 she wondered: a child, when I am old and my husband is old?
  cam: (p) => [K.lerp(1.3, 1.4, E(p)), 720, 540, 0], draw(c, t, d) {
  camp(c, t, 0.85, { sun: [1100, 260], stir: 2 });
  K.par(c, 1, () => { sara(c, t, 1 + 0.4 * Math.sin(t * 4) * A(t, d * 0.2, 0.6)); });
} });
S.push({ // 8 do you wonder at Allah's command? His mercy and blessings upon you, people of the house
  cam: (p) => [K.lerp(1.1, 1.0, E(p)), 560, 460, 0], draw(c, t, d) {
  const rh = B(8, 'رحمةُ', d * 0.4);
  camp(c, t, 0.9, { sun: [1080, 220] });
  K.par(c, 1, () => { guests(c, t, 1); K.presence(c, 520, 615, 26, t, 1); sara(c, t); K.glow(c, 600, 540, 320, '#FFE6A8', 0.18 * A(t, rh - 0.3, 1.2)); K.rays(c, 600, 480, 12, 700, -Math.PI * 0.95, -Math.PI * 0.05, '#FFF0C8', 0.1 * A(t, rh - 0.3, 1.2), t); });
} });
S.push({ // 9 recitation 11:73 - the tent in warm evening light
  cam: (p) => [K.lerp(1.0, 1.06, E(p)), 640, K.lerp(450, 400, E(p)), 0], draw(c, t, d, p) {
  camp(c, t, K.lerp(0.85, 0.5, E(p)), { sun: [K.lerp(1080, 1160, E(p)), K.lerp(240, 420, E(p))] });
  K.par(c, 1, () => { K.presence(c, 520, 615, 26, t, 1); sara(c, t); K.glow(c, 640, 560, 260, '#FFD58A', 0.15); });
} });
S.push({ // 10 thus said your Lord; He is able, the Wise, the Knowing
  cam: (p) => [1.0, 640, K.lerp(400, 330, E(p)), 0], draw(c, t, d) {
  camp(c, t, 0.3, { moon: [1040, 140] });
  K.par(c, 0.1, () => K.stars(c, 21102, 160, 0.9, t, 500));
  K.par(c, 1, () => { K.presence(c, 520, 615, 24, t, 1); sara(c, t); });
} });
S.push({ // 11 the boy would be one of knowledge of Allah
  cam: (p) => [K.lerp(1.0, 1.1, E(p)), 640, 440, 0], draw(c, t, d) {
  camp(c, t, 0.9, { sun: [1060, 170] });
  K.par(c, 1, () => { K.presence(c, 560, 615, 26, t, 1); K.presence(c, 640, 625, 12, t, A(t, d * 0.2, 1)); K.rays(c, 640, 615, 8, 400, -Math.PI * 0.75, -Math.PI * 0.25, '#FFF0C8', 0.1 * A(t, d * 0.4, 1), t); });
} });
S.push({ cam: (p) => [K.lerp(1.1, 1.02, E(p)), 640, K.lerp(390, 362, E(p)), 0], draw(c, t, d, p) {
  KIT.lesson(c, t, p, { seed: 21103 });
} });
window.STORY_SCENES = S;
})();
