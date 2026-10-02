// Story 7 - Hud, peace be upon him, and the wind. VISUALS ONLY.
// Narration: docs/kids_stories/hud_narration.md (11:50-58, 46:21-25, 69:6-8).
// Hud is NEVER drawn - only a warm light. 'Ad are flat featureless figures; their
// gods are plain carved stones. Nobody is drawn struck down: wind, sand, and in
// the end empty houses only. The "seven nights and eight days" pass with the
// sky's contrast softened (no flashing).
'use strict';
(() => {
const { W, H } = K;
const TAU = Math.PI * 2;
const E = K.easeInOut, B = K.beat, A = K.after;
const dunes = (c, light, o = {}) => {
  K.par(c, 0.3, () => { K.ridge(c, 400, 90, 2.2, 0.5, K.tone('#E0B07A', light)); K.haze(c, 300, 460, o.haze || '#F6DCB0', 0.3); });
  K.par(c, 0.55, () => K.ridge(c, 470, 70, 5.3, 0.7, K.tone('#D49E66', light)));
};
const adTown = (c, light, glow = 0, buried = 0) => K.par(c, 0.8, () => {
  KIT.ground(c, 530, light, '#E0B47E');
  K.town(c, 4621, 18, 160, 1120, 548, 1.15, light, glow);
  if (buried > 0) {   // sand drifts over the empty houses
    c.fillStyle = K.tone('#E6BC86', light);
    c.beginPath(); c.moveTo(-420, 760);
    for (let x = -420; x <= W + 420; x += 16) c.lineTo(x, 560 - buried * (40 + 30 * Math.sin(x * 0.012) + 14 * Math.sin(x * 0.037)));
    c.lineTo(W + 420, 760); c.closePath(); c.fill();
  }
});
const stones = (c, light) => {
  for (const [k, x, h] of [['slab', 980, 110], ['obelisk', 1060, 150], ['boulder', 1140, 100]]) K.stone(c, k, x, 650, h, K.tone('#9C8A78', light), K.tone('#C7AE8E', light), K.tone('#6E5E54', light));
};
const s1 = { cam: (p) => [K.lerp(1.0, 1.14, E(p)), K.lerp(520, 700, E(p)), K.lerp(360, 410, E(p)), 0], draw(c, t, d, p) {
  const rm = B(1, 'رمال', 4.0);
  KIT.sky(c, t, 0.95, { sun: [1080, 150] });
  dunes(c, 0.95);
  adTown(c, 0.95);
  K.par(c, 1.1, () => K.dust(c, t, 2901, 30, '#F6DCB0', 0.4 + 0.2 * A(t, rm, 1), -100, W + 100, 450, 720, 14));
  KIT.foreGrass(c, t, 0.9);
} };
const s2 = { cam: (p) => [K.lerp(1.1, 1.2, E(p)), 640, 440, 0], draw(c, t, d, p) {
  const hd = B(2, 'هود', 2.8);
  KIT.sky(c, t, 0.95, { sun: [1080, 150] }); dunes(c, 0.95); adTown(c, 0.95);
  K.par(c, 1, () => { KIT.crowd(c, 2902, 10, 700, 1150, 660, 1.0, t, { face: -1 }); K.presence(c, 480, 630, 28, t, A(t, hd - 0.3, 1)); });
} };
const s3 = { cam: (p) => [1.2, K.lerp(600, 680, E(p)), 450, 0], draw(c, t, d, p) {
  KIT.sky(c, t, 0.94, { sun: [1080, 150] }); dunes(c, 0.94); adTown(c, 0.94);
  K.par(c, 1, () => { KIT.crowd(c, 2902, 10, 700, 1150, 660, 1.0, t, { face: -1 }); K.presence(c, 480, 630, 30, t, 1); });
} };
const s4 = { // ask forgiveness and repent: He will send you rain and add strength - shown as a hope, faded in
  cam: (p) => [K.lerp(1.15, 1.02, E(p)), 640, K.lerp(440, 390, E(p)), 0], draw(c, t, d, p) {
  const mt = B(4, 'المطر', 3.84), qw = B(4, 'قوة', 6.0);
  const hope = A(t, mt - 0.8, 1.2);
  KIT.sky(c, t, 0.94, { sun: [1080, 150], extra: () => { for (let i = 0; i < 5; i++) K.cloud(c, 200 + i * 220, 120 + (i % 2) * 30, 1.1, '#E8EEF4', 0.8 * hope); } });
  dunes(c, 0.94); adTown(c, 0.94);
  K.par(c, 1, () => {
    // the dream of it: soft rain and green fields over the sand
    c.save(); c.globalAlpha *= 0.85 * hope;
    c.fillStyle = '#9AC27A'; c.fillRect(-420, 610, W + 840, 200);
    for (let i = 0; i < 9; i++) K.shrub(c, 80 + i * 140, 620, 1.2, '#6E9A48');
    c.restore();
    K.rain(c, t, 2903, 120, 0.3 * hope, -30, 700, 18, '#E0ECF6', 1.5);
    K.presence(c, 480, 630, 28 + 8 * A(t, qw - 0.3, 0.6), t, 1);
  });
} };
const s5 = { // they: we will not leave our gods for your word
  cam: (p) => [1.18, K.lerp(820, 900, E(p)), 450, 0], draw(c, t, d, p) {
  const ln = B(5, 'لن', 1.04);
  KIT.sky(c, t, 0.9, { sun: [1080, 150] }); dunes(c, 0.9); adTown(c, 0.9);
  K.par(c, 1, () => {
    stones(c, 0.9);
    KIT.crowd(c, 2904, 10, 700, 1000, 670, 1.0, t, { face: 1, shake: 0.4 * A(t, ln, 0.4) });
    K.presence(c, 480, 630, 28, t, 1);
  });
} };
const s6 = { // Hud: I have put my trust in God, my Lord and yours
  cam: (p) => [K.lerp(1.2, 1.32, E(p)), 520, 460, 0], draw(c, t, d, p) {
  const tw = B(6, 'توكل', 2.0);
  KIT.sky(c, t, 0.9, { sun: [1080, 150], extra: () => K.rays(c, 480, 630, 10, 700, -Math.PI * 0.9, -Math.PI * 0.1, '#FFF0C8', 0.12 * A(t, tw, 1), t) });
  dunes(c, 0.9); adTown(c, 0.9);
  K.par(c, 1, () => K.presence(c, 480, 630, 28 + 12 * A(t, tw - 0.2, 0.8), t, 1));
} };
// a great dark cloud bank sweeping in from the right
const cloudBank = (c, t, k, dark = 1) => {
  for (let i = 0; i < 12; i++) {
    const x = K.lerp(1700, 0, k) + i * 140 + Math.sin(t * 0.5 + i) * 12, y = 90 + (i % 3) * 40;
    K.cloud(c, x, y, 2.0, K.mix('#7A7068', '#3E3640', dark), 0.95);
  }
};
const s7 = { // they saw a great cloud heading for their valleys and rejoiced: rain for us
  cam: (p) => [K.lerp(1.0, 1.08, E(p)), 640, K.lerp(360, 400, E(p)), 0], draw(c, t, d, p) {
  const sh = B(7, 'سحاب', 1.36), fr = B(7, 'فرحوا', 4.72);
  const k = A(t, sh - 0.6, d - sh + 2, (x) => x) * 0.6;
  KIT.sky(c, t, K.lerp(0.9, 0.7, k), { sun: [1080, 150], cloud: K.mix('#FFF8EC', '#5A5058', k * 1.4), extra: () => cloudBank(c, t, k, 0.6) });
  dunes(c, K.lerp(0.9, 0.7, k)); adTown(c, K.lerp(0.9, 0.7, k));
  K.par(c, 1, () => KIT.crowd(c, 2905, 14, 300, 1000, 670, 1.0, t, { face: 1, point: A(t, fr - 0.3, 0.4), shake: 0.5 * A(t, fr, 0.4) }));
} };
const s8 = { // recitation 46:24 - it is the wind they hastened: the cloud arrives, the wind starts
  cam: (p, t, d) => { const rh = B(8, 'ريح', 15.84); return [K.lerp(1.02, 1.1, E(p)), 640, 400, Math.sin(t * 7) * 0.006 * A(t, rh, 1)]; }, draw(c, t, d, p) {
  const rh = B(8, 'ريح', 15.84);
  const k = K.lerp(0.6, 1, A(t, 0, 12)), wind = A(t, rh - 1, 2);
  KIT.sky(c, t, K.lerp(0.7, 0.45, k), { cols: ['#3E3A48', '#6E6060', '#A08A70'], cloud: '#4A4048', extra: () => cloudBank(c, t, k, 1) });
  dunes(c, 0.55, { haze: '#C8A880' }); adTown(c, 0.55);
  K.par(c, 1.1, () => {
    K.rain(c, t, 2906, 140, 0.35 * wind, 1400, 60, 1.4, '#E8D0A8', 2.5);   // sand streaks driven sideways
    K.dust(c, t, 2907, 60, '#E8D0A8', 0.5 * wind, -100, W + 100, 300, 720, 200);
  });
  KIT.foreGrass(c, t, 0.5, 746, 1 + 3 * wind);
} };
const s9 = { // a bitter cold wind, seven nights and eight days without pause
  cam: (p) => [1.05, 640, 400, Math.sin(p * 40) * 0.006], draw(c, t, d, p) {
  const sb = B(9, 'سبع', 3.36);
  const u = A(t, sb - 0.6, d - sb, (x) => x) * 4;
  const l0 = K.smooth(0.5 + 0.9 * Math.sin(K.fract(u + 0.2) * TAU));
  const light = K.lerp(l0, 0.4, 0.75);   // contrast heavily softened: no flashing
  KIT.sky(c, t, light, { cols: KIT.skyAt(light).map((col) => K.mix(col, '#7A6A60', 0.5)), cloud: '#4A4048', extra: () => cloudBank(c, t, 1, 1) });
  dunes(c, light, { haze: '#C8A880' }); adTown(c, light);
  K.par(c, 1.1, () => { K.rain(c, t, 2906, 180, 0.4, 1600, 60, 1.4, '#E8D0A8', 2.5); K.dust(c, t, 2907, 70, '#E8D0A8', 0.55, -100, W + 100, 300, 720, 260); });
  KIT.foreGrass(c, t, 0.45, 746, 4);
} };
const s10 = { // it destroyed everything by its Lord's command; only their dwellings were seen
  cam: (p) => [K.lerp(1.08, 1.0, E(p)), K.lerp(700, 600, E(p)), 400, 0], draw(c, t, d, p) {
  const ms = B(10, 'مساكنهم', 5.52);
  const calm = A(t, 1.5, 3);
  KIT.sky(c, t, K.lerp(0.45, 0.65, calm), { cols: ['#5A5060', '#9A8070', '#D0A87A'], cloudA: 0.4 });
  dunes(c, 0.6); adTown(c, 0.6, 0, A(t, 0.5, ms));
  K.par(c, 1.1, () => K.dust(c, t, 2907, 40, '#E8D0A8', 0.5 * (1 - calm), -100, W + 100, 300, 720, 200 * (1 - calm)));
} };
const s11 = { // God saved Hud and those who believed with him
  cam: (p) => [K.lerp(1.1, 1.0, E(p)), 640, K.lerp(420, 390, E(p)), 0], draw(c, t, d, p) {
  const nj = B(11, 'أنجى', 0.32);
  KIT.sky(c, t, 0.95, { sun: [1000, 170], extra: () => K.rays(c, 1000, 170, 12, 1000, Math.PI * 0.55, Math.PI * 1.05, '#FFF0C8', 0.1 * A(t, nj, 1), t) });
  K.par(c, 0.4, () => K.ridge(c, 470, 50, 3.1, 0.8, '#C8A88E'));
  K.par(c, 1, () => {
    KIT.ground(c, 560, 0.95, '#B9C98A');
    for (const [x, h] of [[200, 170], [1080, 190]]) KIT.palm(c, x, 640, h, 0.95, t, x);
    KIT.crowd(c, 2908, 8, 520, 900, 650, 1.0, t, { face: -1 });
    K.presence(c, 440, 620, 30, t, 1);
  });
} };
const s12 = { cam: (p) => [K.lerp(1.1, 1.02, E(p)), 640, K.lerp(390, 362, E(p)), 0], draw(c, t, d, p) { KIT.lesson(c, t, p, { seed: 2909, far: '#D8B48A' }); } };
window.STORY_SCENES = [s1, s2, s3, s4, s5, s6, s7, s8, s9, s10, s11, s12];
})();
