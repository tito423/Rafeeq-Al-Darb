// Story - Yusuf, peace be upon him. VISUALS ONLY.
// Narration: docs/kids_stories/yusuf_narration.md (12:4-100 + al-Muyassar).
// Yusuf and Ya'qub are NEVER drawn - warm lights (young Yusuf smaller). His
// brothers are NOT drawn as people (caution, see the doc): they are told by
// eleven small stars, their caravan and their sacks. No wolf, no blood shown:
// the shirt is folded and plain. The prostration is not drawn: the eleven
// stars, the sun and the moon shine over Egypt. Beats fall back to d * f.
'use strict';
(() => {
const { W, H } = K;
const TAU = Math.PI * 2;
const E = K.easeInOut, B = K.beat, A = K.after;
// eleven stars + sun + moon (the dream); k = brightness, bow = 0..1 dip toward (x, y)
const dream = (c, t, k, bow = 0, cx = 640, cy = 560) => {
  if (k <= 0.01) return;
  const r = K.rng(5101);
  for (let i = 0; i < 11; i++) {
    const a = Math.PI * (0.12 + 0.76 * i / 10), R = 380;
    let x = 640 + Math.cos(a) * R * -1, y = 330 - Math.sin(a) * 210;
    x = K.lerp(x, cx + (x - 640) * 0.35, bow); y = K.lerp(y, cy - 140 + (y - 330) * 0.3, bow);
    const tw = 0.75 + 0.25 * Math.sin(t * 2 + r() * TAU);
    K.glow(c, x, y, 26, '#FFF3C8', 0.5 * k * tw);
    c.fillStyle = K.rgba('#FFFBEA', k); c.beginPath();
    for (let j = 0; j < 10; j++) { const rr = j % 2 ? 3 : 8, aa = j * Math.PI / 5 - Math.PI / 2; c.lineTo(x + Math.cos(aa) * rr, y + Math.sin(aa) * rr); }
    c.fill();
  }
  K.sun(c, K.lerp(380, cx - 170, bow), K.lerp(160, cy - 190, bow), 30, '#FFF1C4', '#FFC46B', 0.5, k);
  K.moon(c, K.lerp(900, cx + 170, bow), K.lerp(150, cy - 190, bow), 24, '#FFF4D6', k);
};
const NIGHT = ['#0E1534', '#1B2550', '#2E3A66'];
const canaan = (c, t, light, o = {}) => {
  KIT.sky(c, t, light, { sun: o.sun, moon: o.moon, cols: o.cols, seed: 51 });
  KIT.land(c, light, { seed: 5.2, farCol: '#A8A88A', midCol: '#A49A6A' });
  K.par(c, 0.8, () => {
    KIT.ground(c, 530, light, '#B8B07A');
    if (!o.noTent) {
      c.fillStyle = K.tone('#8A6A52', light); c.beginPath(); c.moveTo(300, 600); c.lineTo(390, 500); c.lineTo(480, 600); c.fill();
      c.fillStyle = K.tone('#6A4A3A', light); c.beginPath(); c.moveTo(372, 600); c.lineTo(390, 540); c.lineTo(408, 600); c.fill();
    }
    for (const [x, s] of [[150, 1.1], [620, 0.9], [1100, 1.0]]) K.shrub(c, x, 620, s, K.tone('#7E9A55', light));
  });
};
const well = (c, x, y, light) => {
  c.fillStyle = K.tone('#9A8A78', light); c.beginPath(); c.ellipse(x, y, 70, 18, 0, 0, TAU); c.fill();
  c.fillStyle = K.tone('#B8A890', light); c.fillRect(x - 70, y - 40, 140, 40);
  c.fillStyle = K.tone('#2A2018', light); c.beginPath(); c.ellipse(x, y - 40, 60, 14, 0, 0, TAU); c.fill();
  c.strokeStyle = K.tone('#6B4A34', light); c.lineWidth = 6;
  c.beginPath(); c.moveTo(x - 66, y - 40); c.lineTo(x - 66, y - 120); c.lineTo(x + 66, y - 120); c.lineTo(x + 66, y - 40); c.stroke();
};
const camels = (c, t, n, x0, y, s, walk, light, shift = 0) => {
  for (let i = 0; i < n; i++) {
    K.animal(c, 'camel', x0 + i * 120 * s + shift, y + (i % 2) * 6, s, walk ? t * 3 + i : 0, 0, light < 0.6 ? 0.3 : 0);
    c.fillStyle = K.tone('#C8A878', light); c.fillRect(x0 + i * 120 * s + shift - 18 * s, y - 66 * s, 36 * s, 18 * s); // a load
  }
};
const egypt = (c, t, light, o = {}) => {
  KIT.sky(c, t, light, { sun: o.sun, moon: o.moon, cols: o.cols, seed: 52 });
  K.par(c, 0.3, () => { K.ridge(c, 430, 20, 6.1, 0.6, K.tone('#D8B888', light)); K.haze(c, 330, 490, '#F6DEB8', 0.3); });
  K.par(c, 0.6, () => {
    // the Nile
    c.fillStyle = K.tone('#5E9EB0', light); c.fillRect(-420, 470, W + 840, 40);
    c.strokeStyle = K.rgba('#E3F2F4', 0.5); c.lineWidth = 2;
    for (let i = 0; i < 6; i++) { const x = K.mod(i * 260 + t * 20, W + 300) - 150; c.beginPath(); c.moveTo(x, 488); c.lineTo(x + 50, 488); c.stroke(); }
  });
  K.par(c, 0.8, () => {
    KIT.ground(c, 510, light, '#D8BC86');
    // a palace with columns
    if (!o.noPalace) {
      const x = o.px ?? 760;
      c.fillStyle = K.tone('#E8D2A8', light); c.fillRect(x, 400, 360, 160);
      c.fillStyle = K.tone('#D4BA8C', light); c.fillRect(x - 10, 388, 380, 16);
      c.fillStyle = K.tone('#F2E2C0', light); for (let i = 0; i < 7; i++) c.fillRect(x + 16 + i * 50, 404, 16, 156);
      c.fillStyle = K.tone('#6E5038', light); c.fillRect(x + 160, 490, 40, 70);
    }
    for (const [x, h, ph] of [[120, 160, 1], [320, 140, 2], [1220, 150, 3]]) KIT.palm(c, x, 580, h, light, t, ph);
  });
};
const prison = (c, t, light, o = {}) => {
  K.par(c, 0, () => { c.fillStyle = K.tone('#7A6A5C', light); c.fillRect(-420, -420, W + 840, H + 840);
    c.strokeStyle = K.rgba('#4A3C30', 0.35); c.lineWidth = 2; for (let y = 30; y < 640; y += 52) for (let x = (y / 52) % 2 ? -40 : 10; x < W + 60; x += 104) c.strokeRect(x, y, 104, 52); });
  K.par(c, 0.7, () => {
    // a high barred window with a shaft of light
    c.fillStyle = K.rgba('#FFF0C8', 0.9); c.fillRect(580, 110, 120, 90);
    c.fillStyle = K.tone('#3A2C22', light); for (let i = 0; i < 5; i++) c.fillRect(592 + i * 24, 110, 6, 90);
    K.rays(c, 640, 150, 6, 640, Math.PI * 0.38, Math.PI * 0.62, '#FFF0C8', 0.12 * (o.ray ?? 1), t);
    c.fillStyle = K.tone('#5A4A3E', light); c.fillRect(-420, 600, W + 840, 600);
  });
};
// a cow: simple flat body; fat (f=1) or lean (f=0)
const cow = (c, x, y, s, f, light, ph = 0) => {
  const body = K.tone(K.mix('#A88A6A', '#C9A27A', f), light), dark = K.tone('#6A5040', light);
  c.save(); c.translate(x, y); c.scale(s, s);
  c.strokeStyle = dark; c.lineWidth = 5; c.lineCap = 'round';
  for (const lx of [-22, -10, 14, 26]) { c.beginPath(); c.moveTo(lx, -20); c.lineTo(lx + Math.sin(ph + lx) * 2, 8); c.stroke(); }
  c.fillStyle = body; c.beginPath(); c.ellipse(0, -30, 34, K.lerp(9, 18, f), 0, 0, TAU); c.fill();
  c.beginPath(); c.ellipse(38, -38, 11, 8, 0.3, 0, TAU); c.fill();
  c.strokeStyle = '#E8DCC0'; c.lineWidth = 3; c.beginPath(); c.moveTo(36, -46); c.lineTo(32, -54); c.moveTo(42, -46); c.lineTo(46, -54); c.stroke();
  c.restore();
};
const ear = (c, x, y, s, green, light, t) => {
  const col = K.tone(green ? '#7AA04A' : '#C8A860', light), sway = Math.sin(t * 1.3 + x * 0.05) * 3 * (green ? 1 : 0.3);
  c.strokeStyle = col; c.lineWidth = 3; c.beginPath(); c.moveTo(x, y); c.quadraticCurveTo(x + sway, y - 40 * s, x + sway * 1.5, y - 80 * s); c.stroke();
  c.fillStyle = col; for (let i = 0; i < 5; i++) { c.beginPath(); c.ellipse(x + sway * 1.5 + (i % 2 ? 5 : -5), y - 80 * s + i * 7, 5, 8, i % 2 ? 0.5 : -0.5, 0, TAU); c.fill(); }
};
const sacks = (c, x, y, n, light, a = 1) => {
  c.save(); c.globalAlpha *= a;
  for (let i = 0; i < n; i++) { const xx = x + (i % 6) * 46, yy = y - Math.floor(i / 6) * 34; c.fillStyle = K.tone(i % 2 ? '#D8C08C' : '#C8AE7A', 1); c.beginPath(); c.ellipse(xx, yy, 22, 18, 0, 0, TAU); c.fill(); c.fillStyle = K.tone('#8A6A44', 1); c.fillRect(xx - 6, yy - 20, 12, 6); }
  c.restore();
};
const shirt = (c, x, y, s, a = 1) => {
  c.save(); c.globalAlpha *= a; c.translate(x, y); c.scale(s, s);
  c.fillStyle = '#E8DCC4'; c.beginPath(); c.moveTo(-30, -20); c.lineTo(-14, -28); c.lineTo(14, -28); c.lineTo(30, -20); c.lineTo(24, -8); c.lineTo(16, -12); c.lineTo(16, 24); c.lineTo(-16, 24); c.lineTo(-16, -12); c.lineTo(-24, -8); c.closePath(); c.fill();
  c.strokeStyle = '#B8A888'; c.lineWidth = 1.5; c.stroke();
  c.restore();
};

const S = [];
S.push({ // 1 the dream: eleven stars, the sun and the moon
  cam: (p) => [K.lerp(1.0, 1.08, E(p)), 640, K.lerp(380, 340, E(p)), 0], draw(c, t, d) {
  const kw = B(1, 'كوكبًا', d * 0.55), sj = B(1, 'يسجدونَ', d * 0.85);
  canaan(c, t, 0.18, { cols: NIGHT });
  K.par(c, 0.25, () => dream(c, t, A(t, kw - 0.8, 1.5), A(t, sj - 0.3, 2), 390, 560));
  K.par(c, 1, () => K.presence(c, 390, 590, 14, t, 1));
} });
S.push({ // 2 his father: do not tell your brothers
  cam: (p) => [K.lerp(1.15, 1.25, E(p)), 420, 520, 0], draw(c, t, d) {
  canaan(c, t, 0.3, { moon: [1000, 140] });
  K.par(c, 1, () => { K.presence(c, 360, 590, 26, t, 1); K.presence(c, 430, 600, 14, t, 1); K.glow(c, 390, 560, 160, '#FFC869', 0.12); });
} });
S.push({ // 3 the brothers: our father loves Yusuf and his brother more - eleven stars, two of them apart
  cam: (p) => [1.0, 640, 360, 0], draw(c, t, d) {
  const tf = B(3, 'فاتَّفَقوا', d * 0.7);
  canaan(c, t, 0.2, { cols: NIGHT, noTent: false });
  K.par(c, 0.25, () => {
    const r = K.rng(5102);
    for (let i = 0; i < 10; i++) {
      const x = 760 + (i % 5) * 70 + r() * 20, y = 160 + Math.floor(i / 5) * 70;
      const k = 0.5 + 0.3 * A(t, tf - 0.5, 1); // they gather, dimmer, together
      K.glow(c, x, y, 18, '#C8C8E8', 0.35 * k); c.fillStyle = K.rgba('#D8DCF0', k); c.beginPath(); c.arc(x, y, 3.5, 0, TAU); c.fill();
    }
    K.glow(c, 300, 200, 30, '#FFF3C8', 0.6); c.fillStyle = '#FFFBEA'; c.beginPath(); c.arc(300, 200, 5, 0, TAU); c.fill();
    K.glow(c, 360, 230, 22, '#FFF3C8', 0.5); c.fillStyle = '#FFFBEA'; c.beginPath(); c.arc(360, 230, 4, 0, TAU); c.fill();
  });
} });
S.push({ // 4 they took him to the pastures and threw him into the well
  cam: (p) => [K.lerp(1.0, 1.3, E(p)), K.lerp(640, 820, E(p)), K.lerp(400, 500, E(p)), 0], draw(c, t, d) {
  const bi = B(4, 'البئرِ', d * 0.85);
  canaan(c, t, 0.85, { sun: [1080, 160], noTent: true });
  K.par(c, 1, () => {
    well(c, 820, 640, 0.85);
    const k = A(t, bi - 0.6, 1.4);
    K.presence(c, K.lerp(560, 820, k), K.lerp(620, 620, k), 14, t, 1 - k);
    K.glow(c, 820, 600, 40, '#FFC869', 0.3 * k);
  });
  KIT.foreGrass(c, t, 0.85);
} });
S.push({ // 5 Allah revealed to Yusuf: you will tell them one day - light in the dark of the well
  cam: (p) => [K.lerp(1.0, 1.1, E(p)), 640, 360, 0], draw(c, t, d) {
  K.par(c, 0, () => { c.fillStyle = '#16120E'; c.fillRect(-420, -420, W + 840, H + 840);
    // the shaft: stone courses on both sides, the mouth of the well a circle of sky
    for (let y = -40; y < H + 40; y += 44) for (let k = 0; k < 2; k++) { const x0 = k ? 820 : 120, off = (y / 44) % 2 ? 0 : 60; for (let x = x0 - 120 + off; x < x0 + 340; x += 120) { c.fillStyle = (x + y) % 3 ? '#2E241C' : '#261E17'; c.fillRect(x, y, 116, 40); } }
    const g = c.createLinearGradient(400, 0, 880, 0); g.addColorStop(0, 'rgba(22,18,14,1)'); g.addColorStop(0.5, 'rgba(22,18,14,0.2)'); g.addColorStop(1, 'rgba(22,18,14,1)'); c.fillStyle = g; c.fillRect(380, -40, 520, H + 80);
    c.fillStyle = '#7FA8C8'; c.beginPath(); c.arc(640, 60, 90, 0, TAU); c.fill(); });
  K.par(c, 1, () => {
    K.presence(c, 640, 560, 16, t, 1);
    K.rays(c, 640, 40, 5, 600, Math.PI * 0.42, Math.PI * 0.58, '#FFF6DA', 0.1 + 0.12 * A(t, d * 0.3, 1.5), t);
  });
} });
S.push({ // 6 at night they came back weeping: the wolf ate him - with his shirt
  cam: (p) => [K.lerp(1.15, 1.25, E(p)), 400, 520, 0], draw(c, t, d) {
  const qm = B(6, 'بقميصِهِ', d * 0.75);
  canaan(c, t, 0.25, { moon: [1000, 140] });
  K.par(c, 1, () => {
    K.presence(c, 330, 590, 24, t, 0.9);
    shirt(c, 470, 610, 1.1, A(t, qm - 0.4, 0.8));
    camels(c, t, 0, 0, 0, 0, 0, 0.3);
  });
} });
S.push({ // 7 Ya'qub: beautiful patience, and Allah's help is sought
  cam: (p) => [K.lerp(1.1, 1.0, E(p)), 420, 440, 0], draw(c, t, d) {
  canaan(c, t, 0.22, { moon: [1000, 140] });
  K.par(c, 1, () => { K.presence(c, 330, 590, 24, t, 1); K.rays(c, 330, 580, 6, 520, -Math.PI * 0.62, -Math.PI * 0.38, '#FFE6B0', 0.08 * A(t, d * 0.5, 1.5), t); });
} });
S.push({ // 8 a caravan; the water-drawer lets down his bucket, Yusuf holds on
  cam: (p) => [K.lerp(1.0, 1.25, E(p)), K.lerp(640, 820, E(p)), K.lerp(420, 500, E(p)), 0], draw(c, t, d) {
  const dl = B(8, 'دلوَهُ', d * 0.6), tl = B(8, 'تعلَّقَ', d * 0.85);
  canaan(c, t, 0.9, { sun: [1080, 160], noTent: true });
  K.par(c, 1, () => {
    camels(c, t, 3, 260, 640, 0.9, false, 0.9);
    well(c, 820, 640, 0.9);
    const down = A(t, dl - 0.3, 1.2), up = A(t, tl, 1.6);
    const by = 520 + 80 * down - 90 * up;
    c.strokeStyle = '#6B4A34'; c.lineWidth = 2; c.beginPath(); c.moveTo(820, 520); c.lineTo(820, by); c.stroke();
    c.fillStyle = '#7A5A40'; c.fillRect(808, by, 24, 18);
    K.presence(c, 820, by + 30, 14, t, up);
    KIT.crowd(c, 5103, 1, 720, 721, 640, 1.0, t, { face: 1, point: down * (1 - up * 0.5) });
  });
} });
S.push({ // 9 sold for a few coins; taken to Egypt; bought by the 'Aziz: honour his stay
  cam: (p) => [K.lerp(1.0, 1.08, E(p)), K.lerp(500, 760, E(p)), 410, 0], draw(c, t, d) {
  const mr = B(9, 'مصرَ', d * 0.45);
  const k = A(t, mr - 0.6, 1.6);
  if (k < 0.5) canaan(c, t, 0.9, { sun: [1080, 160], noTent: true }); else egypt(c, t, 0.95, { sun: [1080, 150] });
  K.par(c, 1, () => {
    camels(c, t, 3, 200, 640, 0.9, true, 0.9, (t * 30) % 300);
    K.presence(c, 200 + (t * 30) % 300 + 360, 610, 13, t, 1);
  });
  K.par(c, 0, () => { const f = 1 - Math.abs(k - 0.5) * 2; if (f > 0) { c.fillStyle = K.rgba('#F6E6C8', f); c.fillRect(-420, -420, W + 840, H + 840); } });
} });
S.push({ // 10 when grown, Allah gave him understanding and knowledge
  cam: (p) => [K.lerp(1.0, 1.12, E(p)), 760, 420, 0], draw(c, t, d) {
  egypt(c, t, 0.95, { sun: [1060, 140] });
  K.par(c, 1, () => { K.presence(c, 940, 600, 22 + 6 * A(t, d * 0.4, 1.5), t, 1); K.rays(c, 940, 590, 8, 520, -Math.PI * 0.75, -Math.PI * 0.25, '#FFF0C8', 0.08 * A(t, d * 0.4, 1.5), t); });
} });
S.push({ // 11 imprisoned unjustly though innocent; in prison he called to Allah alone and interpreted dreams
  cam: (p) => [K.lerp(1.05, 1.15, E(p)), 640, 430, 0], draw(c, t, d) {
  prison(c, t, 0.7);
  K.par(c, 1, () => {
    K.presence(c, 640, 610, 24, t, 1);
    c.save(); c.globalAlpha *= 0.85; KIT.crowd(c, 5104, 2, 380, 460, 640, 1.0, t, { face: 1 }); KIT.crowd(c, 5105, 1, 860, 861, 640, 1.0, t, { face: -1 }); c.restore();
  });
} });
S.push({ // 12 the king's dream: seven fat cows eaten by seven lean, seven green ears and seven dry
  cam: (p) => [1.0, 640, 360, 0], draw(c, t, d) {
  const nh = B(12, 'نحيلاتٌ', d * 0.4), sn = B(12, 'سنبلاتٍ', d * 0.6);
  K.par(c, 0, () => { K.sky(c, ['#2A2A5A', '#5A4A7A', '#8A6A8A'], 0, 720); K.stars(c, 5106, 80, 0.6, t, 700); });
  K.par(c, 1, () => {
    const k1 = 1 - A(t, sn - 0.6, 0.8);
    c.save(); c.globalAlpha *= k1;
    for (let i = 0; i < 7; i++) cow(c, 160 + i * 150, 420, 1.0, 1, 0.9, t);
    c.globalAlpha *= A(t, nh - 0.5, 1);
    for (let i = 0; i < 7; i++) cow(c, 160 + i * 150 - 40 + 40 * A(t, nh, 2), 560, 1.0, 0, 0.75, t);
    c.restore();
    c.save(); c.globalAlpha *= 1 - k1;
    for (let i = 0; i < 7; i++) ear(c, 160 + i * 70, 560, 1.4, true, 0.9, t);
    for (let i = 0; i < 7; i++) ear(c, 700 + i * 70, 560, 1.4, false, 0.9, t);
    c.restore();
  });
} });
S.push({ // 13 Yusuf interpreted: seven good years, store the grain in its ears; then seven hard years
  cam: (p) => [K.lerp(1.05, 1.0, E(p)), 640, 410, 0], draw(c, t, d) {
  const sh = B(13, 'شديدةٌ', d * 0.65);
  const hard = A(t, sh - 0.6, 1.6);
  egypt(c, t, 0.95, { sun: [1060, 140], noPalace: true, cols: [K.mix('#5DA9D6', '#A88A6A', hard), K.mix('#A3D2E6', '#D8B888', hard), '#F4E3C0'] });
  K.par(c, 1, () => {
    for (let i = 0; i < 14; i++) ear(c, 120 + i * 40, 650, 1.1, hard < 0.5, 0.95, t);
    sacks(c, 820, 640, 12, 0.95, A(t, d * 0.25, 1.5));
    K.presence(c, 720, 610, 22, t, 1);
  });
} });
S.push({ // 14 then a year of rain and plenty
  cam: (p) => [K.lerp(1.0, 1.1, E(p)), 640, 400, 0], draw(c, t, d) {
  const rain = A(t, 0.2, 1.2) * (1 - A(t, d * 0.55, 1.2));
  egypt(c, t, K.lerp(0.95, 0.7, rain), { sun: [1060, 140], noPalace: true, cloudA: 1 });
  K.par(c, 0.9, () => K.rain(c, t, 5107, 160, 0.5 * rain, -40, 700, 18));
  K.par(c, 1, () => { for (let i = 0; i < 22; i++) ear(c, 80 + i * 52, 660, 1.2 * (0.6 + 0.4 * A(t, d * 0.4, d * 0.5)), true, 0.95, t); });
} });
S.push({ // 15 his innocence shown, the king brought him out; over the storehouses: trustworthy, knowing
  cam: (p) => [K.lerp(1.0, 1.15, E(p)), 820, 440, 0], draw(c, t, d) {
  const kh = B(15, 'خزائنِ', d * 0.7);
  egypt(c, t, 0.95, { sun: [1060, 140] });
  K.par(c, 1, () => {
    K.presence(c, 940, 600, 26, t, 1);
    sacks(c, 420, 650, 18, 0.95, A(t, kh - 0.4, 1.2));
  });
} });
S.push({ // 16 the hard years; his brothers came for food - their caravan, sacks empty
  cam: (p) => [1.0, K.lerp(500, 640, E(p)), 410, 0], draw(c, t, d) {
  egypt(c, t, 0.85, { sun: [1060, 160], cols: ['#B8A07A', '#D8B888', '#F0D8B0'] });
  K.par(c, 1, () => {
    camels(c, t, 4, -80, 640, 0.85, true, 0.85, Math.min(t, d * 0.7) * 40);
    K.presence(c, 1000, 600, 24, t, 1);
  });
  K.par(c, 1.08, () => K.dust(c, t, 5108, 30, '#E8D3B0', 0.35, -100, W + 100, 420, 720, 18));
} });
S.push({ // 17 he honoured them, asked for their brother; held him close: I am your brother
  cam: (p) => [K.lerp(1.1, 1.3, E(p)), 760, 520, 0], draw(c, t, d) {
  const an = B(17, 'أخوكَ', d * 0.85);
  egypt(c, t, 0.9, { sun: [1080, 160] });
  K.par(c, 1, () => {
    sacks(c, 380, 650, 10, 0.9);
    const k = A(t, an - 1.2, 1.2);
    K.presence(c, K.lerp(700, 730, k), 610, 26, t, 1);
    K.presence(c, K.lerp(860, 790, k), 620, 16, t, A(t, d * 0.4, 1));
    K.glow(c, 760, 610, 120, '#FFC869', 0.2 * k);
  });
} });
S.push({ // 18 I am Yusuf, and this is my brother; whoever fears Allah and is patient...
  cam: (p) => [K.lerp(1.2, 1.05, E(p)), 760, 470, 0], draw(c, t, d) {
  egypt(c, t, 0.95, { sun: [1060, 140] });
  K.par(c, 1, () => {
    K.presence(c, 730, 610, 30, t, 1); K.presence(c, 790, 620, 16, t, 1);
    K.rays(c, 760, 600, 10, 620, -Math.PI * 0.9, -Math.PI * 0.1, '#FFF0C8', 0.1 * A(t, d * 0.2, 1.2), t);
  });
} });
S.push({ // 19 they said: Allah has preferred you over us, we were wrong - eleven stars dim, bow
  cam: (p) => [1.0, 640, 360, 0], draw(c, t, d) {
  egypt(c, t, 0.35, { moon: [1040, 140], noPalace: false });
  K.par(c, 0.25, () => { const r = K.rng(5109); for (let i = 0; i < 10; i++) { const x = 300 + i * 72, y = 170 + 20 * Math.sin(i) + 40 * A(t, d * 0.4, 1.5); K.glow(c, x, y, 16, '#C8C8E8', 0.3); c.fillStyle = '#D8DCF0'; c.beginPath(); c.arc(x, y, 3, 0, TAU); c.fill(); } });
} });
S.push({ // 20 recitation 12:92 - forgiveness: warm dawn over Egypt
  cam: (p) => [K.lerp(1.0, 1.08, E(p)), 640, K.lerp(420, 380, E(p)), 0], draw(c, t, d, p) {
  const l = K.lerp(0.4, 0.9, E(p));
  egypt(c, t, l, { sun: [1000, K.lerp(420, 180, E(p))], cols: KIT.skyAt(l) });
  K.par(c, 1, () => { K.presence(c, 760, 610, 28, t, 1); K.glow(c, 760, 610, 260, '#FFD58A', 0.12 * E(p)); });
} });
S.push({ // 21 his shirt sent; laid on his father's face, his sight returned
  cam: (p) => [K.lerp(1.15, 1.3, E(p)), 420, 520, 0], draw(c, t, d) {
  const bs = B(21, 'بصرُهُ', d * 0.85);
  canaan(c, t, K.lerp(0.4, 0.9, A(t, bs - 0.5, 1.5)), { sun: [1080, 160] });
  K.par(c, 1, () => {
    const k = A(t, bs - 0.6, 1.2);
    shirt(c, K.lerp(560, 380, A(t, d * 0.25, 1.5)), K.lerp(620, 580, A(t, d * 0.25, 1.5)), 1.0, 1 - k);
    K.presence(c, 360, 590, 24 + 10 * k, t, 0.7 + 0.3 * k);
    K.rays(c, 360, 580, 12, 600, -Math.PI, 0, '#FFF6DA', 0.14 * k, t);
  });
} });
S.push({ // 22 Ya'qub and his family came to Egypt; honoured on the throne; the greeting - not drawn
  cam: (p) => [K.lerp(1.0, 1.08, E(p)), K.lerp(500, 760, E(p)), 420, 0], draw(c, t, d) {
  egypt(c, t, 0.95, { sun: [1060, 140] });
  K.par(c, 1, () => {
    camels(c, t, 3, 140, 640, 0.85, false, 0.95);
    K.presence(c, 900, 600, 30, t, 1); K.presence(c, 980, 610, 22, t, A(t, d * 0.25, 1.2));
    K.glow(c, 940, 560, 200, '#FFD58A', 0.15 * A(t, d * 0.25, 1.2));
  });
} });
S.push({ // 23 this is the meaning of my dream, my Lord made it true - the eleven stars, sun and moon over Egypt
  cam: (p) => [K.lerp(1.0, 1.06, E(p)), 640, K.lerp(380, 340, E(p)), 0], draw(c, t, d) {
  egypt(c, t, 0.2, { cols: NIGHT });
  K.par(c, 0.25, () => dream(c, t, A(t, 0.3, 1.5), A(t, d * 0.45, 2), 940, 600));
  K.par(c, 1, () => K.presence(c, 940, 600, 26, t, 1));
} });
S.push({ cam: (p) => [K.lerp(1.1, 1.02, E(p)), 640, K.lerp(390, 362, E(p)), 0], draw(c, t, d, p) {
  KIT.lesson(c, t, p, { seed: 5110 });
} });
window.STORY_SCENES = S;
})();
