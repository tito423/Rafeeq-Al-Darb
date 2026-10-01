// Luqman's counsel to his son. VISUALS ONLY.
// Narration: docs/kids_stories/luqman_narration.md (31:12-19 + al-Muyassar).
// Luqman is NOT drawn (caution - some scholars held him a prophet): a warm
// light, his son a smaller one. Each scene pictures the counsel itself.
// «the harshest voice is the donkey's» is not narrated, and no donkey is drawn.
'use strict';
(() => {
const { W, H } = K;
const TAU = Math.PI * 2;
const E = K.easeInOut, B = K.beat, A = K.after;
const garden = (c, t, light, o = {}) => {
  KIT.sky(c, t, light, { sun: o.sun, moon: o.moon, seed: 71 });
  KIT.land(c, light, { seed: 7.1, farCol: '#A8B49A', midCol: '#94A872' });
  K.par(c, 0.8, () => {
    KIT.ground(c, 540, light, '#A9BC7C');
    // a broad shade tree
    c.fillStyle = K.tone('#6B4A34', light); c.fillRect(372, 430, 26, 180);
    c.fillStyle = K.tone('#5E7A45', light); for (const [x, y, r] of [[385, 400, 90], [320, 430, 60], [455, 430, 66], [385, 350, 60]]) { c.beginPath(); c.arc(x, y, r, 0, TAU); c.fill(); }
    for (const [x, h, ph] of [[900, 160, 1], [1150, 140, 2]]) KIT.palm(c, x, 600, h, light, t, ph);
    for (const [x, s] of [[620, 1.0], [760, 0.8], [1040, 1.1]]) K.shrub(c, x, 640, s, K.tone('#7E9A55', light));
  });
};
const pair = (c, t, a = 1, x = 520) => { K.presence(c, x, 615, 26, t, a); K.presence(c, x + 80, 625, 14, t, a); };
const home = (c, light, glow) => K.house(c, 820, 610, 150, 100, K.tone('#E2BC8C', light), K.tone('#B98E64', light), K.tone('#5A3A2A', light), glow);

const S = [];
S.push({ // 1 Allah gave Luqman wisdom: understanding of the religion, reason, right speech
  cam: (p) => [K.lerp(1.0, 1.12, E(p)), 520, 440, 0], draw(c, t, d) {
  garden(c, t, 0.95, { sun: [1060, 150] });
  K.par(c, 1, () => { K.presence(c, 470, 615, 28, t, 1); K.rays(c, 470, 600, 9, 600, -Math.PI * 0.85, -Math.PI * 0.15, '#FFF0C8', 0.1 * A(t, d * 0.4, 1.5), t); });
  KIT.foreGrass(c, t, 0.95);
} });
S.push({ // 2 thank Allah for His blessings; whoever thanks, it is for his own good
  cam: (p) => [K.lerp(1.0, 1.08, E(p)), K.lerp(560, 760, E(p)), 420, 0], draw(c, t, d) {
  garden(c, t, 0.97, { sun: [1060, 150] });
  K.par(c, 1, () => {
    K.presence(c, 470, 615, 26, t, 1);
    const r = K.rng(7102); // fruit appearing on the shrubs and palms: blessings
    for (let i = 0; i < 16; i++) { const x = 560 + r() * 640, y = 520 + r() * 110, k = A(t, d * (0.2 + r() * 0.5), 0.6); c.fillStyle = K.rgba(['#C8553D', '#E0A030', '#B04A6A'][i % 3], k); c.beginPath(); c.arc(x, y, 6 * k, 0, TAU); c.fill(); }
  });
  K.par(c, 0.12, () => K.birds(c, t, 7103, 6, 500, 170, 200, 26, 9, '#4A3A40', 0.6));
  KIT.foreGrass(c, t, 0.97);
} });
S.push({ // 3 he sat counselling his son: do not associate anything with Allah
  cam: (p) => [K.lerp(1.15, 1.3, E(p)), 560, 540, 0], draw(c, t, d) {
  const sh = B(3, 'تُشرِكْ', d * 0.6);
  garden(c, t, 0.85, { sun: [1080, 220] });
  K.par(c, 1, () => { pair(c, t); K.rays(c, 560, 600, 6, 520, -Math.PI * 0.62, -Math.PI * 0.38, '#FFF0C8', 0.12 * A(t, sh - 0.3, 1), t); });
  KIT.foreGrass(c, t, 0.85);
} });
S.push({ // 4 recitation 31:13 - one light in the sky above the two
  cam: (p) => [K.lerp(1.0, 1.08, E(p)), 640, K.lerp(420, 360, E(p)), 0], draw(c, t, d, p) {
  garden(c, t, K.lerp(0.6, 0.35, E(p)), { sun: [1080, K.lerp(260, 420, E(p))] });
  K.par(c, 1, () => pair(c, t));
  K.par(c, 0.2, () => { K.glow(c, 640, 160, 120, '#FFF6DA', 0.25 * E(p)); K.stars(c, 7104, 60, 0.6 * E(p), t, 400); });
} });
S.push({ // 5 be dutiful to parents: his mother carried him weakness upon weakness, two years nursing - a cradle in a lit home
  cam: (p) => [K.lerp(1.1, 1.25, E(p)), 860, 540, 0], draw(c, t, d) {
  garden(c, t, 0.35, { moon: [1100, 140] });
  K.par(c, 1, () => {
    home(c, 0.4, 1);
    K.glow(c, 880, 580, 120, '#FFC869', 0.25);
    // a cradle by the door, rocking (no figure)
    c.save(); c.translate(980, 640); c.rotate(Math.sin(t * 1.4) * 0.12);
    c.fillStyle = '#8A6A4C'; c.beginPath(); c.arc(0, -10, 34, 0, Math.PI); c.fill(); c.fillStyle = '#EADCC4'; c.fillRect(-28, -20, 56, 10); c.restore();
  });
} });
S.push({ // 6 thank Allah, then thank your parents
  cam: (p) => [K.lerp(1.2, 1.05, E(p)), 760, 460, 0], draw(c, t, d) {
  const wl = B(6, 'والدَيْنا', d * 0.7);
  garden(c, t, 0.85, { sun: [1060, 200] });
  K.par(c, 1, () => {
    home(c, 0.85, 0.6);
    K.rays(c, 1060, 200, 10, 900, Math.PI * 0.55, Math.PI * 0.95, '#FFF0C8', 0.1, t);
    K.glow(c, 895, 560, 140, '#FFC869', 0.25 * A(t, wl - 0.3, 1));
    K.presence(c, 720, 625, 14, t, 1);
  });
  KIT.foreGrass(c, t, 0.85);
} });
S.push({ // 7 a deed as small as a mustard seed, in a rock, in the heavens or the earth - Allah brings it
  cam: (p, t, d) => { const q = E(p); return [K.lerp(2.4, 1.0, q), 640, K.lerp(560, 380, q), 0]; }, draw(c, t, d, p) {
  K.par(c, 0, () => { K.sky(c, ['#0E1534', '#1B2550', '#2E3A66'], 0, 720); K.stars(c, 7105, 160, 0.9, t, 700); });
  K.par(c, 1, () => {
    K.stone(c, 'boulder', 640, 620, 200, '#8A7A6A', '#A89888', '#6A5A4C');
    K.glow(c, 640, 560, 30, '#FFE6A8', 0.9); c.fillStyle = '#FFF4D0'; c.beginPath(); c.arc(640, 560, 3, 0, TAU); c.fill();
    KIT.ground(c, 620, 0.4, '#6E6A5A');
  });
} });
S.push({ // 8 Allah is Subtle with His servants, Aware of what they do - the seed's light rises
  cam: (p) => [K.lerp(1.0, 1.1, E(p)), 640, K.lerp(380, 300, E(p)), 0], draw(c, t, d, p) {
  K.par(c, 0, () => { K.sky(c, ['#0E1534', '#1B2550', '#2E3A66'], 0, 720); K.stars(c, 7105, 160, 0.9, t, 700); });
  K.par(c, 1, () => { const y = K.lerp(560, 160, E(p)); K.glow(c, 640, y, 40, '#FFE6A8', 0.8); c.fillStyle = '#FFF4D0'; c.beginPath(); c.arc(640, y, 3, 0, TAU); c.fill(); KIT.ground(c, 620, 0.4, '#6E6A5A'); });
} });
S.push({ // 9 establish prayer, enjoin good, forbid wrong gently, be patient
  cam: (p) => [K.lerp(1.1, 1.2, E(p)), 560, 520, 0], draw(c, t, d) {
  const sl = B(9, 'الصلاةَ', d * 0.15);
  garden(c, t, 0.7, { sun: [1100, 300] });
  K.par(c, 1, () => {
    const k = A(t, sl - 0.3, 1);
    c.save(); c.globalAlpha *= k; c.fillStyle = '#8A3E3A'; c.beginPath(); c.moveTo(640, 650); c.lineTo(720, 650); c.lineTo(712, 600); c.lineTo(648, 600); c.fill(); c.restore();
    pair(c, t, 1, 480);
  });
  KIT.foreGrass(c, t, 0.7);
} });
S.push({ // 10 do not turn your face from people; do not walk proudly - people greet each other
  cam: (p) => [1.05, K.lerp(560, 720, E(p)), 440, 0], draw(c, t, d) {
  garden(c, t, 0.95, { sun: [1060, 150] });
  K.par(c, 1, () => { KIT.crowd(c, 7106, 3, 560, 700, 650, 1.0, t, { face: 1 }); KIT.crowd(c, 7107, 3, 760, 900, 650, 1.0, t, { face: -1 }); });
  KIT.foreGrass(c, t, 0.95);
} });
S.push({ // 11 be modest in your walk and lower your voice
  cam: (p) => [1.08, 640, 450, 0], draw(c, t, d) {
  garden(c, t, 0.9, { sun: [1060, 170] });
  K.par(c, 1, () => {
    KIT.crowd(c, 7108, 1, 380, 381, 660, 1.0, t, { face: 1, walk: 0.5, shift: A(t, 0, d, (x) => x) * 420 });
    const x = 380 + A(t, 0, d, (x) => x) * 420; // soft sound rings, small
    for (let i = 0; i < 3; i++) { const q = K.fract(t * 0.5 + i / 3); c.strokeStyle = K.rgba('#FFFFFF', 0.4 * (1 - q)); c.lineWidth = 1.5; c.beginPath(); c.arc(x + 8, 585, 6 + q * 22, -0.6, 0.6); c.stroke(); }
  });
  KIT.foreGrass(c, t, 0.9);
} });
S.push({ cam: (p) => [K.lerp(1.1, 1.02, E(p)), 640, K.lerp(390, 362, E(p)), 0], draw(c, t, d, p) {
  KIT.lesson(c, t, p, { seed: 7109 });
} });
window.STORY_SCENES = S;
})();
