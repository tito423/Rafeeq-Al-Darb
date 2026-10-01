// The owner of the two gardens (18:32-44). VISUALS ONLY.
// Narration: docs/kids_stories/jannatayn_narration.md (+ al-Muyassar).
// No prophet in the story: the two men are flat featureless figures (the
// believer in a plain robe, the proud owner in a richer one). The gardens are
// the subject. The ruin is the garden only (fallen trellises, bare ground) -
// no frightening storm.
'use strict';
(() => {
const { W, H } = K;
const TAU = Math.PI * 2;
const E = K.easeInOut, B = K.beat, A = K.after;
const OWNER = { robes: ['#8A2E4A'], cloths: ['#F0D060'] }, BELIEVER = { robes: ['#6E6A5E'], cloths: ['#E9DCC4'] };
// g = 1 lush ... 0 ruined
const gardens = (c, t, light, g, o = {}) => {
  KIT.sky(c, t, light, { sun: o.sun, moon: o.moon, cols: o.cols, seed: 141 });
  KIT.land(c, light, { seed: 14.1, farCol: '#A8B49A', midCol: K.mix('#A89878', '#94A872', g) });
  K.par(c, 0.8, () => {
    KIT.ground(c, 540, light, K.mix('#9A8A6A', '#A9BC7C', g));
    // the river between the two gardens
    c.fillStyle = K.tone(K.mix('#8A7A60', '#6EB0C0', g), light); c.beginPath(); c.moveTo(600, 540); c.quadraticCurveTo(640, 620, 560, 720); c.lineTo(720, 720); c.quadraticCurveTo(700, 620, 680, 540); c.fill();
    for (const [x0, x1] of [[60, 560], [720, 1220]]) {
      // palms around
      for (let x = x0; x <= x1; x += 125) { if (g > 0.3) KIT.palm(c, x, 590, 150 + 20 * Math.sin(x), light, t, x, g); else { c.strokeStyle = K.tone('#6B4A34', light); c.lineWidth = 8; c.beginPath(); c.moveTo(x, 590); c.lineTo(x + 30 * (1 - g), 500 + 60 * (1 - g)); c.stroke(); } }
      // vine trellises with grapes
      for (let x = x0 + 40; x < x1 - 20; x += 90) {
        const fall = (1 - g) * ((x * 7) % 3) * 0.3;
        c.save(); c.translate(x, 620); c.rotate(fall);
        c.strokeStyle = K.tone('#7A5A3E', light); c.lineWidth = 4; c.beginPath(); c.moveTo(-30, 0); c.lineTo(-30, -60); c.lineTo(30, -60); c.lineTo(30, 0); c.stroke();
        if (g > 0.05) { c.fillStyle = K.tone('#5E7A45', light); c.globalAlpha *= g; c.beginPath(); c.ellipse(0, -62, 42, 14, 0, 0, TAU); c.fill(); c.fillStyle = K.tone('#6A3A6A', light); for (let i = 0; i < 3; i++) { c.beginPath(); c.arc(-16 + i * 16, -44, 6, 0, TAU); c.fill(); } }
        c.restore();
      }
    }
    // crops in between
    if (g > 0.05) for (let x = 80; x < 1200; x += 22) { if (x > 560 && x < 720) continue; c.strokeStyle = K.rgba(K.tone('#7AA04A', light), g); c.lineWidth = 2; c.beginPath(); c.moveTo(x, 660); c.lineTo(x + Math.sin(t + x) * 2, 640); c.stroke(); }
  });
};

const S = [];
S.push({ // 1 Allah gives an example of two men: one believing, one disbelieving
  cam: (p) => [K.lerp(1.1, 1.2, E(p)), 640, 520, 0], draw(c, t, d) {
  gardens(c, t, 0.9, 1, { sun: [1060, 160] });
  K.par(c, 1, () => { KIT.crowd(c, 14101, 1, 520, 521, 680, 1.1, t, { face: 1, ...BELIEVER }); KIT.crowd(c, 14102, 1, 760, 761, 680, 1.1, t, { face: -1, ...OWNER }); });
} });
S.push({ // 2 two gardens of grapes surrounded by palms, crops between
  cam: (p) => [K.lerp(1.0, 1.08, E(p)), K.lerp(420, 860, E(p)), 430, 0], draw(c, t, d) {
  gardens(c, t, 0.95, 1, { sun: [1060, 160] });
  K.par(c, 0.12, () => K.birds(c, t, 14103, 7, 400, 170, 200, 26, 9, '#4A3A40', 0.6));
} });
S.push({ // 3 each gave its full fruit; a river flows between them
  cam: (p) => [K.lerp(1.2, 1.3, E(p)), 640, 560, 0], draw(c, t, d) {
  gardens(c, t, 0.95, 1, { sun: [1060, 160] });
  K.par(c, 0.8, () => { for (let i = 0; i < 3; i++) { const q = K.fract(t * 0.4 + i / 3); c.strokeStyle = K.rgba('#E8F8FA', 0.6 * (1 - q)); c.lineWidth = 2; c.beginPath(); c.moveTo(620 - 20 * q, 560 + 140 * q); c.lineTo(660 - 20 * q, 560 + 140 * q); c.stroke(); } });
} });
S.push({ // 4 full of pride he told his believing friend: I have more wealth and stronger helpers
  cam: (p) => [K.lerp(1.15, 1.3, E(p)), 640, 540, 0], draw(c, t, d) {
  gardens(c, t, 0.9, 1, { sun: [1060, 180] });
  K.par(c, 1, () => { KIT.crowd(c, 14101, 1, 520, 521, 680, 1.1, t, { face: 1, ...BELIEVER }); KIT.crowd(c, 14102, 1, 760, 761, 680, 1.1, t, { face: -1, ...OWNER, point: A(t, d * 0.2, 0.6), shake: 0.4 }); });
} });
S.push({ // 5 he entered his garden, admired its fruit: this will never perish
  cam: (p) => [1.06, K.lerp(800, 960, E(p)), 470, 0], draw(c, t, d) {
  gardens(c, t, 0.95, 1, { sun: [1060, 160] });
  K.par(c, 1, () => KIT.crowd(c, 14102, 1, 800, 801, 690, 1.1, t, { face: 1, ...OWNER, walk: 0.6, shift: 180 * A(t, 0, d, (x) => x) }));
} });
S.push({ // 6 nor do I think the Hour will come
  cam: (p) => [K.lerp(1.1, 1.0, E(p)), 900, 440, 0], draw(c, t, d) {
  gardens(c, t, 0.8, 1, { sun: [1100, 300] });
  K.par(c, 1, () => KIT.crowd(c, 14102, 1, 980, 981, 690, 1.1, t, { face: -1, ...OWNER, shake: 0.3 }));
} });
S.push({ // 7 his friend counselled: how can you disbelieve in the One who created you from dust?
  cam: (p) => [K.lerp(1.2, 1.3, E(p)), 600, 560, 0], draw(c, t, d) {
  gardens(c, t, 0.85, 1, { sun: [1100, 260] });
  K.par(c, 1, () => { KIT.crowd(c, 14101, 1, 520, 521, 680, 1.1, t, { face: 1, ...BELIEVER }); KIT.crowd(c, 14102, 1, 700, 701, 680, 1.1, t, { face: -1, ...OWNER }); K.dust(c, t, 14104, 20, '#E8D3B0', 0.5 * A(t, d * 0.4, 1), 480, 560, 600, 680, 1); });
} });
S.push({ // 8 as for me: Allah is my Lord alone, I associate none with Him
  cam: (p) => [K.lerp(1.3, 1.4, E(p)), 520, 580, 0], draw(c, t, d) {
  gardens(c, t, 0.8, 1, { sun: [1100, 300] });
  K.par(c, 1, () => { KIT.crowd(c, 14101, 1, 520, 521, 680, 1.1, t, { face: 1, ...BELIEVER }); K.rays(c, 520, 600, 7, 520, -Math.PI * 0.62, -Math.PI * 0.38, '#FFF0C8', 0.12 * A(t, d * 0.3, 1), t); });
} });
S.push({ // 9 why not say when you entered: what Allah wills, there is no power except with Allah
  cam: (p) => [K.lerp(1.0, 1.1, E(p)), 640, 460, 0], draw(c, t, d) {
  gardens(c, t, 0.9, 1, { sun: [1060, 200] });
  K.par(c, 1, () => { KIT.crowd(c, 14101, 1, 520, 521, 680, 1.1, t, { face: 1, ...BELIEVER }); KIT.crowd(c, 14102, 1, 700, 701, 680, 1.1, t, { face: -1, ...OWNER }); });
  K.par(c, 0.2, () => K.glow(c, 640, 160, 160, '#FFF6DA', 0.2 * A(t, d * 0.4, 1.5)));
} });
S.push({ // 10 recitation 18:39 - the garden in golden light
  cam: (p) => [K.lerp(1.0, 1.08, E(p)), 640, K.lerp(440, 380, E(p)), 0], draw(c, t, d, p) {
  gardens(c, t, K.lerp(0.9, 0.6, E(p)), 1, { sun: [K.lerp(1060, 1140, E(p)), K.lerp(200, 360, E(p))] });
} });
S.push({ // 11 what his friend warned of came true: everything in the garden perished
  cam: (p) => [K.lerp(1.0, 1.1, E(p)), 640, 440, 0], draw(c, t, d) {
  const hl = B(11, 'وهلكَ', d * 0.55);
  const g = 1 - A(t, hl - 0.6, 2.4);
  gardens(c, t, K.lerp(0.55, 0.9, g), g, { sun: [1080, 220], cols: [K.mix('#6E6A86', '#5DA9D6', g), K.mix('#B49A9A', '#A3D2E6', g), K.mix('#D8B48E', '#F4E3C0', g)] });
  K.par(c, 1.08, () => K.dust(c, t, 14105, 40, '#D8C8A8', 0.4 * (1 - g), -100, W + 100, 400, 720, 26));
} });
S.push({ // 12 he wrung his hands in regret: if only I had not associated anyone with my Lord
  cam: (p) => [K.lerp(1.15, 1.3, E(p)), 900, 540, 0], draw(c, t, d) {
  gardens(c, t, 0.6, 0, { sun: [1100, 300], cols: ['#6E6A86', '#B49A9A', '#D8B48E'] });
  K.par(c, 1, () => KIT.crowd(c, 14102, 1, 900, 901, 690, 1.1, t, { face: -1, ...OWNER, shake: 0.5 }));
} });
S.push({ // 13 none of those he boasted of could help him
  cam: (p) => [K.lerp(1.0, 1.06, E(p)), 640, 430, 0], draw(c, t, d) {
  gardens(c, t, 0.55, 0, { sun: [1120, 360], cols: ['#5E5A76', '#A48A8A', '#C8A47E'] });
  K.par(c, 1, () => KIT.crowd(c, 14102, 1, 900, 901, 690, 1.0, t, { face: -1, ...OWNER }));
} });
S.push({ cam: (p) => [K.lerp(1.1, 1.02, E(p)), 640, K.lerp(390, 362, E(p)), 0], draw(c, t, d, p) {
  KIT.lesson(c, t, p, { seed: 14106 });
} });
window.STORY_SCENES = S;
})();
