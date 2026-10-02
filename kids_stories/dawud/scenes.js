// Dawud, peace be upon him, and Jalut. VISUALS ONLY.
// Narration: docs/kids_stories/dawud_narration.md (2:246-251, 34:10-11,
// 21:79-80 + al-Muyassar). Dawud and their prophet are NEVER drawn - lights.
// Talut is not drawn (caution) - a steady light ahead of the army. Soldiers are
// flat featureless figures; Jalut a large dark featureless shape far off. NO
// fighting is drawn: the victory is dust settling and a banner raised.
'use strict';
(() => {
const { W, H } = K;
const TAU = Math.PI * 2;
const E = K.easeInOut, B = K.beat, A = K.after;
const TALUT = '#FFF0D0';
const plain = (c, t, light, o = {}) => {
  KIT.sky(c, t, light, { sun: o.sun, moon: o.moon, cols: o.cols, seed: 171 });
  KIT.land(c, light, { seed: 17.1, farCol: '#A89A8A', midCol: '#A8A070' });
  K.par(c, 0.8, () => {
    KIT.ground(c, 540, light, '#B8B07A');
    if (o.river) { c.fillStyle = K.tone('#6EB0C0', light); c.fillRect(-420, 600, W + 840, 40); c.strokeStyle = K.rgba('#E8F8FA', 0.5); c.lineWidth = 2; for (let i = 0; i < 8; i++) { const x = K.mod(i * 200 + t * 30, W + 300) - 150; c.beginPath(); c.moveTo(x, 618); c.lineTo(x + 40, 618); c.stroke(); } }
    if (o.town) KIT.town(c, light, 0, { seed: 17101, n: 18, ty: 545 });
  });
};
const talut = (c, x, y, t) => { c.save(); c.globalCompositeOperation = 'lighter'; K.glow(c, x, y, 50, TALUT, 0.25); K.glow(c, x, y, 18, '#FFFFFF', 0.45); c.restore(); };
const army = (c, t, seed, n, x0, x1, gy, o = {}) => KIT.crowd(c, seed, n, x0, x1, gy, 1.0, t, { robes: ['#5E6A7A', '#6E5E4E', '#4E5A4A'], ...o });
const banner = (c, x, y, k, t) => { if (k <= 0) return; c.strokeStyle = '#6B4A34'; c.lineWidth = 4; c.beginPath(); c.moveTo(x, y); c.lineTo(x, y - 120 * k); c.stroke(); c.fillStyle = '#E8DCC4'; c.beginPath(); c.moveTo(x, y - 120 * k); for (let i = 0; i <= 10; i++) c.lineTo(x + i * 7, y - 120 * k + 4 * Math.sin(t * 3 + i)); c.lineTo(x + 70, y - 120 * k + 40); for (let i = 10; i >= 0; i--) c.lineTo(x + i * 7, y - 120 * k + 40 + 4 * Math.sin(t * 3 + i)); c.fill(); };

const S = [];
S.push({ // 1 after Musa, Bani Isra'il asked their prophet for a king, to fight those who drove them out
  cam: (p) => [K.lerp(1.0, 1.1, E(p)), 640, 440, 0], draw(c, t, d) {
  plain(c, t, 0.85, { sun: [1080, 200], town: true });
  K.par(c, 1, () => { army(c, t, 17102, 14, 600, 1180, 660, { face: -1 }); K.presence(c, 420, 620, 28, t, 1); });
} });
S.push({ // 2 Allah has chosen Talut as your king
  cam: (p) => [K.lerp(1.1, 1.2, E(p)), 520, 500, 0], draw(c, t, d) {
  const tl = B(2, 'طالوتَ', d * 0.7);
  plain(c, t, 0.85, { sun: [1080, 200], town: true });
  K.par(c, 1, () => { army(c, t, 17102, 14, 700, 1180, 660, { face: -1 }); K.presence(c, 360, 620, 28, t, 1); talut(c, 520, 620, t); K.glow(c, 520, 620, 120, '#FFF6DA', 0.25 * A(t, tl - 0.3, 1)); });
} });
S.push({ // 3 how can he be king with no great wealth? Allah chose him and increased him in knowledge and strength
  cam: (p) => [K.lerp(1.2, 1.1, E(p)), 640, 480, 0], draw(c, t, d) {
  plain(c, t, 0.85, { sun: [1080, 200], town: true });
  K.par(c, 1, () => { army(c, t, 17102, 14, 700, 1180, 660, { face: -1, shake: 0.4 * (1 - A(t, d * 0.5, 1)), point: 0.4 * (1 - A(t, d * 0.5, 1)) }); K.presence(c, 360, 620, 28, t, 1); talut(c, 520, 620, t); K.rays(c, 520, 610, 8, 520, -Math.PI * 0.8, -Math.PI * 0.2, '#FFF0C8', 0.1 * A(t, d * 0.5, 1), t); });
} });
S.push({ // 4 Talut set out: Allah will test you with a river - whoever drinks is not with me, except a handful
  cam: (p) => [1.04, K.lerp(500, 760, E(p)), 440, 0], draw(c, t, d) {
  plain(c, t, 0.95, { sun: [640, 130], river: true });
  K.par(c, 1, () => { const k = A(t, 0, d, (x) => x); talut(c, 260 + 300 * k, 560, t); army(c, t, 17103, 20, -200 + 300 * k, 260 + 300 * k, 580, { face: 1, walk: 1 }); });
} });
S.push({ // 5 at the river most drank; only a few endured their thirst
  cam: (p) => [K.lerp(1.1, 1.2, E(p)), 640, 520, 0], draw(c, t, d) {
  plain(c, t, 0.95, { sun: [640, 130], river: true });
  K.par(c, 1, () => {
    army(c, t, 17104, 16, 120, 900, 600, { face: 1, robes: ['#8A8070'] });
    c.save(); c.globalAlpha *= 0.95; army(c, t, 17105, 4, 940, 1100, 590, { face: 1 }); c.restore();
    talut(c, 1020, 560, t);
    K.spray(c, t, 17106, 30, 120, 900, 606, 20, '#DFF4F8', 0.6);
  });
} });
S.push({ // 6 Talut crossed with the faithful few; they saw Jalut's great army
  cam: (p) => [1.0, 640, 420, 0], draw(c, t, d) {
  plain(c, t, 0.75, { sun: [1100, 280] });
  K.par(c, 0.55, () => { c.fillStyle = K.rgba('#2E2A30', 0.85); c.beginPath(); c.ellipse(1000, 470, 30, 60, 0, 0, TAU); c.fill(); c.beginPath(); c.arc(1000, 400, 22, 0, TAU); c.fill(); for (let i = 0; i < 40; i++) { const x = 700 + (i % 20) * 30, y = 500 + Math.floor(i / 20) * 14; c.fillStyle = K.rgba('#3A3438', 0.7); c.fillRect(x, y - 30, 10, 30); c.beginPath(); c.arc(x + 5, y - 36, 5, 0, TAU); c.fill(); } });
  K.par(c, 1, () => { army(c, t, 17105, 6, 120, 400, 660, { face: 1 }); talut(c, 440, 620, t); });
} });
S.push({ // 7 how many a small patient band has overcome a large one by Allah's leave; Allah is with the patient
  cam: (p) => [K.lerp(1.15, 1.25, E(p)), 330, 540, 0], draw(c, t, d) {
  plain(c, t, 0.75, { sun: [1100, 280] });
  K.par(c, 1, () => { army(c, t, 17105, 6, 120, 400, 660, { face: 1 }); talut(c, 440, 620, t); K.rays(c, 280, 620, 9, 600, -Math.PI * 0.85, -Math.PI * 0.15, '#FFF0C8', 0.1 * A(t, d * 0.4, 1), t); });
} });
S.push({ // 8 they prayed: pour patience on us, make our feet firm, give us victory
  cam: (p) => [K.lerp(1.1, 1.0, E(p)), 400, 480, 0], draw(c, t, d) {
  plain(c, t, 0.6, { sun: [1120, 380], cols: ['#3F3B6C', '#C07A6A', '#F2C08B'] });
  K.par(c, 1, () => { army(c, t, 17105, 6, 120, 400, 660, { face: 1 }); talut(c, 440, 620, t); K.rays(c, 280, 620, 7, 520, -Math.PI * 0.62, -Math.PI * 0.38, '#FFE6B0', 0.1, t); });
} });
S.push({ // 9 recitation 2:250 - dawn over the small band
  cam: (p) => [K.lerp(1.0, 1.08, E(p)), 640, K.lerp(440, 380, E(p)), 0], draw(c, t, d, p) {
  const l = K.lerp(0.4, 0.85, E(p));
  plain(c, t, l, { sun: [900, K.lerp(500, 220, E(p))], cols: KIT.skyAt(l) });
  K.par(c, 1, () => { army(c, t, 17105, 6, 120, 400, 660, { face: 1 }); talut(c, 440, 620, t); });
} });
S.push({ // 10 they defeated them by Allah's leave, and Dawud killed Jalut - told, not drawn: dust settles, a banner rises
  cam: (p) => [K.lerp(1.0, 1.1, E(p)), 640, 440, 0], draw(c, t, d) {
  const qt = B(10, 'وقتلَ', d * 0.5);
  plain(c, t, 0.85, { sun: [1000, 180] });
  K.par(c, 1.05, () => K.dust(c, t, 17107, 80, '#D8C8A8', 0.6 * (1 - A(t, qt - 0.6, 2)), -100, W + 100, 300, 720, 30));
  K.par(c, 1, () => { army(c, t, 17105, 6, 360, 640, 660, { face: 1 }); K.presence(c, 720, 615, 22, t, A(t, qt - 0.4, 1)); banner(c, 680, 640, A(t, qt + 0.4, 1.2), t); });
} });
S.push({ // 11 Allah gave Dawud kingship and prophethood afterwards, and taught him
  cam: (p) => [K.lerp(1.1, 1.2, E(p)), 640, 480, 0], draw(c, t, d) {
  plain(c, t, 0.95, { sun: [1000, 160], town: true });
  K.par(c, 1, () => { K.presence(c, 640, 615, 28, t, 1); K.rays(c, 640, 600, 12, 700, -Math.PI * 0.95, -Math.PI * 0.05, '#FFF0C8', 0.12 * A(t, d * 0.2, 1.5), t); });
} });
S.push({ // 12 the mountains and the birds glorified with him - echo rings and birds in rows
  cam: (p) => [1.0, 640, 380, 0], draw(c, t, d) {
  KIT.sky(c, t, 0.9, { sun: [1060, 150], seed: 172 });
  K.par(c, 0.4, () => { // rugged mountains (not pyramids)
    for (const [cx, hgt, col, ph] of [[300, 300, '#8A7A6A', 1], [1000, 340, '#8E7E6E', 2]]) {
      c.fillStyle = col; c.beginPath(); c.moveTo(cx - 420, 580);
      for (let x = cx - 420; x <= cx + 420; x += 10) c.lineTo(x, 560 - hgt * Math.exp(-Math.pow((x - cx) / 210, 2)) + 18 * Math.sin(x * 0.04 + ph) + 9 * Math.sin(x * 0.11 + ph));
      c.lineTo(cx + 420, 580); c.fill();
    }
  });
  K.par(c, 0.8, () => KIT.ground(c, 560, 0.9, '#A9B87C'));
  K.par(c, 1, () => {
    K.presence(c, 640, 620, 26, t, 1);
    for (let i = 0; i < 3; i++) { const q = K.fract(t * 0.35 + i / 3); c.strokeStyle = K.rgba('#FFF6DA', 0.5 * (1 - q)); c.lineWidth = 2.5; c.beginPath(); c.ellipse(640, 600, 60 + q * 640, 20 + q * 220, 0, Math.PI, TAU); c.stroke(); }
  });
  K.par(c, 0.2, () => K.birds(c, t, 17108, 18, 640, 170, 500, 0, 10, '#4A3A40', 0.75));
} });
S.push({ // 13 Allah softened iron for him like dough; he made armour that protects
  cam: (p) => [K.lerp(1.3, 1.45, E(p)), 640, 560, 0], draw(c, t, d) {
  plain(c, t, 0.8, { sun: [1100, 280] });
  K.par(c, 1, () => {
    K.presence(c, 520, 615, 24, t, 1);
    const k = A(t, d * 0.2, d * 0.6, (x) => x);
    K.glow(c, 680, 620, 70, '#FF9A4A', 0.3);
    c.strokeStyle = '#8A8A96'; c.lineWidth = 3;
    const rows = Math.floor(k * 6);
    for (let r = 0; r <= rows; r++) for (let i = 0; i < 9; i++) { c.beginPath(); c.arc(640 + i * 12 + (r % 2) * 6, 570 + r * 11, 6, 0, TAU); c.stroke(); }
  });
} });
S.push({ cam: (p) => [K.lerp(1.1, 1.02, E(p)), 640, K.lerp(390, 362, E(p)), 0], draw(c, t, d, p) {
  KIT.lesson(c, t, p, { seed: 17109 });
} });
window.STORY_SCENES = S;
})();
