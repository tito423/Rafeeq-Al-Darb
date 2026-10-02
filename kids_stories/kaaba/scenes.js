// Ibrahim and Isma'il build the Ka'ba; Hajar and Zamzam. VISUALS ONLY.
// Narration: docs/kids_stories/kaaba_narration.md (14:35-40, 2:125-129,
// 22:26-27 + al-Muyassar; Hajar/Zamzam from Sahih al-Bukhari 3364).
// Ibrahim and Isma'il are NEVER drawn - lights (Isma'il smaller). Hajar is not
// drawn (caution): a small light by the tent and between the hills. The angel
// is never drawn: water bursting in light. The Ka'ba is plain stone courses -
// no covering, no writing.
'use strict';
(() => {
const { W, H } = K;
const TAU = Math.PI * 2;
const E = K.easeInOut, B = K.beat, A = K.after;
// the valley of Makka: bare dark hills, sand; safa (left) and marwa (right)
const valley = (c, t, light, o = {}) => {
  KIT.sky(c, t, light, { sun: o.sun, moon: o.moon, cols: o.cols, seed: 91, cloudA: o.cloudA ?? 0.5 });
  K.par(c, 0.35, () => { K.ridge(c, 400, 70, 9.1, 0.9, K.tone('#7A6458', light)); K.haze(c, 300, 480, '#F2D8B8', 0.2); });
  K.par(c, 0.6, () => {
    for (const [x, w, h] of [[180, 420, 210], [1110, 440, 230]]) {
      c.fillStyle = K.tone('#6E5A4C', light); c.beginPath(); c.moveTo(x - w / 2, 560);
      for (let u = 0; u <= 1; u += 0.05) c.lineTo(x - w / 2 + u * w, 560 - h * Math.sin(u * Math.PI) * (0.85 + 0.15 * Math.sin(u * 17 + x)));
      c.closePath(); c.fill();
    }
  });
  K.par(c, 0.8, () => KIT.ground(c, 540, light, '#C9A877'));
};
const tent = (c, x, light) => {
  c.fillStyle = K.tone('#8A6A52', light); c.beginPath(); c.moveTo(x - 70, 620); c.lineTo(x, 540); c.lineTo(x + 70, 620); c.fill();
  c.fillStyle = K.tone('#5A4030', light); c.beginPath(); c.moveTo(x - 12, 620); c.lineTo(x, 575); c.lineTo(x + 12, 620); c.fill();
};
// the House, built up to fraction h (stone courses)
const house = (c, x, gy, h, light, o = {}) => {
  const w = o.w || 240, full = o.full || 230, top = gy - full * h;
  if (h <= 0.001) { c.strokeStyle = K.rgba('#FFF0C8', 0.6); c.lineWidth = 2; c.strokeRect(x - w / 2, gy - 6, w, 6); return; }
  c.fillStyle = K.tone('#5E5650', light); c.fillRect(x - w / 2, top, w * 0.72, gy - top);
  c.fillStyle = K.tone('#4A433E', light); c.fillRect(x - w / 2 + w * 0.72, top, w * 0.28, gy - top);
  c.strokeStyle = K.rgba('#2E2824', 0.5); c.lineWidth = 1.5;
  for (let y = gy; y > top; y -= 23) { c.beginPath(); c.moveTo(x - w / 2, y); c.lineTo(x + w / 2, y); c.stroke(); const off = ((gy - y) / 23) % 2 ? 20 : 0; for (let xx = x - w / 2 + off; xx < x + w / 2; xx += 40) { c.beginPath(); c.moveTo(xx, y); c.lineTo(xx, Math.max(top, y - 23)); c.stroke(); } }
};

const S = [];
S.push({ // 1 by Allah's command Ibrahim settled Isma'il and his mother Hajar in the valley of Makka
  cam: (p) => [K.lerp(1.0, 1.1, E(p)), 640, 430, 0], draw(c, t, d) {
  valley(c, t, 0.9, { sun: [1000, 150] });
  K.par(c, 1, () => { tent(c, 640, 0.9); K.presence(c, 520, 610, 26, t, 1); K.presence(c, 700, 615, 12, t, 1); K.presence(c, 735, 610, 14, t, 0.7); });
} });
S.push({ // 2 a valley with no crops and no water, by His House
  cam: (p) => [K.lerp(1.1, 1.0, E(p)), K.lerp(500, 700, E(p)), 410, 0], draw(c, t, d) {
  valley(c, t, 0.95, { sun: [1000, 140] });
  K.par(c, 1.08, () => K.dust(c, t, 9101, 30, '#E8D3B0', 0.4, -100, W + 100, 420, 720, 22));
  K.par(c, 1, () => { tent(c, 640, 0.95); for (const x of [200, 1060]) { c.strokeStyle = '#6B4A34'; c.lineWidth = 4; c.beginPath(); c.moveTo(x, 640); c.lineTo(x + 6, 600); c.lineTo(x - 8, 585); c.stroke(); } });
} });
S.push({ // 3 Hajar: did Allah command you this? Yes. Then He will not abandon us
  cam: (p) => [K.lerp(1.15, 1.25, E(p)), 640, 520, 0], draw(c, t, d) {
  const nm = B(3, 'نعم', d * 0.6);
  valley(c, t, 0.85, { sun: [1040, 200] });
  K.par(c, 1, () => {
    tent(c, 640, 0.85);
    const go = A(t, 0, d, (x) => x);
    K.presence(c, K.lerp(560, 1000, go), 610, 24, t, 1);
    K.presence(c, 720, 612, 14, t, 1); K.presence(c, 690, 618, 10, t, 1);
    K.glow(c, 705, 612, 90, '#FFE6A8', 0.25 * A(t, nm + 0.5, 1));
  });
} });
S.push({ // 4 from the pass he prayed: make hearts yearn to them, provide them fruits
  cam: (p) => [K.lerp(1.0, 1.06, E(p)), 640, 400, 0], draw(c, t, d) {
  valley(c, t, 0.6, { sun: [1100, 320] });
  K.par(c, 0.6, () => { K.presence(c, 1110, 360, 20, t, 1); K.rays(c, 1110, 350, 8, 600, -Math.PI * 0.7, -Math.PI * 0.3, '#FFF0C8', 0.1, t); });
  K.par(c, 1, () => { tent(c, 560, 0.6); K.presence(c, 640, 614, 12, t, 1); });
} });
S.push({ // 5 a safe land; keep me and my sons from idols. Allah answered
  cam: (p) => [1.0, 640, 380, 0], draw(c, t, d) {
  const st = B(5, 'فاستجابَ', d * 0.8);
  valley(c, t, 0.25, { moon: [1000, 130] });
  K.par(c, 0.2, () => K.glow(c, 640, 300, 300, '#FFF0C8', 0.12 * A(t, st - 0.3, 1.5)));
  K.par(c, 1, () => { tent(c, 560, 0.3); K.presence(c, 640, 614, 12, t, 1); K.glow(c, 560, 600, 60, '#FFC869', 0.2); });
} });
S.push({ // 6 the water ran out; Hajar and her son grew thirsty
  cam: (p) => [K.lerp(1.2, 1.3, E(p)), 640, 540, 0], draw(c, t, d) {
  valley(c, t, 1, { sun: [640, 110], cols: ['#8EB4D0', '#E8D8B8', '#F8E2B8'] });
  K.par(c, 1, () => {
    tent(c, 560, 1);
    c.fillStyle = '#8A6A4C'; c.beginPath(); c.ellipse(700, 632, 22, 9, 0.2, 0, TAU); c.fill(); // an empty waterskin, flat
    K.presence(c, 640, 614, 12, t, 0.9); K.presence(c, 600, 610, 14, t, 0.8);
  });
  K.par(c, 1.1, () => { for (let i = 0; i < 6; i++) { const y = 700 - i * 30, ph = t * 2 + i; c.strokeStyle = K.rgba('#FFFFFF', 0.06); c.lineWidth = 2; c.beginPath(); for (let x = -100; x < W + 100; x += 20) c.lineTo(x, y + Math.sin(x * 0.03 + ph) * 3); c.stroke(); } });
} });
S.push({ // 7 she climbed Safa to look for anyone, then Marwa - seven times
  cam: (p) => [1.0, 640, 420, 0], draw(c, t, d) {
  valley(c, t, 0.95, { sun: [640, 120] });
  K.par(c, 0.6, () => {
    const u = A(t, 0.6, d - 1.2, (x) => x) * 7, k = Math.floor(u), q = u - k;
    const fwd = k % 2 === 0, x = fwd ? K.lerp(200, 1100, K.smooth(q)) : K.lerp(1100, 200, K.smooth(q));
    const y = 370 + 140 * Math.sin(K.smooth(q) * Math.PI) ** 0.5 * 0 + (Math.abs(x - 640) > 300 ? -0.3 * (Math.abs(x - 640) - 300) : 0) + 140;
    K.presence(c, x, Math.min(510, y), 14, t, 1);
    for (let i = 0; i < Math.min(7, k + (q > 0.95 ? 1 : 0)); i++) { c.fillStyle = K.rgba('#FFE6A8', 0.6); c.beginPath(); c.arc(560 + i * 24, 690, 4, 0, TAU); c.fill(); }
  });
} });
S.push({ // 8 the angel at the place of Zamzam struck the ground until water appeared - no angel drawn
  cam: (p) => [K.lerp(1.3, 1.15, E(p)), 640, 560, 0], draw(c, t, d) {
  const zm = B(8, 'زمزمَ', d * 0.4), mz = B(8, 'الماءُ', d * 0.8);
  valley(c, t, 0.9, { sun: [1040, 160] });
  K.par(c, 1, () => {
    const k = A(t, zm - 0.6, 1), w = A(t, mz - 0.4, 1);
    K.rays(c, 640, -40, 7, 760, Math.PI * 0.42, Math.PI * 0.58, '#FFF6DA', 0.14 * k, t);
    K.glow(c, 640, 650, 120, '#FFFFFF', 0.4 * k * (1 - w * 0.5));
    c.fillStyle = K.rgba('#7FC2D0', 0.9 * w); c.beginPath(); c.ellipse(640, 655, 30 + 70 * w, 10 + 12 * w, 0, 0, TAU); c.fill();
    K.spray(c, t, 9102, 50, 610, 670, 652, 90, '#DFF4F8', w);
    K.presence(c, 520, 620, 14, t, 1);
  });
} });
S.push({ // 9 she drank and nursed her son; do not fear neglect - here is a House this boy and his father will build
  cam: (p) => [K.lerp(1.15, 1.05, E(p)), 640, 500, 0], draw(c, t, d) {
  const bt = B(9, 'بيتًا', d * 0.7);
  valley(c, t, 0.95, { sun: [1040, 150] });
  K.par(c, 1, () => {
    c.fillStyle = '#7FC2D0'; c.beginPath(); c.ellipse(560, 655, 90, 20, 0, 0, TAU); c.fill();
    for (let i = 0; i < 3; i++) { const q = K.fract(t * 0.5 + i / 3); c.strokeStyle = K.rgba('#E8F8FA', 0.6 * (1 - q)); c.lineWidth = 2; c.beginPath(); c.ellipse(560, 655, 90 * q, 20 * q, 0, 0, TAU); c.stroke(); }
    K.presence(c, 470, 625, 14, t, 1); K.presence(c, 500, 632, 10, t, 1);
    house(c, 820, 640, 0, 1); K.glow(c, 820, 636, 120, '#FFF0C8', 0.3 * A(t, bt - 0.3, 1.2));
  });
} });
S.push({ // 10 Allah showed Ibrahim the place of the House and commanded him to build it
  cam: (p) => [K.lerp(1.0, 1.15, E(p)), 640, 470, 0], draw(c, t, d) {
  valley(c, t, 0.9, { sun: [1040, 160] });
  K.par(c, 1, () => { K.rays(c, 640, -40, 9, 760, Math.PI * 0.4, Math.PI * 0.6, '#FFF6DA', 0.12 * A(t, d * 0.2, 1.5), t); house(c, 640, 640, 0, 1); K.presence(c, 480, 620, 26, t, 1); });
} });
S.push({ // 11 Ibrahim and Isma'il raised the foundations, stone upon stone, praying humbly
  cam: (p) => [K.lerp(1.1, 1.0, E(p)), 640, 440, 0], draw(c, t, d) {
  valley(c, t, 0.92, { sun: [1040, 160] });
  K.par(c, 1, () => {
    const h = 0.05 + 0.5 * A(t, 0.3, d - 0.6, (x) => x);
    house(c, 640, 640, h, 0.95);
    K.presence(c, 470, 620, 26, t, 1); K.presence(c, 820, 625, 18, t, 1);
    const q = K.fract(t / 2.2); // a stone passing from the son to the father
    c.fillStyle = '#5E5650'; c.fillRect(K.lerp(800, 500, q) - 12, 600 - 60 * Math.sin(q * Math.PI) - 8, 24, 16);
  });
} });
S.push({ // 12 recitation 2:127 - the walls rising under the sky
  cam: (p) => [K.lerp(1.0, 1.06, E(p)), 640, K.lerp(420, 380, E(p)), 0], draw(c, t, d, p) {
  valley(c, t, K.lerp(0.9, 0.6, E(p)), { sun: [K.lerp(1040, 1140, E(p)), K.lerp(160, 330, E(p))] });
  K.par(c, 1, () => { house(c, 640, 640, 0.55 + 0.25 * E(p), 0.9); K.presence(c, 470, 620, 26, t, 1); K.presence(c, 820, 625, 18, t, 1); });
} });
S.push({ // 13 he stood on a stone as he built: the Station of Ibrahim
  cam: (p) => [K.lerp(1.2, 1.35, E(p)), 520, 520, 0], draw(c, t, d) {
  const hj = B(13, 'حجرٍ', d * 0.2);
  valley(c, t, 0.85, { sun: [1100, 260] });
  K.par(c, 1, () => {
    house(c, 700, 640, 0.85, 0.9);
    const k = A(t, hj - 0.3, 1);
    c.fillStyle = '#8A7E70'; c.fillRect(520, 618, 52, 22);
    K.glow(c, 546, 625, 60, '#FFF0C8', 0.35 * k);
    K.presence(c, 546, 560, 24, t, 1);
  });
} });
S.push({ // 14 they prayed: make us steadfast in Islam, and from our offspring a submitting nation
  cam: (p) => [K.lerp(1.0, 1.1, E(p)), 640, 420, 0], draw(c, t, d) {
  valley(c, t, 0.45, { sun: [1140, 420] });
  K.par(c, 1, () => { house(c, 640, 640, 1, 0.5); K.presence(c, 440, 620, 26, t, 1); K.presence(c, 850, 625, 18, t, 1); K.rays(c, 640, 400, 9, 600, -Math.PI * 0.85, -Math.PI * 0.15, '#FFF0C8', 0.08, t); });
} });
S.push({ // 15 send among them a messenger from Isma'il's line - it was our Prophet ﷺ (never drawn): a far star
  cam: (p) => [1.0, 640, K.lerp(380, 300, E(p)), 0], draw(c, t, d) {
  valley(c, t, 0.2, { moon: [1040, 130] });
  K.par(c, 0.15, () => { const k = A(t, d * 0.35, 2); K.glow(c, 640, 150, 80, '#FFF6DA', 0.45 * k); c.fillStyle = K.rgba('#FFFFFF', k); c.beginPath(); c.arc(640, 150, 5, 0, TAU); c.fill(); });
  K.par(c, 1, () => house(c, 640, 640, 1, 0.3));
} });
S.push({ // 16 purify My House for those who circle it and pray
  cam: (p) => [K.lerp(1.1, 1.2, E(p)), 640, 480, 0], draw(c, t, d) {
  valley(c, t, 0.95, { sun: [1040, 150] });
  K.par(c, 1, () => { c.fillStyle = K.rgba('#F2E6CC', 0.7); c.beginPath(); c.ellipse(640, 650, 360, 40, 0, 0, TAU); c.fill(); house(c, 640, 640, 1, 0.95); K.dust(c, t, 9103, 26, '#FFF6DA', 0.6, 280, 1000, 380, 660, 2); });
} });
S.push({ // 17 call people to Hajj: they come on foot and riding, from every far road
  cam: (p) => [K.lerp(1.0, 1.06, E(p)), 640, 420, 0], draw(c, t, d) {
  valley(c, t, 0.9, { sun: [1040, 160] });
  K.par(c, 1, () => {
    house(c, 640, 600, 1, 0.9, { w: 150, full: 140 });
    const ap = A(t, d * 0.15, d * 0.8, (x) => x);
    KIT.crowd(c, 9104, 10, -200, 260, 660, 0.9, t, { face: 1, walk: 1, shift: 200 * ap });
    KIT.crowd(c, 9105, 10, 1020, 1480, 660, 0.9, t, { face: -1, walk: 1, shift: -200 * ap });
    K.animal(c, 'camel', -60 + 220 * ap, 640, 0.8, t * 3, 0);
    K.animal(c, 'camel', 1340 - 220 * ap, 640, 0.8, t * 3 + 1, 0);
  });
} });
S.push({ // 18 Allah made the Ka'ba a place people return to, and a safety - people circling
  cam: (p) => [K.lerp(1.15, 1.0, E(p)), 640, 440, 0], draw(c, t, d) {
  valley(c, t, 0.75, { sun: [1100, 280] });
  K.par(c, 1, () => {
    const n = 26, back = [], front = [];
    for (let i = 0; i < n; i++) { const a = (i / n) * TAU - t * 0.25; (Math.sin(a) < 0 ? back : front).push(a); }
    const ring = (list) => list.forEach((a, i) => K.person(c, 640 + Math.cos(a) * 250, 650 + Math.sin(a) * 40, 0.8, { robe: '#EDE6D8', cloth: '#F4EFE4', dir: Math.cos(a) > 0 ? -1 : 1, walk: 0.6, phase: t * 4 + i }));
    ring(back); house(c, 640, 640, 1, 0.75); ring(front);
  });
} });
S.push({ cam: (p) => [K.lerp(1.1, 1.02, E(p)), 640, K.lerp(390, 362, E(p)), 0], draw(c, t, d, p) {
  KIT.lesson(c, t, p, { seed: 9106 });
} });
window.STORY_SCENES = S;
})();
