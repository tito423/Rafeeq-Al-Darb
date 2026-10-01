// Shu'ayb, peace be upon him, and the honest measure. VISUALS ONLY.
// Narration: docs/kids_stories/shuayb_narration.md (11:84-94, 7:85,
// 26:181-183 + al-Muyassar). Shu'ayb is NEVER drawn - a warm light. The people
// of Madyan are flat featureless figures in their market. The punishment is
// not drawn: the market stands empty, the scales still there.
'use strict';
(() => {
const { W, H } = K;
const TAU = Math.PI * 2;
const E = K.easeInOut, B = K.beat, A = K.after;
const market = (c, t, light, o = {}) => {
  KIT.sky(c, t, light, { sun: o.sun, moon: o.moon, cols: o.cols, seed: 81 });
  KIT.land(c, light, { seed: 8.1, farCol: '#B4A08E', midCol: '#A89070' });
  KIT.town(c, light, o.glow || 0, { seed: 8102, n: 22, ty: 530 });
  K.par(c, 0.9, () => {
    KIT.ground(c, 580, light, '#C9A877');
    for (const [x, col] of [[200, '#C8553D'], [980, '#3E7A8A']]) {
      c.fillStyle = K.tone('#8A6A4C', light); c.fillRect(x, 560, 200, 60);
      c.fillStyle = K.tone(col, light); c.beginPath(); c.moveTo(x - 20, 560); c.lineTo(x + 220, 560); c.lineTo(x + 200, 520); c.lineTo(x, 520); c.fill();
      for (let i = 0; i < 5; i++) { c.fillStyle = K.tone(['#E0A030', '#C8A860', '#E8D8B0'][i % 3], light); c.beginPath(); c.ellipse(x + 30 + i * 36, 556, 15, 10, 0, 0, TAU); c.fill(); }
    }
  });
};
// a balance at (x, y); tilt > 0 = right pan lower
const scales = (c, x, y, s, tilt, light = 1, a = 1) => {
  if (a <= 0.01) return;
  c.save(); c.globalAlpha *= a; c.translate(x, y); c.scale(s, s);
  const metal = K.tone('#B8903C', light);
  c.strokeStyle = metal; c.fillStyle = metal; c.lineWidth = 5; c.lineCap = 'round';
  c.beginPath(); c.moveTo(0, 0); c.lineTo(0, -120); c.stroke();
  c.fillRect(-30, -4, 60, 8);
  c.save(); c.translate(0, -120); c.rotate(tilt * 0.25);
  c.beginPath(); c.moveTo(-90, 0); c.lineTo(90, 0); c.stroke();
  for (const sx of [-1, 1]) {
    c.save(); c.translate(sx * 90, 0); c.rotate(-tilt * 0.25);
    c.lineWidth = 1.5; c.beginPath(); c.moveTo(0, 0); c.lineTo(-24, 54); c.moveTo(0, 0); c.lineTo(24, 54); c.stroke();
    c.beginPath(); c.ellipse(0, 56, 30, 7, 0, 0, Math.PI); c.fill();
    c.fillStyle = K.tone(sx < 0 ? '#E0A030' : '#C8A860', light); c.beginPath(); c.ellipse(0, 50, 18, 8, 0, Math.PI, TAU); c.fill(); c.fillStyle = metal;
    c.restore();
  }
  c.restore();
  K.glow(c, 0, -120, 30, '#FFF0C8', 0.25);
  c.restore();
};

const S = [];
S.push({ // 1 Allah sent to Madyan their brother Shu'ayb
  cam: (p) => [K.lerp(1.0, 1.1, E(p)), 640, 420, 0], draw(c, t, d) {
  market(c, t, 0.95, { sun: [1080, 150] });
  K.par(c, 1, () => { KIT.crowd(c, 8103, 12, 160, 1180, 660, 1.0, t, {}); K.presence(c, K.lerp(-40, 560, A(t, 0, d * 0.7)), 620, 26, t, 1); });
} });
S.push({ // 2 worship Allah alone, you have no god but Him
  cam: (p) => [K.lerp(1.1, 1.2, E(p)), 560, 480, 0], draw(c, t, d) {
  market(c, t, 0.95, { sun: [1080, 150] });
  K.par(c, 1, () => { KIT.crowd(c, 8103, 12, 160, 1180, 660, 1.0, t, {}); K.presence(c, 560, 620, 28, t, 1); K.rays(c, 560, 610, 9, 600, -Math.PI * 0.85, -Math.PI * 0.15, '#FFF0C8', 0.1 * A(t, d * 0.3, 1), t); });
} });
S.push({ // 3 they gave short measure and weight - the scale is made to lean
  cam: (p) => [K.lerp(1.3, 1.45, E(p)), 640, 520, 0], draw(c, t, d) {
  const nq = B(3, 'يُنقِصونَ', d * 0.2);
  market(c, t, 0.9, { sun: [1080, 160] });
  K.par(c, 1, () => { scales(c, 640, 660, 1.1, 0.6 * A(t, nq, 1.2) + 0.05 * Math.sin(t * 2), 0.9); KIT.crowd(c, 8104, 2, 760, 840, 670, 1.0, t, { face: -1, point: 0.4 }); });
} });
S.push({ // 4 give full measure and weight with justice; do not spread corruption - level
  cam: (p) => [K.lerp(1.45, 1.3, E(p)), 640, 520, 0], draw(c, t, d) {
  const ad = B(4, 'بالعدلِ', d * 0.3);
  market(c, t, 0.95, { sun: [1080, 150] });
  K.par(c, 1, () => { scales(c, 640, 660, 1.1, 0.6 * (1 - A(t, ad - 0.3, 1.4)), 0.95); K.presence(c, 470, 620, 26, t, 1); });
} });
S.push({ // 5 recitation 11:85 - the level scale in the light
  cam: (p) => [K.lerp(1.2, 1.35, E(p)), 640, 500, 0], draw(c, t, d) {
  market(c, t, 0.75, { sun: [1100, 300] });
  K.par(c, 1, () => { scales(c, 640, 660, 1.1, 0.02 * Math.sin(t), 0.85); K.presence(c, 470, 620, 26, t, 1); K.rays(c, 640, 540, 8, 600, -Math.PI * 0.85, -Math.PI * 0.15, '#FFF0C8', 0.08, t); });
} });
S.push({ // 6 the little lawful profit has blessing - better than unlawful gain
  cam: (p) => [K.lerp(1.3, 1.15, E(p)), 640, 520, 0], draw(c, t, d) {
  const bk = B(6, 'بركةٌ', d * 0.45);
  market(c, t, 0.95, { sun: [1080, 150] });
  K.par(c, 1, () => {
    const k = A(t, bk - 0.3, 1);
    // a few honest coins that glow (blessing) beside a dull heap that fades
    for (let i = 0; i < 4; i++) { const x = 540 + i * 34, y = 650 - (i % 2) * 8; K.glow(c, x, y, 40, '#FFE6A8', 0.55 * k); c.fillStyle = '#E8D080'; c.beginPath(); c.ellipse(x, y, 18, 8, 0, 0, TAU); c.fill(); c.strokeStyle = '#B8A050'; c.lineWidth = 2; c.stroke(); }
    c.save(); c.globalAlpha *= 1 - 0.7 * k; for (let i = 0; i < 18; i++) { c.fillStyle = i % 2 ? '#8A8468' : '#9A9070'; c.beginPath(); c.ellipse(780 + (i % 6) * 30, 655 - Math.floor(i / 6) * 12, 18, 8, 0, 0, TAU); c.fill(); } c.restore();
    K.presence(c, 440, 620, 24, t, 1);
  });
} });
S.push({ // 7 they mocked him: does your prayer order us to leave what our fathers worshipped?
  cam: (p) => [1.08, 760, 460, 0], draw(c, t, d) {
  market(c, t, 0.85, { sun: [1080, 220] });
  K.par(c, 1, () => { KIT.crowd(c, 8105, 12, 640, 1180, 665, 1.0, t, { face: -1, shake: 0.6, point: A(t, d * 0.3, 0.5) }); K.presence(c, 420, 620, 26, t, 1); });
} });
S.push({ // 8 I only want to set right what I can; my success is only by Allah, in Him I trust
  cam: (p) => [K.lerp(1.15, 1.25, E(p)), 440, 500, 0], draw(c, t, d) {
  const tw = B(8, 'توكَّلتُ', d * 0.85);
  market(c, t, 0.8, { sun: [1080, 260] });
  K.par(c, 1, () => { KIT.crowd(c, 8105, 12, 640, 1180, 665, 1.0, t, { face: -1 }); K.presence(c, 420, 620, 28, t, 1); K.rays(c, 420, 610, 8, 640, -Math.PI * 0.7, -Math.PI * 0.3, '#FFF0C8', 0.08 + 0.08 * A(t, tw - 0.4, 1), t); });
} });
S.push({ // 9 he never ordered them a thing and did otherwise - the same light, at his own stall, level scale
  cam: (p) => [K.lerp(1.2, 1.3, E(p)), 300, 520, 0], draw(c, t, d) {
  market(c, t, 0.85, { sun: [1080, 220] });
  K.par(c, 1, () => { scales(c, 300, 650, 0.8, 0.02 * Math.sin(t), 0.85); K.presence(c, 420, 620, 24, t, 1); });
} });
S.push({ // 10 they persisted: we do not understand much of what you say
  cam: (p) => [1.04, 760, 430, 0], draw(c, t, d) {
  market(c, t, 0.6, { sun: [1120, 360], cols: ['#4E4A6A', '#B07A6A', '#E8B08A'] });
  K.par(c, 1, () => { KIT.crowd(c, 8106, 14, 600, 1220, 665, 1.0, t, { face: 1, walk: 0.6, shift: 120 * A(t, 0, d, (x) => x) }); K.presence(c, 420, 620, 24, t, 1); });
} });
S.push({ // 11 Allah saved Shu'ayb and the believers; the blast took the wrongdoers - empty market
  cam: (p) => [K.lerp(1.1, 1.0, E(p)), 640, 420, 0], draw(c, t, d) {
  const sy = B(11, 'الصيحةُ', d * 0.75);
  const empty = A(t, sy - 0.2, 1.5);
  market(c, t, K.lerp(0.55, 0.45, empty), { cols: ['#3E3A5A', '#8A6A7A', '#C8987A'] });
  K.par(c, 1, () => {
    const go = A(t, d * 0.15, d * 0.5, (x) => x);
    KIT.crowd(c, 8107, 6, 380, 560, 660, 1.0, t, { face: -1, walk: 1, shift: -620 * go });
    K.presence(c, K.lerp(340, -260, go), 620, 26, t, 1);
    c.save(); c.globalAlpha *= 1 - empty; KIT.crowd(c, 8106, 10, 760, 1180, 665, 1.0, t, {}); c.restore();
    scales(c, 1000, 650, 0.7, 0, 0.5);
    const q = K.clamp((t - sy) / 1.6); if (q > 0 && q < 1) { c.strokeStyle = K.rgba('#FFFFFF', 0.5 * (1 - q)); c.lineWidth = 5; c.beginPath(); c.arc(900, 300, 80 + q * 900, 0, TAU); c.stroke(); }
  });
} });
S.push({ cam: (p) => [K.lerp(1.1, 1.02, E(p)), 640, K.lerp(390, 362, E(p)), 0], draw(c, t, d, p) {
  KIT.lesson(c, t, p, { seed: 8108 });
} });
window.STORY_SCENES = S;
})();
