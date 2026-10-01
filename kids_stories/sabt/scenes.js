// The People of the Sabbath (7:163-166). VISUALS ONLY.
// Narration: docs/kids_stories/sabt_narration.md (+ al-Muyassar). No prophet
// in the story; people are flat featureless figures. The transformation is
// NEVER drawn - no apes: the shore stands empty, the pits empty, and only the
// voice says it.
'use strict';
(() => {
const { W, H } = K;
const TAU = Math.PI * 2;
const E = K.easeInOut, B = K.beat, A = K.after;
const shore = (c, t, light, o = {}) => {
  KIT.sky(c, t, light, { sun: o.sun, moon: o.moon, cols: o.cols, seed: 221 });
  K.par(c, 0.4, () => KIT.sea(c, t, 430, 5, light, ['#4E8EA6', '#2E5E78']));
  K.par(c, 0.7, () => { KIT.town(c, light, o.glow || 0, { seed: 22101, n: 16, x0: 640, x1: 1260, ty: 520 }); });
  K.par(c, 0.85, () => {
    c.fillStyle = K.tone('#D8C49A', light); c.beginPath(); c.moveTo(-420, 560); c.quadraticCurveTo(300, 500, 700, 540); c.quadraticCurveTo(1000, 570, W + 420, 520); c.lineTo(W + 420, H + 420); c.lineTo(-420, H + 420); c.fill();
    if (o.pits) for (const x of [180, 300, 420]) { c.fillStyle = K.tone('#5E8A9A', light); c.beginPath(); c.ellipse(x, 600, 46, 12, 0, 0, TAU); c.fill(); if (o.pits > 1) for (let i = 0; i < 3; i++) { c.fillStyle = K.rgba('#C8D8E0', 0.9); c.beginPath(); c.ellipse(x - 18 + i * 18, 600, 8, 3, 0, 0, TAU); c.fill(); } }
  });
};
// fish on the surface (n), drawn small near the shore
const fish = (c, t, n, a = 1) => { if (a <= 0.01) return; const r = K.rng(22102); c.save(); c.globalAlpha *= a; for (let i = 0; i < n; i++) { const x = 60 + r() * 1180 + Math.sin(t * 0.8 + i) * 10, y = 450 + r() * 70, s = 0.8 + r() * 0.4; c.fillStyle = ['#C8D8E0', '#E8D8A8', '#A8C0D0'][i % 3]; c.beginPath(); c.ellipse(x, y, 12 * s, 4.5 * s, 0, 0, TAU); c.fill(); c.beginPath(); c.moveTo(x - 10 * s, y); c.lineTo(x - 18 * s, y - 5 * s); c.lineTo(x - 18 * s, y + 5 * s); c.fill(); } c.restore(); };
const dayMark = (c, t, sabbath) => { // a calendar of seven dots; the Sabbath dot lit
  for (let i = 0; i < 7; i++) { c.fillStyle = K.rgba(i === 6 && sabbath ? '#FFE070' : '#FFFFFF', i === 6 && sabbath ? 0.9 : 0.35); c.beginPath(); c.arc(520 + i * 40, 680, i === 6 ? 9 : 6, 0, TAU); c.fill(); }
};

const S = [];
S.push({ // 1 a town by the sea; commanded to honour the Sabbath and not fish on it
  cam: (p) => [K.lerp(1.0, 1.1, E(p)), 640, 420, 0], draw(c, t, d) {
  shore(c, t, 0.9, { sun: [1060, 150] });
  K.par(c, 1, () => { KIT.crowd(c, 22103, 10, 700, 1180, 640, 1.0, t, {}); dayMark(c, t, A(t, d * 0.5, 1) > 0.5); });
} });
S.push({ // 2 a test: on the Sabbath the fish came plentiful, floating on the sea's surface
  cam: (p) => [K.lerp(1.0, 1.08, E(p)), 640, 460, 0], draw(c, t, d) {
  shore(c, t, 0.9, { sun: [1060, 150] });
  K.par(c, 0.4, () => fish(c, t, 40, A(t, d * 0.2, 1.5)));
  K.par(c, 1, () => dayMark(c, t, true));
} });
S.push({ // 3 when the Sabbath passed, the fish went away
  cam: (p) => [1.04, 640, 460, 0], draw(c, t, d) {
  shore(c, t, 0.9, { sun: [1060, 150] });
  K.par(c, 0.4, () => fish(c, t, 40, 1 - A(t, d * 0.2, 1.5)));
  K.par(c, 1, () => dayMark(c, t, A(t, d * 0.2, 0.5) < 0.5));
} });
S.push({ // 4 some schemed: trap the fish on the Sabbath in pits, catch them after
  cam: (p) => [K.lerp(1.2, 1.35, E(p)), 320, 560, 0], draw(c, t, d) {
  shore(c, t, 0.75, { sun: [1100, 300], pits: 1 + (A(t, d * 0.4, 0.6) > 0.5 ? 1 : 0) });
  K.par(c, 1, () => KIT.crowd(c, 22104, 4, 480, 640, 640, 1.0, t, { face: -1, point: 0.5 }));
} });
S.push({ // 5 a righteous group warned them and forbade the sin
  cam: (p) => [K.lerp(1.0, 1.08, E(p)), 560, 470, 0], draw(c, t, d) {
  shore(c, t, 0.8, { sun: [1100, 260], pits: 2 });
  K.par(c, 1, () => { KIT.crowd(c, 22104, 4, 300, 460, 640, 1.0, t, { face: 1 }); KIT.crowd(c, 22105, 4, 620, 760, 640, 1.0, t, { face: -1, robes: ['#E8E0D0', '#D8D0C0'] }); K.glow(c, 690, 600, 140, '#FFF0C8', 0.18); });
} });
S.push({ // 6 another group said: why warn a people Allah will destroy?
  cam: (p) => [K.lerp(1.08, 1.0, E(p)), 820, 460, 0], draw(c, t, d) {
  shore(c, t, 0.8, { sun: [1100, 260], pits: 2 });
  K.par(c, 1, () => { KIT.crowd(c, 22105, 4, 620, 760, 640, 1.0, t, { face: 1, robes: ['#E8E0D0', '#D8D0C0'] }); KIT.crowd(c, 22106, 4, 900, 1040, 640, 1.0, t, { face: -1, robes: ['#7A7A8A'] }); });
} });
S.push({ // 7 to do our duty before Allah, and that they might fear Him and repent
  cam: (p) => [K.lerp(1.2, 1.3, E(p)), 690, 540, 0], draw(c, t, d) {
  shore(c, t, 0.8, { sun: [1100, 260] });
  K.par(c, 1, () => { KIT.crowd(c, 22105, 4, 620, 760, 640, 1.0, t, { face: 1, robes: ['#E8E0D0', '#D8D0C0'] }); K.rays(c, 690, 600, 8, 520, -Math.PI * 0.8, -Math.PI * 0.2, '#FFF0C8', 0.12 * A(t, d * 0.3, 1), t); });
} });
S.push({ // 8 recitation 7:164 - the shore at dusk
  cam: (p) => [K.lerp(1.0, 1.06, E(p)), 640, K.lerp(440, 390, E(p)), 0], draw(c, t, d, p) {
  shore(c, t, K.lerp(0.8, 0.45, E(p)), { sun: [K.lerp(1100, 1160, E(p)), K.lerp(260, 420, E(p))], glow: E(p) * 0.5 });
} });
S.push({ // 9 they would not listen; Allah saved those who forbade the evil
  cam: (p) => [K.lerp(1.0, 1.08, E(p)), K.lerp(640, 900, E(p)), 450, 0], draw(c, t, d) {
  shore(c, t, 0.6, { sun: [1120, 360], cols: ['#3E3A5A', '#8A6A7A', '#C8987A'] });
  K.par(c, 1, () => { const go = A(t, d * 0.2, d * 0.7, (x) => x); KIT.crowd(c, 22105, 4, 620, 760, 640, 1.0, t, { face: 1, walk: 1, shift: 520 * go, robes: ['#E8E0D0', '#D8D0C0'] }); K.glow(c, 690 + 520 * go, 600, 140, '#FFF0C8', 0.2); });
} });
S.push({ // 10 and punished the transgressors - NOT drawn: the shore and the pits stand empty
  cam: (p) => [K.lerp(1.1, 1.0, E(p)), 360, 470, 0], draw(c, t, d) {
  shore(c, t, 0.45, { cols: ['#2E2A4A', '#5A4A6A', '#8A6A7A'], pits: 1 });
  K.par(c, 1.05, () => K.dust(c, t, 22107, 30, '#C8C0B8', 0.3, -100, W + 100, 420, 720, 10));
} });
S.push({ cam: (p) => [K.lerp(1.1, 1.02, E(p)), 640, K.lerp(390, 362, E(p)), 0], draw(c, t, d, p) {
  KIT.lesson(c, t, p, { seed: 22108 });
} });
window.STORY_SCENES = S;
})();
