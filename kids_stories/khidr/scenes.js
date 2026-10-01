// Musa and al-Khidr, peace be upon them. VISUALS ONLY.
// Narration: docs/kids_stories/khidr_narration.md (18:60-82 + al-Muyassar).
// Musa and al-Khidr are NEVER drawn - lights; Yusha' bin Nun is not drawn
// (caution) - a smaller light. The second incident (18:74-76) is NOT drawn:
// scene 11 is the empty shore, the lights stop, then walk on - no child on
// screen. Ship's people and villagers are flat featureless figures.
'use strict';
(() => {
const { W, H } = K;
const TAU = Math.PI * 2;
const E = K.easeInOut, B = K.beat, A = K.after;
const KHIDR = '#E8FFE8';
const khidr = (c, x, y, t, a = 1) => { if (a <= 0.01) return; c.save(); c.globalCompositeOperation = 'lighter'; K.glow(c, x, y, 64, KHIDR, 0.2 * a); K.glow(c, x, y, 26, '#FFFFF0', 0.45 * a); K.glow(c, x, y, 9, '#FFFFFF', 0.8 * a); c.restore(); };
const trio = (c, t, x, y, k = 1, withK = false) => { K.presence(c, x, y, 26, t, 1); K.presence(c, x - 70, y + 6, 15, t, k); if (withK) khidr(c, x + 90, y, t); };
const seas = (c, t, light, o = {}) => {
  KIT.sky(c, t, light, { sun: o.sun, moon: o.moon, cols: o.cols, seed: 231 });
  K.par(c, 0.4, () => {
    KIT.sea(c, t, 430, 5, light, ['#4E8EA6', '#2E5E78']);
    // two seas meeting: a darker band from the right
    c.fillStyle = K.rgba(K.tone('#2E6E7A', light), 0.6); c.beginPath(); c.moveTo(700, 430); c.quadraticCurveTo(900, 470, W + 420, 440); c.lineTo(W + 420, 560); c.quadraticCurveTo(900, 520, 700, 430); c.fill();
  });
  K.par(c, 0.8, () => {
    c.fillStyle = K.tone('#D8C49A', light); c.beginPath(); c.moveTo(-420, 560); c.quadraticCurveTo(400, 520, 800, 560); c.quadraticCurveTo(1000, 580, W + 420, 560); c.lineTo(W + 420, H + 420); c.lineTo(-420, H + 420); c.fill();
    if (o.rock) { c.fillStyle = K.tone('#8A7A6A', light); c.beginPath(); c.moveTo(560, 600); c.quadraticCurveTo(580, 520, 650, 516); c.quadraticCurveTo(720, 520, 740, 600); c.fill(); }
  });
};
const ship = (c, x, y, s, t, light, o = {}) => {
  c.save(); c.translate(x, y + Math.sin(t * 1.4) * 3); c.rotate(Math.sin(t * 1.1) * 0.02); c.scale(s, s);
  c.fillStyle = K.tone('#7A5A3E', light); c.beginPath(); c.moveTo(-120, 0); c.lineTo(120, 0); c.lineTo(96, 36); c.lineTo(-96, 36); c.closePath(); c.fill();
  c.strokeStyle = K.tone('#5A3E2A', light); c.lineWidth = 2; for (let i = 0; i < 3; i++) { c.beginPath(); c.moveTo(-112 + i * 4, 10 + i * 9); c.lineTo(112 - i * 4, 10 + i * 9); c.stroke(); }
  if (o.hole) { c.fillStyle = '#1E1814'; c.fillRect(-12, 12, 26 * o.hole, 9); }
  c.fillStyle = K.tone('#6B4A34', light); c.fillRect(-4, -150, 8, 150);
  c.fillStyle = K.tone('#EFE6D2', light); c.beginPath(); c.moveTo(6, -140); c.quadraticCurveTo(80, -90, 6, -20); c.fill();
  c.restore();
};
const village = (c, t, light, o = {}) => {
  KIT.sky(c, t, light, { sun: o.sun, cols: o.cols, seed: 232 });
  KIT.land(c, light, { seed: 23.2, farCol: '#A8A090', midCol: '#A89878' });
  KIT.town(c, light, 0, { seed: 23201, n: 22, ty: 540 });
  K.par(c, 0.8, () => KIT.ground(c, 560, light, '#C2AA7A'));
};
// a wall leaning by lean (0 = upright)
const wall = (c, x, y, lean, light, treasure = 0) => {
  if (treasure > 0) { c.fillStyle = K.rgba('#3A2E24', 0.6 * treasure); c.fillRect(x - 20, y + 2, 250, 30); K.glow(c, x + 105, y + 18, 80, '#E8C060', 0.3 * treasure); }
  c.save(); c.translate(x, y); c.rotate(-lean * 0.22);
  for (let r = 0; r < 7; r++) for (let i = 0; i < 6; i++) {
    const bx = i * 36 + (r % 2) * 18 - 10, by = -r * 24 - 24;
    c.fillStyle = K.tone((r + i) % 2 ? '#A8845A' : '#94704A', light); c.fillRect(bx, by, 35, 23);
    c.strokeStyle = K.tone('#5E442E', light); c.lineWidth = 1.5; c.strokeRect(bx, by, 35, 23);
  }
  c.restore();
};
const S = [];
S.push({ // 1 Musa set out with his servant Yusha' to meet a righteous servant and learn from him
  cam: (p) => [1.04, K.lerp(400, 760, E(p)), 450, 0], draw(c, t, d) {
  seas(c, t, 0.9, { sun: [1060, 160] });
  K.par(c, 1, () => { const k = A(t, 0, d, (x) => x); trio(c, t, 260 + 360 * k, 620); });
} });
S.push({ // 2 a dead fish was their food; by a rock where the seas meet, it came alive and slipped into the sea
  cam: (p) => [K.lerp(1.15, 1.3, E(p)), 700, 540, 0], draw(c, t, d) {
  const hy = B(2, 'حيًّا', d * 0.55);
  seas(c, t, 0.85, { sun: [1080, 200], rock: true });
  K.par(c, 0.6, () => { const k = A(t, hy, 1.6); if (k > 0) { c.strokeStyle = K.rgba('#E8F8FA', 0.8); c.lineWidth = 6; c.beginPath(); c.moveTo(760, 470); c.quadraticCurveTo(900, 455, 900 + 260 * k, 470); c.stroke(); } });
  K.par(c, 1, () => {
    trio(c, t, 520, 620);
    c.fillStyle = '#A8824C'; c.fillRect(700, 600, 40, 26); // the basket
    const k = A(t, hy - 0.2, 0.9);
    const fx = K.lerp(720, 780, k), fy = K.lerp(598, 540, Math.sin(k * Math.PI)) - 20 * k;
    if (k < 1) { c.fillStyle = '#A8C0D0'; c.beginPath(); c.ellipse(fx, fy, 14, 5, -0.6 * k, 0, TAU); c.fill(); c.beginPath(); c.moveTo(fx - 12, fy); c.lineTo(fx - 20, fy - 6); c.lineTo(fx - 20, fy + 6); c.fill(); }
  });
} });
S.push({ // 3 tired and hungry they remembered the fish: that is the sign we sought - back to the rock
  cam: (p) => [1.04, K.lerp(900, 600, E(p)), 450, 0], draw(c, t, d) {
  seas(c, t, 0.75, { sun: [1100, 300], rock: true });
  K.par(c, 1, () => { const k = A(t, d * 0.4, d * 0.6, (x) => x); trio(c, t, 1000 - 400 * k, 620); });
} });
S.push({ // 4 there they found al-Khidr, given mercy and great knowledge from Allah
  cam: (p) => [K.lerp(1.1, 1.2, E(p)), 640, 520, 0], draw(c, t, d) {
  const kh = B(4, 'الخضرَ', d * 0.3);
  seas(c, t, 0.85, { sun: [1080, 220], rock: true });
  K.par(c, 1, () => { trio(c, t, 520, 620); khidr(c, 740, 560, t, A(t, kh - 0.4, 1.2)); K.rays(c, 740, 550, 9, 520, -Math.PI * 0.85, -Math.PI * 0.15, '#E8FFE8', 0.1 * A(t, kh, 1.2), t); });
} });
S.push({ // 5 Musa greeted him: may I follow you so you teach me?
  cam: (p) => [K.lerp(1.25, 1.35, E(p)), 640, 540, 0], draw(c, t, d) {
  seas(c, t, 0.85, { sun: [1080, 220], rock: true });
  K.par(c, 1, () => { trio(c, t, K.lerp(520, 600, A(t, 0, d * 0.4)), 620); khidr(c, 740, 560, t); });
} });
S.push({ // 6 you will not be able to be patient with me - how can you, over what you do not grasp?
  cam: (p) => [K.lerp(1.35, 1.25, E(p)), 670, 540, 0], draw(c, t, d) {
  seas(c, t, 0.8, { sun: [1100, 260], rock: true });
  K.par(c, 1, () => { trio(c, t, 600, 620); khidr(c, 740, 560, t); });
} });
S.push({ // 7 you will find me patient, Allah willing, and I will not disobey you
  cam: (p) => [K.lerp(1.2, 1.3, E(p)), 640, 540, 0], draw(c, t, d) {
  seas(c, t, 0.8, { sun: [1100, 260], rock: true });
  K.par(c, 1, () => { trio(c, t, 600, 620); khidr(c, 740, 560, t); K.glow(c, 600, 620, 90, '#FFE6A8', 0.25 * A(t, d * 0.4, 1)); });
} });
S.push({ // 8 recitation 18:69 - the shore at evening
  cam: (p) => [K.lerp(1.0, 1.06, E(p)), 640, K.lerp(440, 390, E(p)), 0], draw(c, t, d, p) {
  seas(c, t, K.lerp(0.8, 0.45, E(p)), { sun: [K.lerp(1100, 1160, E(p)), K.lerp(260, 420, E(p))], rock: true });
  K.par(c, 1, () => { trio(c, t, 600, 620); khidr(c, 740, 560, t); });
} });
S.push({ // 9 do not ask until I tell you; they boarded a ship that carried them free; he took out a plank
  cam: (p) => [K.lerp(1.0, 1.12, E(p)), 640, 440, 0], draw(c, t, d) {
  const kh = B(9, 'فخرقَها', d * 0.85);
  seas(c, t, 0.9, { sun: [1060, 180] });
  K.par(c, 0.55, () => { ship(c, 640, 470, 1.4, t, 0.9, { hole: A(t, kh - 0.3, 0.8) }); K.presence(c, 600, 430, 18, t, 1); khidr(c, 700, 428, t); KIT.crowd(c, 23101, 3, 520, 760, 470, 0.7, t, {}); });
} });
S.push({ // 10 Musa: did you hole it to drown its people? - reminded of his condition, he apologised
  cam: (p) => [K.lerp(1.3, 1.4, E(p)), 650, 470, 0], draw(c, t, d) {
  seas(c, t, 0.85, { sun: [1080, 200] });
  K.par(c, 0.55, () => { ship(c, 640, 470, 1.4, t, 0.85, { hole: 1 }); K.presence(c, 600, 430, 18 + 3 * Math.sin(t * 5) * (1 - A(t, d * 0.6, 1)), t, 1); khidr(c, 700, 428, t); });
} });
S.push({ // 11 then Musa saw a harsher thing and objected (18:74-76 - NOT drawn): an empty shore, the lights stop, then walk on
  cam: (p) => [1.0, 640, 430, 0], draw(c, t, d) {
  seas(c, t, 0.7, { sun: [1100, 300], cols: ['#5A5A7A', '#B08A8A', '#E8C09A'] });
  K.par(c, 1, () => { const go = A(t, d * 0.6, d * 0.4, (x) => x); K.presence(c, 560 + 300 * go, 620, 24, t, 1); khidr(c, 680 + 300 * go, 616, t); });
} });
S.push({ // 12 a town refused them hospitality; a wall about to fall - he set it straight
  cam: (p) => [K.lerp(1.0, 1.15, E(p)), 760, 480, 0], draw(c, t, d) {
  const qm = B(12, 'فأقامَهُ', d * 0.8);
  village(c, t, 0.85, { sun: [1080, 220] });
  K.par(c, 1, () => { wall(c, 800, 680, 1 - A(t, qm - 0.3, 1.2), 0.9); K.presence(c, 560, 620, 24, t, 1); khidr(c, 700, 616, t); KIT.crowd(c, 23102, 3, 1060, 1180, 650, 1.0, t, { face: -1 }); });
} });
S.push({ // 13 you could have taken a wage for it - this is our parting; I will tell you what you could not bear
  cam: (p) => [K.lerp(1.15, 1.25, E(p)), 680, 520, 0], draw(c, t, d) {
  village(c, t, 0.65, { sun: [1100, 340] });
  K.par(c, 1, () => { wall(c, 800, 680, 0, 0.7); K.presence(c, 560, 620, 24, t, 1); khidr(c, 700, 616, t); });
} });
S.push({ // 14 the ship belonged to poor workers; a king seized every sound ship - I flawed it to save it for them
  cam: (p) => [1.0, 640, 430, 0], draw(c, t, d) {
  seas(c, t, 0.9, { sun: [1060, 180] });
  K.par(c, 0.45, () => { for (let i = 0; i < 3; i++) ship(c, 1000 + i * 150, 440, 0.7, t + i, 0.6, {}); });
  K.par(c, 0.55, () => { const k = A(t, d * 0.3, d * 0.6, (x) => x); ship(c, 400 + 500 * k, 470, 1.1, t, 0.9, { hole: 1 }); KIT.crowd(c, 23101, 3, 330 + 500 * k, 480 + 500 * k, 470, 0.6, t, {}); });
} });
S.push({ // 15 the wall belonged to two orphan boys; beneath it their treasure; their father was righteous
  cam: (p) => [K.lerp(1.1, 1.25, E(p)), 860, 560, 0], draw(c, t, d) {
  const kz = B(15, 'كنزٌ', d * 0.35);
  village(c, t, 0.9, { sun: [1080, 200] });
  K.par(c, 1, () => { wall(c, 800, 680, 0, 0.95, A(t, kz - 0.3, 1)); KIT.crowd(c, 23103, 2, 1080, 1140, 690, 0.75, t, { face: -1 }); K.glow(c, 880, 600, 160, '#FFE6A8', 0.15 * A(t, d * 0.6, 1)); });
} });
S.push({ // 16 I did none of it of my own accord - it was Allah's command
  cam: (p) => [K.lerp(1.0, 1.1, E(p)), 640, K.lerp(420, 360, E(p)), 0], draw(c, t, d) {
  seas(c, t, 0.75, { sun: [1100, 300] });
  K.par(c, 1, () => { K.presence(c, 560, 620, 24, t, 1); khidr(c, 700, 616, t); K.rays(c, 640, -40, 8, 760, Math.PI * 0.42, Math.PI * 0.58, '#FFF6DA', 0.12 * A(t, d * 0.3, 1.2), t); });
} });
S.push({ cam: (p) => [K.lerp(1.1, 1.02, E(p)), 640, K.lerp(390, 362, E(p)), 0], draw(c, t, d, p) {
  KIT.lesson(c, t, p, { seed: 23104 });
} });
window.STORY_SCENES = S;
})();
