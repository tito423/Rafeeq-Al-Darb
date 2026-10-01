// Ilyas, peace be upon him. VISUALS ONLY.
// Narration: docs/kids_stories/ilyas_narration.md (37:123-132 + al-Muyassar).
// Ilyas is NEVER drawn - a warm light. His people are flat featureless
// figures; the idol is a plain stone block (no face), as in the Ibrahim story.
'use strict';
(() => {
const { W, H } = K;
const TAU = Math.PI * 2;
const E = K.easeInOut, B = K.beat, A = K.after;
const town = (c, t, light, o = {}) => {
  KIT.sky(c, t, light, { sun: o.sun, moon: o.moon, cols: o.cols, seed: 201 });
  KIT.land(c, light, { seed: 20.1, farCol: '#A0A090', midCol: '#9AA070' });
  KIT.town(c, light, o.glow || 0, { seed: 20101, n: 22, ty: 540 });
  K.par(c, 0.9, () => { if (!o.noIdol) { K.stone(c, 'stepped', 900, 640, 170 * (o.idol ?? 1), K.tone('#9A8A7A', light), K.tone('#B8A898', light), K.tone('#6E6052', light)); } });
};
const S = [];
S.push({ // 1 Allah honoured Ilyas with prophethood, sent to his people of Bani Isra'il
  cam: (p) => [K.lerp(1.0, 1.1, E(p)), 520, 440, 0], draw(c, t, d) {
  town(c, t, 0.9, { sun: [1060, 160] });
  K.par(c, 1, () => { K.presence(c, K.lerp(-40, 420, A(t, 0, d * 0.6)), 620, 28, t, 1); KIT.crowd(c, 20102, 10, 700, 1180, 665, 1.0, t, {}); });
} });
S.push({ // 2 they worshipped an idol and left the worship of Allah
  cam: (p) => [K.lerp(1.15, 1.3, E(p)), 900, 520, 0], draw(c, t, d) {
  town(c, t, 0.8, { sun: [1080, 240] });
  K.par(c, 1, () => KIT.crowd(c, 20103, 10, 700, 1150, 665, 1.0, t, { face: 1 }));
} });
S.push({ // 3 fear Allah alone; do not associate others with Him
  cam: (p) => [K.lerp(1.1, 1.2, E(p)), 520, 500, 0], draw(c, t, d) {
  town(c, t, 0.85, { sun: [1080, 220] });
  K.par(c, 1, () => { K.presence(c, 420, 620, 28, t, 1); K.rays(c, 420, 610, 9, 600, -Math.PI * 0.85, -Math.PI * 0.15, '#FFF0C8', 0.1 * A(t, d * 0.3, 1), t); KIT.crowd(c, 20103, 10, 640, 1100, 665, 1.0, t, { face: -1 }); });
} });
S.push({ // 4 how can you worship an idol and leave the Best of creators? - the idol dwarfed by the sky
  cam: (p) => [K.lerp(1.3, 1.0, E(p)), 900, K.lerp(560, 360, E(p)), 0], draw(c, t, d) {
  town(c, t, 0.85, { sun: [1080, 200] });
  K.par(c, 0.2, () => K.rays(c, 1080, 200, 12, 1000, Math.PI * 0.5, Math.PI * 1.0, '#FFF0C8', 0.1 * A(t, d * 0.4, 1.5), t));
  K.par(c, 1, () => K.presence(c, 420, 620, 26, t, 1));
} });
S.push({ // 5 recitation 37:125 - the town at dusk, the light steady
  cam: (p) => [K.lerp(1.0, 1.06, E(p)), 640, K.lerp(430, 380, E(p)), 0], draw(c, t, d, p) {
  town(c, t, K.lerp(0.75, 0.4, E(p)), { sun: [K.lerp(1080, 1160, E(p)), K.lerp(240, 430, E(p))], glow: E(p) * 0.5 });
  K.par(c, 1, () => K.presence(c, 420, 620, 28, t, 1));
} });
S.push({ // 6 Allah your Lord, who created you and your forefathers - generations as lights in the sky
  cam: (p) => [1.0, 640, K.lerp(420, 320, E(p)), 0], draw(c, t, d) {
  town(c, t, 0.2, { moon: [1040, 140], glow: 0.7 });
  K.par(c, 0.1, () => K.stars(c, 20104, 200, 0.9 * A(t, d * 0.2, 1.5), t, 600));
  K.par(c, 1, () => K.presence(c, 420, 620, 26, t, 1));
} });
S.push({ // 7 his people denied him, except Allah's sincere servants - a few lights stay with him
  cam: (p) => [K.lerp(1.0, 1.1, E(p)), 520, 460, 0], draw(c, t, d) {
  town(c, t, 0.75, { sun: [1100, 300] });
  K.par(c, 1, () => {
    KIT.crowd(c, 20105, 10, 700, 1180, 665, 1.0, t, { face: 1, walk: 0.5, shift: 120 * A(t, 0, d, (x) => x) });
    KIT.crowd(c, 20106, 3, 470, 600, 660, 1.0, t, { face: -1, appear: A(t, d * 0.5, 1, (x) => x) });
    K.presence(c, 400, 620, 26, t, 1);
  });
} });
S.push({ // 8 a beautiful mention among later nations; peace upon Ilyas
  cam: (p) => [1.0, 640, K.lerp(420, 340, E(p)), 0], draw(c, t, d) {
  town(c, t, 0.9, { sun: [1060, 160], noIdol: true });
  K.par(c, 0.6, () => { for (let i = 0; i < 6; i++) { const q = K.fract(t * 0.12 + i / 6); K.glow(c, 200 + i * 180, 520 - q * 300, 14, '#FFF0C8', 0.45 * Math.sin(q * Math.PI)); } });
  K.par(c, 1, () => K.presence(c, 640, 620, 28, t, 1));
} });
S.push({ // 9 so Allah rewards the doers of good; he was among His sincere believing servants
  cam: (p) => [K.lerp(1.1, 1.2, E(p)), 640, 500, 0], draw(c, t, d) {
  town(c, t, 0.95, { sun: [1060, 160], noIdol: true });
  K.par(c, 1, () => { K.presence(c, 640, 620, 30, t, 1); K.rays(c, 640, 610, 12, 700, -Math.PI * 0.95, -Math.PI * 0.05, '#FFF0C8', 0.12, t); });
} });
S.push({ cam: (p) => [K.lerp(1.1, 1.02, E(p)), 640, K.lerp(390, 362, E(p)), 0], draw(c, t, d, p) {
  KIT.lesson(c, t, p, { seed: 20107 });
} });
window.STORY_SCENES = S;
})();
