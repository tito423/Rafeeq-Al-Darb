// Story - Zakariya and Yahya, peace be upon them. VISUALS ONLY.
// Narration: docs/kids_stories/zakariya_narration.md (19:2-15, 3:37-41,
// 21:89-90 + al-Muyassar). Zakariya and Yahya are NEVER drawn - warm lights
// (Yahya a smaller one). Angels are never drawn: the good news is a light
// coming down. Maryam is not drawn (caution, see the doc): the mihrab and a
// dish of provision only - no particular fruit. Beats fall back to d * f.
'use strict';
(() => {
const { W, H } = K;
const TAU = Math.PI * 2;
const E = K.easeInOut, B = K.beat, A = K.after;
// inside the place of worship: a stone wall, an arched niche, a hanging lamp
const mihrab = (c, t, light, o = {}) => {
  K.par(c, 0, () => {
    const g = c.createLinearGradient(0, 0, 0, H);
    g.addColorStop(0, K.tone('#C9A985', light)); g.addColorStop(1, K.tone('#A88660', light));
    c.fillStyle = g; c.fillRect(-420, -420, W + 840, H + 840);
    c.strokeStyle = K.rgba('#7A5A40', 0.25); c.lineWidth = 2;
    for (let y = 40; y < 620; y += 46) for (let x = (y / 46) % 2 ? -30 : 10; x < W + 60; x += 92) c.strokeRect(x, y, 92, 46);
  });
  K.par(c, 0.6, () => {
    // the niche
    c.fillStyle = K.tone('#8A6A4C', light);
    c.beginPath(); c.moveTo(520, 600); c.lineTo(520, 300); c.arc(640, 300, 120, Math.PI, 0); c.lineTo(760, 600); c.fill();
    c.fillStyle = K.tone('#6E5038', light);
    c.beginPath(); c.moveTo(545, 600); c.lineTo(545, 305); c.arc(640, 305, 95, Math.PI, 0); c.lineTo(735, 600); c.fill();
    // window light
    if (o.win) { K.rays(c, 1150, 120, 5, 700, Math.PI * 0.62, Math.PI * 0.8, '#FFF0C8', 0.07 * o.win, t); c.fillStyle = K.rgba('#FFF2CF', 0.8 * o.win); c.fillRect(1110, 90, 70, 100); }
  });
  K.par(c, 0.85, () => {
    // lamp on a chain
    c.strokeStyle = K.tone('#5A4030', light); c.lineWidth = 2; c.beginPath(); c.moveTo(640, -40); c.lineTo(640, 200); c.stroke();
    c.fillStyle = K.tone('#B88A3C', light); c.beginPath(); c.moveTo(615, 200); c.lineTo(665, 200); c.lineTo(650, 232); c.lineTo(630, 232); c.closePath(); c.fill();
    K.glow(c, 640, 220, 70, '#FFC869', 0.35 * (o.lamp ?? 1) * (0.9 + 0.1 * Math.sin(t * 3)));
    // floor
    c.fillStyle = K.tone('#9A7A58', light); c.fillRect(-420, 600, W + 840, 600);
    c.fillStyle = K.tone('#7E4E3E', light); c.fillRect(420, 612, 440, 46); // a mat
  });
};
const dish = (c, x, y, a, t) => {
  if (a <= 0.01) return;
  c.save(); c.globalAlpha *= a;
  K.glow(c, x, y - 10, 60, '#FFE6A8', 0.3);
  c.fillStyle = '#C8A06A'; c.beginPath(); c.ellipse(x, y, 46, 12, 0, 0, TAU); c.fill();
  const cols = ['#C8553D', '#E0A030', '#7AA040', '#B04A6A', '#E8C060'];
  for (let i = 0; i < 9; i++) { c.fillStyle = cols[i % 5]; c.beginPath(); c.arc(x - 30 + (i % 5) * 15, y - 8 - Math.floor(i / 5) * 10, 7, 0, TAU); c.fill(); }
  c.restore();
};
const outside = (c, t, light, o = {}) => {
  KIT.sky(c, t, light, { sun: o.sun, moon: o.moon, seed: 41 });
  KIT.land(c, light, { seed: 4.1, farCol: '#B9A08C', midCol: '#B8956E' });
  KIT.town(c, light, o.glow || 0, { seed: 4102, n: 18, x0: 60, x1: 1220, ty: 545 });
};

const s1 = { // Zakariya took care of Maryam and housed her in his place of worship
  cam: (p) => [K.lerp(1.0, 1.1, E(p)), 640, K.lerp(380, 420, E(p)), 0], draw(c, t, d) {
  mihrab(c, t, 0.9, { win: 1 });
  K.par(c, 1, () => { K.presence(c, 380, 610, 28, t, 1); K.glow(c, 640, 560, 90, '#FFF6E0', 0.25); });
} };
const s2 = { // whenever he entered he found provision with her: it is from Allah
  cam: (p) => [K.lerp(1.15, 1.3, E(p)), 640, K.lerp(480, 540, E(p)), 0], draw(c, t, d) {
  const rz = B(2, 'رزقًا', d * 0.3), al = B(2, 'اللهِ', d * 0.9);
  mihrab(c, t, 0.9, { win: 1 });
  K.par(c, 1, () => {
    dish(c, 640, 600, A(t, rz - 0.4, 1), t);
    K.presence(c, 430, 610, 26, t, 1);
    K.rays(c, 640, 590, 7, 380, -Math.PI * 0.85, -Math.PI * 0.15, '#FFF0C8', 0.1 * A(t, al - 0.4, 1), t);
  });
} };
const s3 = { // he had grown old, bones weak, head white; his wife bore no children
  cam: (p) => [1.05, K.lerp(560, 700, E(p)), 410, 0], draw(c, t, d) {
  outside(c, t, 0.55, { sun: [K.lerp(1080, 1160, d > 0 ? t / d : 0), 330], glow: 0.3 });
  K.par(c, 1, () => {
    K.presence(c, 640, 620, 24, t, 0.85);
    // autumn leaves drifting: time and age, no figure
    const r = K.rng(4103);
    for (let i = 0; i < 18; i++) { const q = K.fract(t * 0.08 + r()); c.fillStyle = K.rgba(['#C88A4A', '#B86A3A', '#D8A860'][i % 3], 0.8 * Math.sin(q * Math.PI)); c.save(); c.translate(r() * W + Math.sin(t + i) * 30, -20 + q * 700); c.rotate(t * 2 + i); c.fillRect(-5, -2.5, 10, 5); c.restore(); }
  });
} };
const s4 = { // seeing what Allah gave Maryam, he called his Lord in secret
  cam: (p) => [K.lerp(1.1, 1.25, E(p)), 640, 470, 0], draw(c, t, d) {
  const sr = B(4, 'سِرًّا', d * 0.65);
  mihrab(c, t, 0.45, { lamp: 1 });
  K.par(c, 1, () => {
    dish(c, 840, 604, 0.5, t);
    K.presence(c, 640, 610, 26, t, 1);
    K.rays(c, 640, 600, 6, 520, -Math.PI * 0.6, -Math.PI * 0.4, '#FFE6B0', 0.07 * A(t, sr - 0.3, 1.2), t);
  });
} };
const s5 = { // recitation 21:89 - the lamp and the light, still
  cam: (p) => [K.lerp(1.05, 1.18, E(p)), 640, K.lerp(420, 380, E(p)), 0], draw(c, t, d) {
  mihrab(c, t, 0.4, { lamp: 1 });
  K.par(c, 1, () => {
    K.presence(c, 640, 610, 26, t, 1);
    for (let i = 0; i < 4; i++) { const q = K.fract(t * 0.08 + i / 4); K.glow(c, 640 + Math.sin(i * 2.3 + t * 0.3) * 24, 600 - q * 500, 9, '#FFE9B8', 0.5 * Math.sin(q * Math.PI)); }
  });
} };
const s6 = { // standing in prayer, the good news came: a son named Yahya - a light comes down
  cam: (p) => [K.lerp(1.0, 1.12, E(p)), 640, K.lerp(360, 420, E(p)), 0], draw(c, t, d) {
  const bs = B(6, 'البُشرى', d * 0.45), yh = B(6, 'يحيى', d * 0.9);
  mihrab(c, t, 0.5, { lamp: 1 });
  K.par(c, 1, () => {
    const k = A(t, bs - 0.6, 1.4);
    K.rays(c, 640, -60, 9, 760, Math.PI * 0.4, Math.PI * 0.6, '#FFF6DA', 0.16 * k, t);
    K.glow(c, 640, K.lerp(-40, 360, k), 90, '#FFFFFF', 0.35 * k);
    K.presence(c, 640, 610, 26 + 6 * k, t, 1);
    K.presence(c, 760, 560, 12, t, A(t, yh - 0.3, 1));
  });
} };
const s7 = { // no one was named with that name before - a small light among the stars
  cam: (p) => [K.lerp(1.0, 1.1, E(p)), 640, 360, 0], draw(c, t, d) {
  outside(c, t, 0.22, { moon: [1050, 130], glow: 0.7 });
  K.par(c, 0.2, () => K.presence(c, 640, 220, 14, t, A(t, d * 0.2, 1.2)));
} };
const s8 = { // he wondered, joyful: how, when I am old and my wife bears no children?
  cam: (p) => [K.lerp(1.2, 1.3, E(p)), 640, 500, 0], draw(c, t, d) {
  mihrab(c, t, 0.55, { lamp: 1 });
  K.par(c, 1, () => {
    K.presence(c, 640, 610, 28 + 4 * Math.sin(t * 3) * A(t, d * 0.2, 1), t, 1);
    K.dust(c, t, 4104, 30, '#FFF0C8', 0.5, 520, 760, 440, 640, 1);
  });
} };
const s9 = { // that is easy for Allah: He created you before when you were nothing
  cam: (p) => [K.lerp(1.0, 1.2, E(p)), 640, K.lerp(360, 300, E(p)), 0], draw(c, t, d) {
  outside(c, t, 0.2, { moon: [1050, 130], glow: 0.6 });
  K.par(c, 0.1, () => { const k = A(t, d * 0.55, 2); K.stars(c, 4105, 160, 0.9 * k, t, 520); });
  K.par(c, 1, () => K.presence(c, 640, 620, 24, t, 1));
} };
const s10 = { // his sign: three days unable to speak to people, though healthy
  cam: (p) => [1.04, 640, 410, 0], draw(c, t, d) {
  const u = A(t, d * 0.25, d * 0.65, (x) => x) * 3;
  const ph = K.fract(u + 0.25);
  const light = 0.15 + 0.75 * K.smooth(0.5 + Math.sin(ph * TAU) * 0.9);
  outside(c, t, light, { sun: ph < 0.5 ? [K.lerp(-60, W + 60, ph * 2), 200] : [-200, -200], moon: ph >= 0.5 ? [K.lerp(-60, W + 60, ph * 2 - 1), 170] : null, glow: K.clamp(1 - light * 1.5) });
  K.par(c, 1, () => K.presence(c, 640, 620, 24, t, 1));
} };
const s11 = { // he came out to his people and signed to them: glorify Allah morning and evening
  cam: (p) => [K.lerp(1.08, 1.0, E(p)), K.lerp(700, 620, E(p)), 420, 0], draw(c, t, d) {
  const sb = B(11, 'سبِّحوا', d * 0.6);
  outside(c, t, K.lerp(0.75, 0.5, A(t, sb, d - sb)), { sun: [K.lerp(1080, 1180, A(t, sb, d - sb)), K.lerp(170, 360, A(t, sb, d - sb))], glow: 0.3 });
  K.par(c, 1, () => {
    K.presence(c, 560, 625, 26, t, 1);
    KIT.crowd(c, 4106, 12, 700, 1180, 655, 1.0, t, { face: -1 });
    K.rays(c, 560, 615, 5, 260, -Math.PI * 0.2, Math.PI * 0.05, '#FFF0C8', 0.12 * A(t, sb - 0.5, 0.8) * (1 - A(t, sb + 2, 1)), t);
  });
  KIT.foreGrass(c, t, 0.8);
} };
const s12 = { // Yahya was born; while young he was told to take the Torah with strength
  cam: (p) => [K.lerp(1.1, 1.22, E(p)), 640, 470, 0], draw(c, t, d) {
  const tw = B(12, 'التوراةَ', d * 0.55);
  mihrab(c, t, 0.85, { win: 1 });
  K.par(c, 1, () => {
    // a scroll opening on a low stand - no writing drawn
    const k = A(t, tw - 0.4, 1.2);
    c.save(); c.globalAlpha *= K.clamp(k * 3);
    c.fillStyle = '#7A5A40'; c.fillRect(560, 560, 160, 12); c.fillRect(580, 572, 10, 40); c.fillRect(690, 572, 10, 40);
    const half = 8 + 62 * k;
    c.fillStyle = '#EFE3C4'; c.fillRect(640 - half, 520, half * 2, 40);
    c.fillStyle = '#B08A5C';
    for (const x of [640 - half, 640 + half]) { c.beginPath(); c.ellipse(x, 540, 9, 24, 0, 0, TAU); c.fill(); }
    K.glow(c, 640, 540, 90, '#FFF2C8', 0.25 * k);
    c.restore();
    K.presence(c, 640, 560, 16, t, 1);
    K.presence(c, 400, 610, 24, t, 0.8);
  });
} };
const s13 = { // wisdom while young, merciful, obedient
  cam: (p) => [K.lerp(1.0, 1.08, E(p)), 640, 400, 0], draw(c, t, d) {
  outside(c, t, 0.95, { sun: [1060, 150] });
  K.par(c, 1, () => {
    K.presence(c, 640, 620, 18, t, 1);
    K.animal(c, 'sheep', 760, 650, 0.6, t * 2, 0); K.animal(c, 'sheep', 820, 660, 0.55, t * 2 + 1, 0);
  });
  K.par(c, 0.12, () => K.birds(c, t, 4107, 6, 400, 170, 160, 26, 9, '#4A3A40', 0.6));
  KIT.foreGrass(c, t, 0.95);
} };
const s14 = { // dutiful to his parents - a small light beside his father's, by the lit home
  cam: (p) => [K.lerp(1.18, 1.05, E(p)), 640, 460, 0], draw(c, t, d) {
  outside(c, t, 0.7, { sun: [1100, 300], glow: 0.2 });
  K.par(c, 1, () => {
    K.presence(c, 560, 620, 24, t, 1);
    K.presence(c, 640, 630, 14, t, 1);
    // the family home, its door lit (the mother is not drawn - caution, see the doc)
    K.house(c, 700, 640, 110, 80, K.tone('#E2BC8C', 0.7), K.tone('#B98E64', 0.7), '#FFC869', 0.9);
    K.glow(c, 735, 615, 70, '#FFC869', 0.3);
  });
  KIT.foreGrass(c, t, 0.7);
} };
const s15 = { cam: (p) => [K.lerp(1.1, 1.02, E(p)), 640, K.lerp(390, 362, E(p)), 0], draw(c, t, d, p) {
  KIT.lesson(c, t, p, { seed: 4109 });
} };
window.STORY_SCENES = [s1, s2, s3, s4, s5, s6, s7, s8, s9, s10, s11, s12, s13, s14, s15];
})();
