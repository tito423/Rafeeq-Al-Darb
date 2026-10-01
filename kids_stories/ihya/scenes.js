// Two signs of giving life: the man and the ruined town (2:259) and Ibrahim
// and the birds (2:260). VISUALS ONLY.
// Narration: docs/kids_stories/ihya_narration.md (+ al-Muyassar). Ibrahim is
// NEVER drawn; the man of 2:259 is not drawn (caution: said to be a prophet) -
// both lights. NO bones and no cut birds on screen: the donkey rises whole
// from a gathering shadow; the birds are feathers on four peaks that gather
// into whole birds and fly to the light.
'use strict';
(() => {
const { W, H } = K;
const TAU = Math.PI * 2;
const E = K.easeInOut, B = K.beat, A = K.after;
const ruin = (c, t, light, g = 0, o = {}) => {
  KIT.sky(c, t, light, { sun: o.sun, moon: o.moon, cols: o.cols, seed: 191 });
  KIT.land(c, light, { seed: 19.1, farCol: '#A89A8A', midCol: K.mix('#A89878', '#94A872', g) });
  K.par(c, 0.8, () => {
    KIT.ground(c, 540, light, K.mix('#B8A880', '#A9BC7C', g));
    // fallen walls: low broken blocks
    const r = K.rng(19101);
    for (let i = 0; i < 9; i++) { const x = 80 + i * 130 + r() * 40, h = 20 + r() * 50; c.fillStyle = K.tone('#C8A880', light); c.fillRect(x, 600 - h, 70, h); c.fillStyle = K.tone('#A8885E', light); c.fillRect(x + 50, 600 - h, 20, h); c.save(); c.translate(x + 90, 604); c.rotate(-0.3); c.fillStyle = K.tone('#B8986E', light); c.fillRect(0, -10, 50, 10); c.restore(); }
    if (g > 0.05) for (const [x, s] of [[150, 1], [420, 0.9], [760, 1.1], [1100, 1]]) K.shrub(c, x, 640, s * g, K.tone('#7E9A55', light));
  });
};
const donkey = (c, x, y, s, a = 1) => { // drawn whole only
  if (a <= 0.01) return;
  c.save(); c.globalAlpha *= a; c.translate(x, y); c.scale(s, s);
  const col = '#8A8078', dark = '#5A524C';
  c.strokeStyle = dark; c.lineWidth = 6; c.lineCap = 'round';
  for (const lx of [-22, -10, 16, 28]) { c.beginPath(); c.moveTo(lx, -30); c.lineTo(lx, 0); c.stroke(); }
  c.fillStyle = col; c.beginPath(); c.ellipse(0, -40, 36, 16, 0, 0, TAU); c.fill();
  c.strokeStyle = col; c.lineWidth = 14; c.beginPath(); c.moveTo(26, -46); c.lineTo(42, -66); c.stroke();
  c.beginPath(); c.ellipse(50, -66, 15, 9, 0.5, 0, TAU); c.fill();
  c.fillStyle = col; c.beginPath(); c.ellipse(40, -86, 4, 12, -0.2, 0, TAU); c.ellipse(48, -86, 4, 12, 0.2, 0, TAU); c.fill();
  c.fillStyle = '#2A2420'; c.beginPath(); c.arc(52, -69, 2, 0, TAU); c.fill();
  c.restore();
};
const peaks = (c, t, light) => {
  K.par(c, 0.6, () => { for (const [x, h] of [[200, 260], [520, 320], [820, 300], [1110, 270]]) { c.fillStyle = K.tone('#8A7A6A', light); c.beginPath(); c.moveTo(x - 150, 560); for (let u = 0; u <= 1; u += 0.05) c.lineTo(x - 150 + u * 300, 560 - h * Math.sin(u * Math.PI) ** 1.4 + 10 * Math.sin(u * 20 + x)); c.closePath(); c.fill(); } });
};
const PEAK = [[200, 300], [520, 240], [820, 260], [1110, 290]];
const bird = (c, x, y, s, t, col) => { const f = Math.sin(t * 12); c.fillStyle = col; c.beginPath(); c.ellipse(x, y, 12 * s, 7 * s, 0, 0, TAU); c.fill(); c.beginPath(); c.arc(x + 10 * s, y - 5 * s, 5 * s, 0, TAU); c.fill(); c.beginPath(); c.moveTo(x - 4 * s, y - 3 * s); c.quadraticCurveTo(x - 10 * s, y - 20 * s * f - 4, x - 20 * s, y - 14 * s * f); c.lineTo(x + 3 * s, y - 2 * s); c.fill(); };

const S = [];
S.push({ // 1 a man passed a town whose houses had fallen: how will Allah give this life after its death?
  cam: (p) => [1.04, K.lerp(420, 760, E(p)), 440, 0], draw(c, t, d) {
  ruin(c, t, 0.8, 0, { sun: [1080, 240] });
  K.par(c, 1, () => { K.presence(c, 260 + 360 * A(t, 0, d * 0.7), 620, 22, t, 1); donkey(c, 160 + 360 * A(t, 0, d * 0.7), 650, 0.9); });
  K.par(c, 1.08, () => K.dust(c, t, 19102, 30, '#E8D3B0', 0.3, -100, W + 100, 480, 720, 14));
} });
S.push({ // 2 Allah caused him to die for a hundred years, then raised him: how long? a day or part of a day - told gently: the light dims, a hundred years pass, the light returns
  cam: (p) => [1.0, 640, 420, 0], draw(c, t, d) {
  const u = A(t, d * 0.15, d * 0.55, (x) => x), g = u;
  const ph = K.fract(u * 8), light = 0.3 + 0.55 * K.smooth(0.5 + Math.sin(ph * TAU) * 0.8);
  ruin(c, t, light, g, { sun: ph < 0.5 ? [K.lerp(-60, W + 60, ph * 2), 220] : [-200, -200], moon: ph >= 0.5 ? [K.lerp(-60, W + 60, ph * 2 - 1), 180] : null });
  K.par(c, 0.8, () => { for (const [x, hh] of [[300, 1], [980, 0.8]]) KIT.palm(c, x, 600, 40 + 140 * g * hh, light, t, x); });
  K.par(c, 1, () => K.presence(c, 640, 630, 20, t, 0.25 + 0.75 * A(t, d * 0.75, 1)));
} });
S.push({ // 3 you stayed a hundred years: look at your food and drink - unchanged
  cam: (p) => [K.lerp(1.3, 1.4, E(p)), 700, 580, 0], draw(c, t, d) {
  ruin(c, t, 0.9, 1, { sun: [1060, 180] });
  K.par(c, 1, () => {
    K.presence(c, 600, 630, 22, t, 1);
    c.fillStyle = '#C8A06A'; c.beginPath(); c.ellipse(720, 650, 34, 9, 0, 0, TAU); c.fill();
    for (let i = 0; i < 5; i++) { c.fillStyle = ['#E0A030', '#8A3E22', '#C8553D'][i % 3]; c.beginPath(); c.arc(700 + i * 10, 642, 6, 0, TAU); c.fill(); }
    c.fillStyle = '#9A7A5A'; c.beginPath(); c.ellipse(780, 640, 14, 20, 0, 0, TAU); c.fill(); c.fillRect(774, 614, 12, 10);
    K.glow(c, 745, 640, 70, '#FFF6DA', 0.3 * A(t, d * 0.4, 1));
  });
} });
S.push({ // 4 look at your donkey, how Allah gives it life - a gathering shadow, the donkey rises whole
  cam: (p) => [K.lerp(1.2, 1.3, E(p)), 780, 560, 0], draw(c, t, d) {
  const hm = B(4, 'حمارِهِ', d * 0.4);
  ruin(c, t, 0.9, 1, { sun: [1060, 180] });
  K.par(c, 1, () => {
    K.presence(c, 600, 630, 22, t, 1);
    const k = A(t, hm, d * 0.5);
    K.glow(c, 820, 640, 90 * (1 - k) + 20, '#3A3028', 0.5 * (1 - k));
    K.dust(c, t, 19103, 30, '#FFF0C8', 0.6 * Math.sin(k * Math.PI), 760, 880, 560, 660, 1);
    donkey(c, 820, 660, 1.1, K.smooth(k));
  });
} });
S.push({ // 5 seeing it with his own eyes: I know Allah has power over all things
  cam: (p) => [K.lerp(1.1, 1.0, E(p)), 700, 460, 0], draw(c, t, d) {
  ruin(c, t, 0.95, 1, { sun: [1060, 160] });
  K.par(c, 1, () => { K.presence(c, 600, 630, 26, t, 1); donkey(c, 820, 660, 1.1); K.rays(c, 600, 620, 10, 640, -Math.PI * 0.9, -Math.PI * 0.1, '#FFF0C8', 0.12 * A(t, d * 0.3, 1), t); });
} });
S.push({ // 6 Ibrahim asked his Lord to show him how He gives life to the dead, to increase certainty
  cam: (p) => [K.lerp(1.0, 1.08, E(p)), 640, 420, 0], draw(c, t, d) {
  KIT.sky(c, t, 0.3, { moon: [1040, 140], seed: 192 });
  peaks(c, t, 0.35);
  K.par(c, 0.8, () => KIT.ground(c, 560, 0.35, '#A8987A'));
  K.par(c, 1, () => { K.presence(c, 640, 630, 28, t, 1); K.rays(c, 640, 620, 7, 560, -Math.PI * 0.62, -Math.PI * 0.38, '#FFE6B0', 0.1, t); });
} });
S.push({ // 7 recitation 2:260 - four peaks under the stars
  cam: (p) => [K.lerp(1.0, 1.06, E(p)), 640, K.lerp(420, 360, E(p)), 0], draw(c, t, d) {
  KIT.sky(c, t, 0.25, { moon: [1040, 140], seed: 192 });
  peaks(c, t, 0.3);
  K.par(c, 0.8, () => KIT.ground(c, 560, 0.3, '#A8987A'));
  K.par(c, 1, () => K.presence(c, 640, 630, 26, t, 1));
} });
S.push({ // 8 take four birds; put a part on each mountain; then call them - feathers on the peaks only
  cam: (p) => [1.0, 640, 400, 0], draw(c, t, d) {
  KIT.sky(c, t, 0.85, { sun: [1060, 160], seed: 193 });
  peaks(c, t, 0.85);
  K.par(c, 0.8, () => KIT.ground(c, 560, 0.85, '#B8A880'));
  K.par(c, 0.6, () => PEAK.forEach(([x, y], i) => { const k = A(t, d * (0.2 + i * 0.12), 0.8); const r = K.rng(19104 + i); for (let j = 0; j < 7; j++) { c.save(); c.globalAlpha *= k; c.translate(x + (r() - 0.5) * 40, y + (r() - 0.5) * 16); c.rotate(r() * TAU); c.fillStyle = ['#E8E0D0', '#C8A070', '#6A7A8A', '#E0A030'][i]; c.beginPath(); c.ellipse(0, 0, 8, 3, 0, 0, TAU); c.fill(); c.restore(); } }));
  K.par(c, 1, () => K.presence(c, 640, 630, 26, t, 1));
} });
S.push({ // 9 he called: every part returned to its place, and they came to him in haste
  cam: (p) => [K.lerp(1.0, 1.1, E(p)), 640, K.lerp(400, 480, E(p)), 0], draw(c, t, d) {
  const nd = B(9, 'فنادى', d * 0.1);
  KIT.sky(c, t, 0.9, { sun: [1060, 160], seed: 193 });
  peaks(c, t, 0.9);
  K.par(c, 0.8, () => KIT.ground(c, 560, 0.9, '#B8A880'));
  K.par(c, 0.6, () => PEAK.forEach(([x, y], i) => {
    const g = A(t, nd + 0.3 + i * 0.25, 0.9), fl = A(t, nd + 1.8 + i * 0.3, 1.6);
    const r = K.rng(19104 + i);
    if (g < 1) for (let j = 0; j < 7; j++) { c.save(); c.globalAlpha *= 1 - g; c.translate(x + (r() - 0.5) * 40 * (1 - g), y + (r() - 0.5) * 16 * (1 - g)); c.fillStyle = ['#E8E0D0', '#C8A070', '#6A7A8A', '#E0A030'][i]; c.beginPath(); c.ellipse(0, 0, 8, 3, 0, 0, TAU); c.fill(); c.restore(); }
    if (g > 0) { c.save(); c.globalAlpha *= g; bird(c, K.lerp(x, 600 + i * 30, K.easeInOut(fl)), K.lerp(y, 560, K.easeInOut(fl)), 1.4, t + i, ['#E8E0D0', '#C8A070', '#6A7A8A', '#E0A030'][i]); c.restore(); }
  }));
  K.par(c, 1, () => K.presence(c, 640, 630, 26, t, 1));
} });
S.push({ // 10 Allah is Mighty, nothing overcomes Him; Wise in all He does
  cam: (p) => [K.lerp(1.1, 1.0, E(p)), 640, 440, 0], draw(c, t, d) {
  KIT.sky(c, t, 0.95, { sun: [1060, 160], seed: 193 });
  peaks(c, t, 0.95);
  K.par(c, 0.8, () => KIT.ground(c, 560, 0.95, '#B8A880'));
  K.par(c, 1, () => { K.presence(c, 640, 630, 28, t, 1); ['#E8E0D0', '#C8A070', '#6A7A8A', '#E0A030'].forEach((col, i) => bird(c, 640 + Math.cos(t * 0.8 + i * TAU / 4) * 90, 540 + Math.sin(t * 0.8 + i * TAU / 4) * 30, 1.2, t + i, col)); K.rays(c, 1060, 160, 10, 900, Math.PI * 0.55, Math.PI * 0.95, '#FFF0C8', 0.08, t); });
} });
S.push({ cam: (p) => [K.lerp(1.1, 1.02, E(p)), 640, K.lerp(390, 362, E(p)), 0], draw(c, t, d, p) {
  KIT.lesson(c, t, p, { seed: 19105 });
} });
window.STORY_SCENES = S;
})();
