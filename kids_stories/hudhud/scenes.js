// Sulayman, peace be upon him, and the hoopoe. VISUALS ONLY.
// Narration: docs/kids_stories/hudhud_narration.md (27:20-44 + al-Muyassar).
// Sulayman is NEVER drawn - a warm light. The hoopoe is drawn (a bird) and
// carries the story. The queen of Saba' is not drawn (caution): her empty
// throne, and later a soft light. Jinn are never drawn; the one with knowledge
// of the Book is not drawn - the throne appears in a flash of light.
'use strict';
(() => {
const { W, H } = K;
const TAU = Math.PI * 2;
const E = K.easeInOut, B = K.beat, A = K.after;
const hoopoe = (c, x, y, s, t, fly = 0, dir = 1) => {
  c.save(); c.translate(x, y); c.scale(s * dir, s);
  const f = fly ? Math.sin(t * 14) : 0.15;
  // wing (black/white bars)
  c.save(); c.rotate(-0.3 - f * 0.6); c.fillStyle = '#2A2420'; c.beginPath(); c.ellipse(-4, -6, 18, 7, 0, 0, TAU); c.fill(); c.fillStyle = '#F2EEE6'; for (let i = 0; i < 3; i++) c.fillRect(-16 + i * 9, -9, 4, 7); c.restore();
  c.fillStyle = '#D8945A'; c.beginPath(); c.ellipse(0, 0, 16, 10, 0, 0, TAU); c.fill(); // body
  c.beginPath(); c.arc(14, -8, 7, 0, TAU); c.fill(); // head
  c.strokeStyle = '#3A302A'; c.lineWidth = 2; c.beginPath(); c.moveTo(20, -8); c.quadraticCurveTo(30, -6, 34, -2); c.stroke(); // long beak
  // crest: a fan of orange feathers tipped black
  for (let i = 0; i < 5; i++) { const a = -Math.PI * (0.55 + i * 0.1); c.strokeStyle = '#E09050'; c.lineWidth = 3; c.beginPath(); c.moveTo(12, -14); c.lineTo(12 + Math.cos(a) * 14, -14 + Math.sin(a) * 14); c.stroke(); c.fillStyle = '#2A2420'; c.beginPath(); c.arc(12 + Math.cos(a) * 14, -14 + Math.sin(a) * 14, 2, 0, TAU); c.fill(); }
  c.fillStyle = '#2A2420'; c.beginPath(); c.arc(16, -9, 1.6, 0, TAU); c.fill();
  c.fillStyle = '#2A2420'; c.beginPath(); c.moveTo(-14, -2); c.lineTo(-28, -6); c.lineTo(-26, 4); c.fill(); // tail
  if (!fly) { c.strokeStyle = '#6A5040'; c.lineWidth = 2; c.beginPath(); c.moveTo(-2, 9); c.lineTo(-4, 20); c.moveTo(4, 9); c.lineTo(5, 20); c.stroke(); }
  c.restore();
};
const court = (c, t, light, o = {}) => {
  KIT.sky(c, t, light, { sun: o.sun, moon: o.moon, cols: o.cols, seed: 151 });
  KIT.land(c, light, { seed: 15.1, farCol: '#A8A090', midCol: '#9AA878' });
  K.par(c, 0.8, () => {
    KIT.ground(c, 560, light, '#B8B07A');
    c.fillStyle = K.tone('#E8D8B8', light); c.fillRect(-420, 560, W + 840, 18);
    for (let x = 80; x < W; x += 180) { c.fillStyle = K.tone('#F0E4C8', light); c.fillRect(x, 380, 24, 180); c.fillRect(x - 8, 372, 40, 12); }
  });
};
const saba = (c, t, light, o = {}) => {
  KIT.sky(c, t, light, { sun: o.sun, cols: o.cols, seed: 152 });
  K.par(c, 0.35, () => { K.ridge(c, 400, 60, 15.2, 0.8, K.tone('#8A7A6A', light)); });
  KIT.town(c, light, o.glow || 0, { seed: 15201, n: 24, ty: 540 });
};
const throne = (c, x, y, s, light, a = 1) => {
  if (a <= 0.01) return;
  c.save(); c.globalAlpha *= a; c.translate(x, y); c.scale(s, s);
  c.fillStyle = K.tone('#C89A3A', light); c.fillRect(-60, -160, 120, 30); c.beginPath(); c.arc(0, -160, 60, Math.PI, 0); c.fill();
  c.fillStyle = K.tone('#8A3E3A', light); c.fillRect(-46, -140, 92, 80);
  c.fillStyle = K.tone('#C89A3A', light); c.fillRect(-70, -60, 140, 24); c.fillRect(-64, -36, 14, 36); c.fillRect(50, -36, 14, 36);
  for (let i = 0; i < 5; i++) { c.fillStyle = ['#E0405A', '#40A0E0', '#40C080'][i % 3]; c.beginPath(); c.arc(-40 + i * 20, -172, 5, 0, TAU); c.fill(); }
  c.restore();
};
const scroll = (c, x, y, s, a = 1) => { if (a <= 0.01) return; c.save(); c.globalAlpha *= a; c.translate(x, y); c.scale(s, s); c.fillStyle = '#EFE3C4'; c.fillRect(-14, -6, 28, 12); c.fillStyle = '#B08A5C'; c.beginPath(); c.ellipse(-14, 0, 4, 8, 0, 0, TAU); c.ellipse(14, 0, 4, 8, 0, 0, TAU); c.fill(); c.fillStyle = '#A83A2A'; c.beginPath(); c.arc(0, 0, 3.5, 0, TAU); c.fill(); c.restore(); };
const birdsRow = (c, t, n, gap) => { for (let i = 0; i < n; i++) { if (i === gap) continue; const x = 300 + i * 70, y = 540 - (i % 2) * 6; c.fillStyle = ['#6A7A8A', '#8A6A5A', '#C8C0B0', '#5A6A4A'][i % 4]; c.beginPath(); c.ellipse(x, y, 14, 9, 0, 0, TAU); c.fill(); c.beginPath(); c.arc(x + 10, y - 8, 6, 0, TAU); c.fill(); c.fillStyle = '#E0A030'; c.beginPath(); c.moveTo(x + 15, y - 9); c.lineTo(x + 21, y - 7); c.lineTo(x + 15, y - 5); c.fill(); } };

const S = [];
S.push({ // 1 Sulayman inspected the birds and did not find the hoopoe
  cam: (p) => [K.lerp(1.0, 1.15, E(p)), K.lerp(560, 760, E(p)), 470, 0], draw(c, t, d) {
  court(c, t, 0.95, { sun: [1060, 150] });
  K.par(c, 0.8, () => { birdsRow(c, t, 10, 6); c.strokeStyle = K.rgba('#FFFFFF', 0.5 * A(t, d * 0.6, 0.6)); c.lineWidth = 2; c.setLineDash([6, 6]); c.beginPath(); c.ellipse(720, 535, 22, 16, 0, 0, TAU); c.stroke(); c.setLineDash([]); });
  K.par(c, 1, () => K.presence(c, 180, 620, 28, t, 1));
} });
S.push({ // 2 he wanted to know his excuse for being absent
  cam: (p) => [K.lerp(1.15, 1.25, E(p)), 400, 520, 0], draw(c, t, d) {
  court(c, t, 0.9, { sun: [1060, 180] });
  K.par(c, 0.8, () => birdsRow(c, t, 10, 6));
  K.par(c, 1, () => K.presence(c, 260, 620, 28, t, 1));
} });
S.push({ // 3 the hoopoe came after a while: I bring you sure news from Saba' in Yemen
  cam: (p) => [K.lerp(1.0, 1.2, E(p)), 520, 500, 0], draw(c, t, d) {
  court(c, t, 0.9, { sun: [1060, 180] });
  K.par(c, 0.8, () => birdsRow(c, t, 10, 6));
  K.par(c, 1, () => { const k = A(t, 0.2, d * 0.5); hoopoe(c, K.lerp(1300, 440, k), K.lerp(200, 600, k), 1.6, t, k < 1 ? 1 : 0, -1); K.presence(c, 300, 620, 28, t, 1); });
} });
S.push({ // 4 I found a woman ruling them; she has a great throne
  cam: (p) => [K.lerp(1.0, 1.1, E(p)), 640, 420, 0], draw(c, t, d) {
  saba(c, t, 0.9, { sun: [1060, 160] });
  K.par(c, 1, () => { throne(c, 640, 650, 1.2, 0.9, A(t, d * 0.3, 1)); K.glow(c, 640, 520, 160, '#FFE6A8', 0.2); });
  K.par(c, 0.4, () => hoopoe(c, K.lerp(300, 1100, A(t, 0, d, (x) => x)), 200, 1.0, t, 1));
} });
S.push({ // 5 she and her people bow to the sun instead of Allah
  cam: (p) => [K.lerp(1.0, 1.06, E(p)), 640, 400, 0], draw(c, t, d) {
  saba(c, t, 0.75, { sun: [640, 240], cols: ['#5A5A8A', '#D88A6A', '#F2C08B'] });
  K.par(c, 0.6, () => K.rays(c, 640, 240, 12, 700, 0, TAU, '#FFD08A', 0.08, t));
  K.par(c, 1, () => KIT.crowd(c, 15202, 16, 200, 1080, 670, 1.0, t, { face: 1 }));
} });
S.push({ // 6 we will see if you told the truth: take this letter of mine to them
  cam: (p) => [K.lerp(1.2, 1.3, E(p)), 420, 540, 0], draw(c, t, d) {
  const kt = B(6, 'بكتابي', d * 0.75);
  court(c, t, 0.9, { sun: [1060, 180] });
  K.par(c, 1, () => { K.presence(c, 300, 620, 28, t, 1); hoopoe(c, 440, 600, 1.6, t, 0, -1); scroll(c, 380, 610, 1.4, A(t, kt - 0.3, 0.8)); });
} });
S.push({ // 7 the hoopoe dropped it to the queen; she gathered her nobles: a noble letter has come
  cam: (p) => [K.lerp(1.0, 1.12, E(p)), 640, 460, 0], draw(c, t, d) {
  saba(c, t, 0.85, { sun: [1060, 180] });
  K.par(c, 1, () => {
    throne(c, 640, 630, 1.0, 0.85);
    const k = A(t, 0.3, d * 0.4);
    hoopoe(c, K.lerp(200, 700, k), K.lerp(200, 380, k), 1.2, t, 1);
    scroll(c, K.lerp(200, 640, k), K.lerp(214, 590 * k + 214 * (1 - k), A(t, d * 0.45, 1)), 1.4, 1);
    K.glow(c, 640, 540, 110, '#FFF0D8', 0.25);
    KIT.crowd(c, 15203, 10, 300, 540, 665, 1.0, t, { face: 1, appear: A(t, d * 0.5, 1) }); KIT.crowd(c, 15204, 10, 740, 980, 665, 1.0, t, { face: -1, appear: A(t, d * 0.5, 1) });
  });
} });
S.push({ // 8 recitation 27:30 - the letter in the light
  cam: (p) => [K.lerp(1.4, 1.6, E(p)), 640, 560, 0], draw(c, t, d) {
  saba(c, t, 0.7, { sun: [1100, 280] });
  K.par(c, 1, () => { throne(c, 640, 630, 1.0, 0.7); K.glow(c, 640, 590, 90, '#FFF6DA', 0.4); scroll(c, 640, 590, 2.2, 1); });
} });
S.push({ // 9 do not be proud, come to me in submission to Allah
  cam: (p) => [K.lerp(1.2, 1.05, E(p)), 640, 480, 0], draw(c, t, d) {
  saba(c, t, 0.8, { sun: [1080, 220] });
  K.par(c, 1, () => { throne(c, 640, 630, 1.0, 0.8); scroll(c, 640, 590, 1.6, 1); K.rays(c, 640, 590, 8, 520, -Math.PI * 0.85, -Math.PI * 0.15, '#FFF0C8', 0.1, t); KIT.crowd(c, 15203, 10, 300, 540, 665, 1.0, t, { face: 1 }); KIT.crowd(c, 15204, 10, 740, 980, 665, 1.0, t, { face: -1 }); });
} });
S.push({ // 10 she consulted, then sent Sulayman a gift of precious wealth
  cam: (p) => [1.04, K.lerp(500, 760, E(p)), 440, 0], draw(c, t, d) {
  court(c, t, 0.9, { sun: [1060, 180] });
  K.par(c, 1, () => {
    const k = A(t, 0, d * 0.8, (x) => x);
    for (let i = 0; i < 3; i++) { const x = 1300 - 380 * k + i * 140; K.animal(c, 'camel', x, 640, 0.9, t * 3 + i, 0); c.fillStyle = '#C89A3A'; c.fillRect(x - 20, 570, 40, 22); K.glow(c, x, 580, 30, '#FFE070', 0.4); }
    K.presence(c, 260, 620, 28, t, 1);
  });
} });
S.push({ // 11 what Allah gave me is better than what He gave you - he did not accept it
  cam: (p) => [K.lerp(1.15, 1.25, E(p)), 520, 520, 0], draw(c, t, d) {
  court(c, t, 0.9, { sun: [1060, 180] });
  K.par(c, 1, () => {
    const back = A(t, d * 0.6, d * 0.4, (x) => x);
    for (let i = 0; i < 3; i++) { const x = 920 + i * 140 + 500 * back; K.animal(c, 'camel', x, 640, 0.9, t * 3 + i, 0); c.fillStyle = '#C89A3A'; c.fillRect(x - 20, 570, 40, 22); }
    K.presence(c, 260, 620, 30, t, 1); K.rays(c, 260, 610, 9, 600, -Math.PI * 0.85, -Math.PI * 0.15, '#FFF0C8', 0.1, t);
  });
} });
S.push({ // 12 who will bring her throne? The one with knowledge of the Book: before you blink - he prayed, and it came
  cam: (p) => [K.lerp(1.0, 1.1, E(p)), 640, 460, 0], draw(c, t, d) {
  const ja = B(12, 'فجاءَ', d * 0.9);
  court(c, t, 0.9, { sun: [1060, 180] });
  K.par(c, 1, () => {
    K.presence(c, 260, 620, 28, t, 1);
    const q = K.clamp((t - ja + 0.2) / 0.5);
    if (q > 0 && q < 1) { K.glow(c, 760, 540, 260 * (1 - q) + 60, '#FFFFFF', 0.9 * (1 - q)); }
    throne(c, 760, 640, 1.1, 0.9, A(t, ja, 0.3));
  });
} });
S.push({ // 13 seeing it there: this is from my Lord's bounty, to test me - will I be grateful?
  cam: (p) => [K.lerp(1.1, 1.2, E(p)), 520, 500, 0], draw(c, t, d) {
  court(c, t, 0.9, { sun: [1060, 180] });
  K.par(c, 1, () => { throne(c, 760, 640, 1.1, 0.9); K.presence(c, 360, 620, 30, t, 1); K.rays(c, 360, 610, 10, 640, -Math.PI * 0.9, -Math.PI * 0.1, '#FFF0C8', 0.12 * A(t, d * 0.3, 1), t); });
} });
S.push({ // 14 the queen came, saw Allah's power and Sulayman's truth: I submit with Sulayman to Allah
  cam: (p) => [K.lerp(1.0, 1.08, E(p)), 640, 440, 0], draw(c, t, d) {
  const sl = B(14, 'أسلمْتُ', d * 0.7);
  court(c, t, 0.85, { sun: [1080, 220] });
  K.par(c, 1, () => {
    throne(c, 900, 640, 1.0, 0.85);
    K.presence(c, 380, 620, 28, t, 1);
    const k = A(t, 0, d * 0.5);
    c.save(); c.globalCompositeOperation = 'lighter'; K.glow(c, K.lerp(1200, 620, k), 620, 40, '#FFE6C0', 0.35); K.glow(c, K.lerp(1200, 620, k), 620, 16, '#FFF8EC', 0.5); c.restore();
    K.glow(c, 500, 600, 260, '#FFE6A8', 0.18 * A(t, sl - 0.3, 1.2));
  });
  K.par(c, 0.6, () => hoopoe(c, 1000, 470, 1.0, t, 0, -1));
} });
S.push({ cam: (p) => [K.lerp(1.1, 1.02, E(p)), 640, K.lerp(390, 362, E(p)), 0], draw(c, t, d, p) {
  KIT.lesson(c, t, p, { seed: 15205, mid: () => K.par(c, 0.9, () => hoopoe(c, 980, 580, 1.4, t, 0, -1)) });
} });
window.STORY_SCENES = S;
})();
