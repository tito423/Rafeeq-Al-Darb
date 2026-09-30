// Story 1 - Nuh (Noah), peace be upon him. VISUALS ONLY.
// Scene list and the verse each rests on: docs/kids_stories_brief.md.
// Rules kept here: no human figure of any kind, no text drawn, nothing added
// beyond the brief's scene list (no rainbow, no dove, no oven, no labels).
// Each scene: draw(ctx, t, d, p) with t = local seconds (may run 0.35 s past
// either end during a cross-fade), d = the scene's duration from timing.json,
// p = clamp(t / d). Motion that must fit the narration is keyed to p; motion
// with a natural speed (rain, waves, ripples) is keyed to t.
'use strict';
(() => {
const { W, H } = K;
const TAU = Math.PI * 2;
const E = K.easeInOut;

// ---- shared pieces ----
const SKY = {
  night: ['#10183A', '#1E2A55', '#34406E'],
  dusk: ['#2F2B5C', '#9A537A', '#F2A56B'],
  day: ['#5DA9D6', '#A3D2E6', '#F4E3C0'],
};
const skyAt = (light) => {
  const [a, b, t] = light < 0.5 ? [SKY.night, SKY.dusk, light * 2] : [SKY.dusk, SKY.day, (light - 0.5) * 2];
  return a.map((c, i) => K.mix(c, b[i], t));
};
// A valley: far ranges, two sides rising toward the frame edges.
const valleySide = (c, y0, rise, seed, col) => {
  c.fillStyle = col;
  c.beginPath(); c.moveTo(-420, H + 420);
  for (let x = -420; x <= W + 420; x += 8) {
    const d = Math.abs(x - W / 2) / (W / 2);
    c.lineTo(x, y0 - rise * Math.pow(d, 1.8) - K.ridgeY(x, seed, 14, 1.4));
  }
  c.lineTo(W + 420, H + 420); c.closePath(); c.fill();
};
const valley = (c, light, t) => {
  K.ridge(c, 405, 60, 1.3, 0.7, K.tone('#C49A8C', light));
  K.ridge(c, 440, 40, 4.2, 1.1, K.tone('#B98368', light));
  valleySide(c, 470, 190, 2.2, K.tone('#B77A55', light));
  valleySide(c, 505, 120, 7.7, K.tone('#C98E5E', light));
};
const ground = (c, y, light, col = '#D9A86C') => {
  const g = c.createLinearGradient(0, y, 0, H + 60);
  g.addColorStop(0, K.tone(col, light)); g.addColorStop(1, K.tone(K.mix(col, '#8A5A3C', 0.35), light));
  c.fillStyle = g; c.fillRect(-420, y, W + 840, H - y + 420);
};
// One day/night cycle: u in [0,1): 0 sunrise, .25 noon, .5 sunset, .75 midnight.
const cycle = (u) => ({ light: K.smooth(0.5 + 0.9 * Math.sin(u * TAU)), u });
const arcPos = (v, h, horizon) => [K.lerp(-80, W + 80, v), horizon - Math.sin(Math.PI * v) * h];

// ---- 1. Stone idols in an old valley town at dusk (Nuh 71:23) ----
const IDOLS = [['boulder', 400, 118], ['slab', 515, 150], ['obelisk', 640, 178], ['stepped', 765, 142], ['column', 880, 124]];
const s1 = {
  cam: (p) => [K.lerp(1.0, 1.12, E(p)), K.lerp(640, 630, E(p)), K.lerp(360, 410, E(p))],
  draw(c, t, d, p) {
    const light = K.lerp(0.5, 0.38, p);
    K.sky(c, skyAt(light), 0, 470);
    K.stars(c, 23, 90, K.seg(p, 0.45, 1) * 0.75, t, 330);
    K.sun(c, 250, K.lerp(420, 492, E(p)), 30, '#FFE1A0', '#FF9E5E', 0.5);
    valley(c, light, t);
    ground(c, 520, light);
    K.town(c, 71, 16, 250, 1030, 505, 0.85, light, K.seg(p, 0.35, 0.9));
    K.palm(c, 205, 540, 120, K.tone('#6B4A34', light), K.tone('#5E7A45', light), Math.sin(t * 0.9));
    K.palm(c, 1085, 545, 140, K.tone('#6B4A34', light), K.tone('#5E7A45', light), Math.sin(t * 0.8 + 1));
    // the stone platform
    c.fillStyle = K.tone('#B08E70', light); c.beginPath(); c.roundRect(300, 598, 690, 22, 6); c.fill();
    c.fillStyle = K.tone('#8C6E56', light); c.fillRect(306, 616, 678, 18);
    // long evening shadows fall away from the low sun on the left
    for (const [kind, x, h] of IDOLS) {
      c.fillStyle = K.rgba('#3A2433', 0.28);
      c.beginPath(); c.moveTo(x - h * 0.2, 604); c.lineTo(x + h * 0.2, 604); c.lineTo(x + h * 1.2, 612); c.lineTo(x + h * 0.9, 614); c.closePath(); c.fill();
    }
    for (const [kind, x, h] of IDOLS) {
      K.stone(c, kind, x, 606, h, K.tone('#9C8A78', light), K.tone('#C7AE8E', light * 1.1), K.tone('#6E5E54', light));
    }
    ground(c, 634, light, '#C99A62');
  },
};

// ---- 2. Day and night over the town, again and again (Nuh 71:5) ----
const townView = (c, t, light, glow, st) => {
  const sk = skyAt(light);
  K.sky(c, sk, 0, 500);
  K.stars(c, 5, 110, K.clamp(1 - light * 2) * 0.9, t, 360);
  st();
  valley(c, light, t);
  ground(c, 540, light);
  K.town(c, 12, 22, 170, 1110, 548, 1.15, light, glow);
  K.palm(c, 120, 640, 190, K.tone('#6B4A34', light), K.tone('#5E7A45', light), Math.sin(t * 0.9));
  K.palm(c, 1170, 650, 210, K.tone('#6B4A34', light), K.tone('#5E7A45', light), Math.sin(t * 0.7 + 2));
  for (const [x, s] of [[330, 1.2], [520, 0.9], [860, 1.1], [980, 0.8]]) K.shrub(c, x, 660, s, K.tone('#8C8C4E', light));
};
const s2 = {
  cam: (p) => [K.lerp(1.02, 1.08, p), 640, K.lerp(370, 385, p)],
  draw(c, t, d, p) {
    // whole cycles, never faster than one per ~2.7 s (no flashing)
    const n = Math.max(2, Math.round(d / 2.7));
    const phi = 0.02 + p * n;
    const { light, u } = cycle(K.fract(phi));
    townView(c, t, light, K.clamp(1 - light * 1.8), () => {
      if (u < 0.52) { const [x, y] = arcPos(u / 0.5, 360, 520); K.sun(c, x, y, 34); }
      if (u > 0.48) { const [x, y] = arcPos((u - 0.5) / 0.5, 330, 520); K.moon(c, x, y, 30); }
    });
  },
};

// ---- 3. Sun and moon racing: very many years (al-Ankabut 29:14) ----
// Accelerates from 0.3 to 1.2 day-night cycles per second - capped there so
// the brightness change stays well under the 3-flashes-per-second
// photosensitivity guideline; as it speeds up the sky's contrast is softened
// toward its average and the sun and moon draw short comet-like tails. (Full
// arcs were tried first and read as a rainbow, which the brief rules out.)
const MEAN_SKY = ['#2A2E5E', '#58577F', '#A28C8A'];
const s3 = {
  cam: (p) => [K.lerp(1.14, 1.0, E(p)), 640, K.lerp(400, 360, E(p))],
  draw(c, t, d, p) {
    const v0 = 0.3, v1 = 1.2, tt = K.clamp(t, -1, d + 1);
    const phi = 0.1 + v0 * tt + (v1 - v0) * tt * tt / (2 * d);
    const speed = v0 + (v1 - v0) * K.clamp(tt / d);
    const blur = K.smooth((speed - 0.45) / 0.75) * 0.6;
    const { light: l0, u } = cycle(K.fract(phi));
    const light = K.lerp(l0, 0.45, blur);
    const sk = skyAt(l0).map((col, i) => K.mix(col, MEAN_SKY[i], blur));
    K.sky(c, sk, 0, 500);
    K.stars(c, 9, 120, K.clamp(K.clamp(1 - l0 * 2) * (1 - blur) + blur * 0.4), t, 360);
    const tail = (v, h, col, r) => {
      const len = 0.16 * speed;
      for (let k = 14; k >= 1; k--) {
        const vv = v - (k / 14) * len;
        if (vv < 0) continue;
        const [x, y] = arcPos(vv, h, 520);
        c.fillStyle = K.rgba(col, 0.22 * (1 - k / 14));
        c.beginPath(); c.arc(x, y, r * (1 - k / 20), 0, TAU); c.fill();
      }
    };
    if (u < 0.52) { const v = u / 0.5, [x, y] = arcPos(v, 360, 520); tail(v, 360, '#FFD98A', 30); K.sun(c, x, y, 32); }
    if (u > 0.48) { const v = (u - 0.5) / 0.5, [x, y] = arcPos(v, 300, 520); tail(v, 300, '#EEF0FF', 22); K.moon(c, x, y, 28); }
    valley(c, light, t);
    ground(c, 540, light);
    K.town(c, 12, 22, 170, 1110, 548, 1.15, light, K.clamp(1 - light * 1.8) * 0.8);
    K.palm(c, 120, 640, 190, K.tone('#6B4A34', light), K.tone('#5E7A45', light), 0);
    K.palm(c, 1170, 650, 210, K.tone('#6B4A34', light), K.tone('#5E7A45', light), 0);
  },
};

// ---- 4. The ark takes shape from planks and pegs (Hud 11:37, al-Qamar 54:13) ----
const openLand = (c, t, light) => {
  K.sky(c, ['#78B6D6', '#B9DDEA', '#F6E7C6'], 0, 520);
  K.sun(c, 1040, 130, 36, '#FFF1C4', '#FFD68A', 0.45);
  for (const [x, y, s, v] of [[180, 120, 0.9, 7], [520, 80, 0.7, 5], [860, 150, 1.0, 6], [1250, 90, 0.8, 4]]) K.cloud(c, K.mod(x + t * v + 200, W + 400) - 200, y, s, '#FFF8EC', 0.92);
  K.ridge(c, 470, 50, 3.3, 0.8, K.tone('#B7A58E', light));
  K.ridge(c, 515, 34, 8.1, 1.2, K.tone('#C9A77A', light));
  ground(c, 540, light, '#DDB679');
};
const plankPile = (c, x, y, n, light) => {
  for (let i = 0; i < n; i++) {
    const r = Math.floor(i / 2), off = (i % 2) * 58 + (r % 2) * 12;
    c.fillStyle = K.tone('#5E3A22', light); c.fillRect(x + off, y - (r + 1) * 11, 110, 11);
    c.fillStyle = K.tone(i % 3 ? '#A86C40' : '#B27849', light); c.fillRect(x + off + 1.5, y - (r + 1) * 11 + 1.5, 107, 8);
  }
};
const s4 = {
  cam: (p) => [K.lerp(1.04, 1.13, E(p)), K.lerp(640, 660, E(p)), K.lerp(380, 400, E(p))],
  draw(c, t, d, p) {
    openLand(c, t, 1);
    for (const [x, s] of [[120, 1.3], [260, 0.9], [1180, 1.1], [980, 0.7]]) K.shrub(c, x, 600, s, '#8E9A55');
    const build = K.lerp(0.0, 1, K.seg(p, 0.03, 0.9));
    c.fillStyle = K.rgba('#6B4A2E', 0.18); c.beginPath(); c.ellipse(640, 612, 300, 14, 0, 0, TAU); c.fill();
    K.ark(c, 640, 612 - 200 * 0.8, 0.8, { build, blocks: true, door: 'none' });
    plankPile(c, 1000, 640, Math.round((1 - build) * 14) + 2, 1);
  },
};

// ---- 5. The town beside the growing ark, quiet (Hud 11:38) ----
const s5 = {
  cam: (p) => [1.14, K.lerp(520, 780, E(p)), 370],
  draw(c, t, d, p) {
    const light = 0.78;
    K.sky(c, ['#6E9CC6', '#DDBE98', '#F6D29A'], 0, 520);
    K.sun(c, 150, 300, 32, '#FFE7B0', '#FFB870', 0.45);
    for (const [x, y, s, v] of [[300, 120, 0.8, 4], [760, 90, 0.9, 3], [1180, 140, 0.7, 5]]) K.cloud(c, K.mod(x + t * v + 200, W + 400) - 200, y, s, '#FFF1DE', 0.8);
    K.ridge(c, 440, 55, 1.9, 0.7, K.tone('#C49A8C', light));
    K.ridge(c, 490, 35, 5.4, 1.1, K.tone('#C0906A', light));
    ground(c, 540, light);
    K.town(c, 33, 16, -140, 470, 556, 1.0, light, 0);
    K.palm(c, 505, 600, 150, K.tone('#6B4A34', light), K.tone('#5E7A45', light), Math.sin(t * 0.9));
    const build = K.lerp(0.72, 0.9, K.seg(p, 0.05, 0.95));
    c.fillStyle = K.rgba('#6B4A2E', 0.18); c.beginPath(); c.ellipse(930, 612, 240, 11, 0, 0, TAU); c.fill();
    K.ark(c, 930, 612 - 200 * 0.64, 0.64, { build, blocks: true, light, door: 'none' });
    plankPile(c, 1150, 640, Math.round((1 - build) * 14) + 2, light);
    for (const [x, s] of [[640, 1.2], [700, 0.8], [1260, 1.0]]) K.shrub(c, x, 650, s, K.tone('#8E9A55', light));
  },
};

// ---- 6. Water wells up out of the ground (Hud 11:40) ----
// The exegetes differ on what al-tannur is, so no oven is drawn: only water
// rising from the earth.
const CRACKS = (() => {
  const r = K.rng(1140), out = [];
  for (let i = 0; i < 9; i++) {
    const a = (i / 9) * TAU + r() * 0.5, pts = [[0, 0]];
    let x = 0, y = 0;
    for (let k = 0; k < 5; k++) { const aa = a + (r() - 0.5) * 0.8, l = 24 + r() * 30; x += Math.cos(aa) * l; y += Math.sin(aa) * l * 0.32; pts.push([x, y]); }
    out.push(pts);
  }
  return out;
})();
const STONES = [[-260, 30, 22], [180, 40, 16], [320, 10, 26], [-120, 90, 18], [420, 120, 30], [-420, 140, 26], [90, 170, 20]];
const s6 = {
  cam: (p) => [K.lerp(1.0, 1.16, E(p)), 640, K.lerp(420, 450, E(p))],
  draw(c, t, d, p) {
    const light = 0.8, cx = 640, cy = 505;
    K.sky(c, ['#8B8FA8', '#C6B6A8', '#E3CDAE'], 0, 400);
    for (const [x, y, s] of [[200, 110, 1.1], [620, 70, 1.3], [1040, 120, 1.0]]) K.cloud(c, x + t * 3, y, s, '#B7B1B6', 0.85);
    K.ridge(c, 360, 40, 2.6, 0.8, K.tone('#A99589', light));
    K.ridge(c, 395, 26, 6.3, 1.2, K.tone('#B99270', light));
    const g = c.createLinearGradient(0, 390, 0, H);
    g.addColorStop(0, '#C9A06C'); g.addColorStop(1, '#A87A4E');
    c.fillStyle = g; c.fillRect(-420, 390, W + 840, 800);
    for (const [x, y, r] of STONES) {
      c.fillStyle = '#8E7560'; c.beginPath(); c.ellipse(cx + x, cy + y, r, r * 0.55, 0, 0, TAU); c.fill();
      c.fillStyle = '#A88D74'; c.beginPath(); c.ellipse(cx + x - r * 0.2, cy + y - r * 0.15, r * 0.6, r * 0.3, 0, 0, TAU); c.fill();
    }
    // cracks first darken, then fill with water
    const wet = K.seg(p, 0.02, 0.2);
    c.lineCap = 'round'; c.lineJoin = 'round';
    for (const pts of CRACKS) {
      c.strokeStyle = K.mix('#6E4C32', '#3E8E9A', wet); c.lineWidth = 3 + wet * 2;
      c.beginPath(); pts.forEach(([x, y], i) => (i ? c.lineTo(cx + x, cy + y) : c.moveTo(cx + x, cy + y))); c.stroke();
    }
    // the pool widens and rises
    const k = K.seg(p, 0.12, 1);
    const rx = 16 + 1150 * (k * k * 0.6 + k * 0.4), ry = rx * 0.3;
    if (k > 0) {
      const pg = c.createRadialGradient(cx, cy, 0, cx, cy, rx);
      pg.addColorStop(0, '#6CC0C2'); pg.addColorStop(0.6, '#4AA0AA'); pg.addColorStop(1, '#3B8A9A');
      c.save(); c.translate(cx, cy); c.scale(1, 0.3);
      c.fillStyle = pg; c.globalAlpha = 0.93; c.beginPath(); c.arc(0, 0, rx, 0, TAU); c.fill();
      c.globalAlpha = 1; c.strokeStyle = K.rgba('#E9FAF7', 0.7); c.lineWidth = 5; c.beginPath(); c.arc(0, 0, rx, 0, TAU); c.stroke();
      // ripples travel outward
      for (let i = 0; i < 4; i++) {
        const q = K.fract(t / 1.6 + i / 4), rr = q * rx;
        c.strokeStyle = K.rgba('#E9FAF7', 0.5 * (1 - q)); c.lineWidth = 4;
        c.beginPath(); c.arc(0, 0, rr, 0, TAU); c.stroke();
      }
      c.restore();
    }
    // the welling: a low dome that swells and settles
    const w = K.seg(p, 0.06, 0.2);
    if (w > 0) {
      const hb = w * (16 + 6 * Math.sin(t * 5.2) + 3 * Math.sin(t * 8.3));
      c.fillStyle = '#8AD3D0';
      c.beginPath(); c.ellipse(cx, cy, 44 * w + 10, hb + 4, 0, Math.PI, TAU); c.fill();
      c.fillStyle = K.rgba('#FFFFFF', 0.5); c.beginPath(); c.ellipse(cx - 8, cy - hb * 0.6, 12 * w, hb * 0.25 + 1, 0, 0, TAU); c.fill();
      const r = K.rng(611);
      for (let i = 0; i < 14; i++) {
        const ph = r(), ang = -Math.PI / 2 + (r() - 0.5) * 1.6, sp = 40 + r() * 50;
        const q = K.fract(t * 0.9 + ph);
        const x = cx + Math.cos(ang) * sp * q * w, y = cy - hb + Math.sin(ang) * sp * q * w + 60 * q * q;
        c.fillStyle = K.rgba('#D9F4F2', 0.8 * (1 - q) * w); c.beginPath(); c.arc(x, y, 3 + r() * 2, 0, TAU); c.fill();
      }
    }
  },
};

// ---- 7. Animals in pairs walk up into the ark (Hud 11:40) ----
const GY7 = 600, ARK7 = { x: 860, s: 0.8 };
const ark7y = GY7 - 200 * ARK7.s;
const RAMP0 = ARK7.x - 500 * ARK7.s, DOORX = ARK7.x + K.ARK.doorX0 * ARK7.s, DOORY = ark7y + 122 * ARK7.s;
const pathY = (x) => (x < RAMP0 ? GY7 : x < DOORX ? GY7 - (x - RAMP0) * (GY7 - DOORY) / (DOORX - RAMP0) : DOORY);
const RAMP_ANG = -Math.atan((GY7 - DOORY) / (DOORX - RAMP0));
const QUEUE = ['elephant', 'camel', 'lion', 'horse', 'sheep'];
const SA = 0.74;
const s7 = {
  cam: (p) => [1.12, K.lerp(690, 740, E(p)), K.lerp(455, 440, E(p))],
  draw(c, t, d, p) {
    const light = 0.72;
    K.sky(c, ['#6F7690', '#A99D9A', '#D8BE98'], 0, 520);
    for (const [x, y, s] of [[160, 110, 1.3], [520, 70, 1.5], [900, 120, 1.4], [1250, 80, 1.2]]) K.cloud(c, x + t * 5, y, s, '#8C8793', 0.9);
    K.ridge(c, 470, 50, 3.3, 0.8, K.tone('#A7968C', light));
    K.ridge(c, 520, 30, 8.1, 1.2, K.tone('#B99270', light));
    ground(c, 560, light, '#C39A66');
    for (const [x, y, rx] of [[220, 640, 70], [420, 680, 50], [1120, 650, 80], [980, 700, 60]]) {
      c.fillStyle = K.rgba('#6FA6AE', 0.75); c.beginPath(); c.ellipse(x, y, rx, rx * 0.16, 0, 0, TAU); c.fill();
      c.fillStyle = K.rgba('#D6EEF0', 0.35); c.beginPath(); c.ellipse(x - rx * 0.2, y - 1, rx * 0.4, rx * 0.04, 0, 0, TAU); c.fill();
    }
    K.ark(c, ARK7.x, ark7y, ARK7.s, { build: 1, blocks: true, door: 'open', ramp: true, light });
    // the queue: two of each kind, one close behind the other, a clear gap
    // between one pair and the next so each pair reads as a pair
    const travel = 660, lead = 540 + p * travel;
    c.save();
    c.beginPath(); c.rect(-1000, -1000, DOORX + 1000, 3000); c.clip();
    let off = 0;
    const draws = [];
    for (const type of QUEUE) {
      const L = K.ANIMALS[type].len * SA;
      draws.push([type, lead - off], [type, lead - off - L - 6]);
      off += 2 * L + 6 + 70;
    }
    for (const [type, ax] of draws.reverse()) {
      if (ax > DOORX + 160) continue;
      const onRamp = ax > RAMP0 && ax < DOORX;
      K.animal(c, type, ax, pathY(ax), SA, ax / 22, onRamp ? RAMP_ANG : 0);
    }
    c.restore();
  },
};

// ---- 8. The sky's gates pour, springs burst, the waters meet (al-Qamar 54:11-12) ----
// Drawn as breaks in the cloud from which torrents fall - no architecture in
// the sky.
const GATES = [200, 500, 800, 1090];
const SPRINGS = [[350, 0.0], [650, 0.12], [950, 0.06], [90, 0.18], [1200, 0.2]];
const s8 = {
  cam: (p) => [K.lerp(1.02, 1.1, E(p)), 640, K.lerp(380, 400, E(p))],
  draw(c, t, d, p) {
    K.sky(c, ['#2F3856', '#4D5A7C', '#7D8CA6'], 0, 520);
    K.ridge(c, 470, 45, 2.9, 0.8, '#4E566F');
    K.ridge(c, 520, 30, 6.1, 1.2, '#5F6377');
    c.fillStyle = '#6A6470'; c.fillRect(-420, 540, W + 840, 600);
    const level = K.lerp(700, 470, E(K.seg(p, 0.1, 1)));
    const open = K.easeOut(K.seg(p, 0.02, 0.3));
    // torrents
    for (let i = 0; i < GATES.length; i++) {
      const x = GATES[i], w = 64 * open * (0.85 + 0.15 * Math.sin(i * 2.1));
      if (w < 1) continue;
      const g = c.createLinearGradient(0, 150, 0, level);
      g.addColorStop(0, K.rgba('#CFE3EE', 0.9)); g.addColorStop(1, K.rgba('#7FA9C4', 0.75));
      c.fillStyle = g; c.fillRect(x - w / 2, 150, w, level - 150);
      c.strokeStyle = K.rgba('#FFFFFF', 0.45); c.lineWidth = 2;
      c.beginPath();
      for (let k = 0; k < 5; k++) {
        const lx = x - w / 2 + (k + 0.5) * w / 5;
        for (let y = K.mod(t * 420 + k * 37, 90) + 150; y < level; y += 90) { c.moveTo(lx, y); c.lineTo(lx, Math.min(level, y + 38)); }
      }
      c.stroke();
      c.fillStyle = K.rgba('#E6F2F6', 0.8); c.beginPath(); c.ellipse(x, level, w * 0.9, 9 + Math.sin(t * 9 + i) * 2, 0, 0, TAU); c.fill();
    }
    // springs bursting up from the earth: fans of arcing jets
    c.lineCap = 'round';
    for (const [x, delay] of SPRINGS) {
      const k = K.easeOut(K.seg(p, 0.12 + delay, 0.4 + delay));
      if (k <= 0) continue;
      const hj = k * (120 + 22 * Math.sin(t * 4 + x)), base = Math.min(level, 640);
      for (let j = -3; j <= 3; j++) {
        const sp = j * 22 * k, ah = hj * (1 - Math.abs(j) * 0.16);
        c.strokeStyle = K.rgba(Math.abs(j) % 2 ? '#8CC8DB' : '#B9E3EE', 0.9);
        c.lineWidth = 8 - Math.abs(j) * 1.4;
        c.beginPath(); c.moveTo(x, base);
        if (j === 0) c.lineTo(x, base - ah);
        else c.quadraticCurveTo(x + sp, base - 2 * ah, x + 2 * sp, base - ah * 0.25);
        c.stroke();
      }
      const r = K.rng(x | 0);
      for (let i = 0; i < 14; i++) {
        const q = K.fract(t * 1.1 + r()), a = -Math.PI / 2 + (r() - 0.5) * 2.6;
        c.fillStyle = K.rgba('#D9F1F6', 0.85 * (1 - q) * k);
        c.beginPath(); c.arc(x + Math.cos(a) * 70 * q, base - hj + Math.sin(a) * 40 * q + 80 * q * q, 3, 0, TAU); c.fill();
      }
    }
    // the rising water
    K.water(c, (x) => level + 7 * Math.sin(x * 0.02 + t * 2.2) + 4 * Math.sin(x * 0.047 - t * 3.1), level - 20, H + 60, '#4E8FAD', '#23506E', K.rgba('#CFE6EE', 0.8), 3);
    // the cloud ceiling, with lit breaks where the torrents begin
    for (let i = 0; i < 9; i++) K.cloud(c, -60 + i * 175 + Math.sin(t * 0.3 + i) * 6, 110 + (i % 2) * 30, 1.5, i % 2 ? '#454F6C' : '#525C7A');
    for (let i = 0; i < GATES.length; i++) {
      K.glow(c, GATES[i], 150, 90 * open + 1, '#C9DCE8', 0.45 * open);
    }
    K.rain(c, t, 88, 220, 0.4, -60, 900, 26);
  },
};

// ---- 9. The ark sails on waves like mountains (Hud 11:42) ----
const swell = (x, t, base, A, L, v, ph = 0) => {
  const th = ((x - v * t) / L) * TAU + ph;
  return base - A * (Math.sin(th) + 0.28 * Math.sin(2 * th - Math.PI / 2));
};
const s9 = {
  cam: (p, t) => {
    const y = swell(640, t, 470, 95, 820, 70);
    return [1.08, K.lerp(600, 680, p), K.lerp(360, y - 10, 0.35)];
  },
  draw(c, t, d, p) {
    K.sky(c, ['#3B4668', '#5B6B8C', '#8D9EB3'], 0, 480);
    for (let i = 0; i < 7; i++) K.cloud(c, K.mod(-100 + i * 230 + t * 12, W + 500) - 250, 90 + (i % 3) * 30, 1.4, i % 2 ? '#4A5576' : '#56627F');
    K.rain(c, t, 9, 160, 0.3, -140, 900, 24);
    K.water(c, (x) => swell(x, t, 380, 60, 520, 40, 1.3), 300, H, '#3F6F8F', '#2A4F6C', K.rgba('#B8D4E0', 0.5), 2);
    const surf = (x) => swell(x, t, 470, 95, 820, 70);
    K.water(c, surf, 360, H + 100, '#3F86A2', '#1F4F6A', K.rgba('#E3F2F4', 0.85), 4);
    // the ark rides the middle swell
    const ax = 640, s = 0.42, y0 = surf(ax), slope = (surf(ax + 20) - surf(ax - 20)) / 40;
    c.save(); c.translate(ax, y0 - 70 * s); c.rotate(K.clamp(Math.atan(slope) * 0.35, -0.16, 0.16));
    K.ark(c, 0, 0, s, { build: 1, door: 'closed', light: 0.72 });
    c.restore();
    // near swell in front of the hull
    c.globalAlpha = 0.9;
    K.water(c, (x) => swell(x, t, 610, 55, 600, 90, 2.2) + 26, 520, H + 100, '#357A97', '#1C4861', K.rgba('#E3F2F4', 0.8), 3);
    c.globalAlpha = 1;
  },
};

// ---- 10. A great wave rises and fills the view, then calm (Hud 11:43) ----
// Only the wave is drawn; the verse's event is told by the narrator.
const BUBBLES = (() => { const r = K.rng(1143), o = []; for (let i = 0; i < 40; i++) o.push([r() * W, r(), 3 + r() * 7, 0.6 + r() * 0.8]); return o; })();
const s10 = {
  cam: (p) => [K.lerp(1.02, 1.08, p), 640, 360],
  draw(c, t, d, p) {
    const calm = K.seg(p, 0.62, 1);
    K.sky(c, [K.mix('#4B5575', '#6E7D99', calm), K.mix('#6E7D99', '#95A5B8', calm), K.mix('#98A6B8', '#C3CCD2', calm)], 0, 480);
    for (let i = 0; i < 6; i++) K.cloud(c, K.mod(-100 + i * 260 + t * 10, W + 500) - 250, 100 + (i % 2) * 40, 1.3, K.mix('#56607F', '#8190A8', calm));
    K.rain(c, t, 17, 120, 0.3 * (1 - calm * 0.5), -80, 900, 22);
    const rise = E(K.seg(p, 0.06, 0.5));
    const A = 980 * rise, cx = K.lerp(1300, 560, E(K.seg(p, 0.06, 0.56))), sg = K.lerp(170, 720, rise);
    const lift = K.lerp(0, -560, E(K.seg(p, 0.42, 0.56)));
    const settle = E(K.seg(p, 0.6, 0.95));
    const base = K.lerp(470 + lift, 440, settle);
    const Aw = A * (1 - settle), chop = K.lerp(10, 3, calm);
    const surf = (x) => {
      const dx = x - cx, s = dx < 0 ? sg * 0.55 : sg;
      return base - Aw * Math.exp(-(dx / s) * (dx / s)) + chop * Math.sin(x * 0.018 + t * 2.4) + chop * 0.6 * Math.sin(x * 0.041 - t * 1.7);
    };
    K.water(c, surf, Math.min(base - Aw, 300), H + 100, '#4A97AE', '#1E5A74', K.rgba('#EEF8F8', 0.9), 5);
    // the lip of foam on the wave's front face
    if (Aw > 40) {
      c.strokeStyle = K.rgba('#F4FBFB', 0.75); c.lineWidth = 10; c.lineCap = 'round';
      c.beginPath();
      for (let x = cx - sg * 0.9; x <= cx + sg * 0.15; x += 6) (x === cx - sg * 0.9 ? c.moveTo(x, surf(x) + 8) : c.lineTo(x, surf(x) + 8));
      c.stroke();
    }
    // inside the water: soft bubbles while the view is covered
    const under = K.seg(p, 0.46, 0.52) * (1 - K.seg(p, 0.6, 0.7));
    if (under > 0) {
      for (const [x, ph, r, sp] of BUBBLES) {
        const y = H + 40 - K.fract(ph + t * 0.25 * sp) * (H + 80);
        c.strokeStyle = K.rgba('#DDF3F5', 0.55 * under); c.lineWidth = 2;
        c.beginPath(); c.arc(x + Math.sin(t * 2 + ph * 9) * 6, y, r, 0, TAU); c.stroke();
      }
    }
  },
};

// ---- 11. The rain stops, the water sinks, the ark rests on the mountain (Hud 11:44) ----
const SUMMIT = 300;
const restMountain = (c, col, shade, rock) => {
  c.fillStyle = col;
  c.beginPath();
  c.moveTo(60, 800);
  c.bezierCurveTo(210, 650, 300, 520, 420, 440);
  c.bezierCurveTo(470, 400, 500, 332, 548, 308);
  c.quadraticCurveTo(640, 292, 732, 306);
  c.bezierCurveTo(790, 334, 820, 384, 880, 440);
  c.bezierCurveTo(990, 540, 1090, 650, 1220, 800);
  c.closePath(); c.fill();
  c.fillStyle = shade;
  c.beginPath();
  c.moveTo(732, 306);
  c.bezierCurveTo(790, 334, 820, 384, 880, 440);
  c.bezierCurveTo(990, 540, 1090, 650, 1220, 800);
  c.lineTo(820, 800);
  c.bezierCurveTo(780, 620, 760, 470, 700, 312);
  c.closePath(); c.fill();
  c.strokeStyle = rock; c.lineWidth = 4; c.lineCap = 'round';
  for (const [x, y, w] of [[470, 430, 60], [380, 540, 80], [560, 520, 50], [300, 650, 70], [650, 640, 60]]) {
    c.beginPath(); c.moveTo(x, y); c.quadraticCurveTo(x + w / 2, y - 6, x + w, y + 2); c.stroke();
  }
};
const s11 = {
  cam: (p) => [K.lerp(1.3, 1.04, E(K.seg(p, 0.3, 1))), K.lerp(620, 640, E(p)), K.lerp(300, 380, E(K.seg(p, 0.3, 1)))],
  draw(c, t, d, p) {
    const clear = E(K.seg(p, 0.15, 0.6));
    K.sky(c, [K.mix('#4B5575', '#78B6D6', clear), K.mix('#6E7D99', '#B9DDEA', clear), K.mix('#98A6B8', '#F4E4C4', clear)], 0, 500);
    K.sun(c, 1050, 150, 34, '#FFF1C4', '#FFD68A', 0.45, K.seg(p, 0.3, 0.7));
    for (let i = 0; i < 7; i++) {
      const dir = i < 3.5 ? -1 : 1;
      K.cloud(c, -80 + i * 230 + dir * clear * 520, 90 + (i % 2) * 40, 1.4, K.mix('#56607F', '#F4F1EA', clear), 1 - clear * 0.6);
    }
    K.rain(c, t, 21, 160, 0.35 * (1 - K.seg(p, 0.02, 0.3)), -60, 900, 24);
    // far ranges and the mountain the ark comes to rest on
    K.mountain(c, 190, 700, 640, 300, K.mix('#6F7A94', '#A7A3B5', clear), K.mix('#5E6882', '#8E8AA0', clear));
    K.mountain(c, 1110, 700, 700, 330, K.mix('#6F7A94', '#A7A3B5', clear), K.mix('#5E6882', '#8E8AA0', clear));
    restMountain(c, K.mix('#7A6A63', '#B09279', clear), K.mix('#62544F', '#90735F', clear), K.mix('#5A4B45', '#8A6E5A', clear));
    // the water sinks only once the rain has eased; the ark settles near mid-scene
    const level = K.lerp(210, 650, E(K.seg(p, 0.25, 0.95)));
    const s = 0.33, float = K.clamp((SUMMIT - level) / 30);
    const bottom = Math.min(level, SUMMIT) + 18 * s * float;
    const ax = K.lerp(580, 640, E(K.seg(p, 0.0, 0.5)));
    const bob = Math.sin(t * 1.7) * 4 * float, rot = Math.sin(t * 1.3) * 0.05 * float;
    c.save(); c.translate(ax, bottom - 140 * s + bob); c.rotate(rot);
    K.ark(c, 0, 0, s, { build: 1, door: 'closed', light: K.lerp(0.72, 1, clear) });
    c.restore();
    const calm = K.lerp(6, 2, K.seg(p, 0.2, 0.8));
    K.water(c, (x) => level + calm * Math.sin(x * 0.02 + t * 1.6) + calm * 0.5 * Math.sin(x * 0.05 - t), level - 10, H + 100, K.mix('#3F7F98', '#5FA6B8', clear), K.mix('#1F4F6A', '#2F6F88', clear), K.rgba('#EAF6F6', 0.8), 3);
  },
};

// ---- 12. Closing: a calm landscape at sunrise, the lower third left clear ----
const s12 = {
  cam: (p) => [K.lerp(1.1, 1.02, E(p)), 640, K.lerp(390, 362, E(p))],
  draw(c, t, d, p) {
    const up = E(K.seg(p, 0, 0.8));
    K.sky(c, ['#8EC3DE', '#CFE0E2', '#F7D6A8', '#F3B98A'], 0, 470);
    const sy = K.lerp(470, 350, up);
    c.save(); c.globalAlpha = 0.12 * up;
    for (let i = 0; i < 9; i++) {
      const a = Math.PI + 0.25 + i * 0.33 + Math.sin(t * 0.2) * 0.02;
      c.fillStyle = '#FFF1C8'; c.beginPath(); c.moveTo(820, sy); c.arc(820, sy, 900, a, a + 0.12); c.closePath(); c.fill();
    }
    c.restore();
    K.sun(c, 820, sy, 38, '#FFF0C2', '#FFB36B', 0.55);
    for (const [x, y, s, v] of [[250, 120, 0.8, 4], [600, 90, 0.6, 3], [1100, 140, 0.7, 5]]) K.cloud(c, x + t * v, y, s, '#FFF3E4', 0.85);
    K.mountain(c, 300, 520, 760, 250, '#B6A3B8', '#9E8CA6');
    K.mountain(c, 1020, 520, 820, 230, '#B6A3B8', '#9E8CA6');
    K.ridge(c, 500, 36, 3.1, 0.9, '#A7B97F');
    K.ridge(c, 535, 24, 6.9, 1.2, '#98B070');
    // a calm river winding through the valley, holding the sky's colour
    c.fillStyle = '#E9CFA6';
    c.beginPath(); c.moveTo(-420, 575); c.bezierCurveTo(300, 545, 500, 600, 800, 565); c.bezierCurveTo(1000, 545, 1200, 560, W + 420, 552);
    c.lineTo(W + 420, 572); c.bezierCurveTo(1200, 580, 1000, 565, 800, 588); c.bezierCurveTo(500, 622, 300, 568, -420, 598); c.closePath(); c.fill();
    c.strokeStyle = K.rgba('#FFF7E6', 0.6); c.lineWidth = 2;
    for (let i = 0; i < 5; i++) { const x = 150 + i * 240 + Math.sin(t + i) * 8; c.beginPath(); c.moveTo(x, 575 + (i % 2) * 6); c.lineTo(x + 40, 575 + (i % 2) * 6); c.stroke(); }
    // the lower third is left open meadow for the lesson line added later
    const g = c.createLinearGradient(0, 600, 0, H);
    g.addColorStop(0, '#B9C98A'); g.addColorStop(1, '#A9BC7C');
    c.fillStyle = g; c.fillRect(-420, 600, W + 840, 600);
    for (const [x, s] of [[120, 1.0], [260, 0.8], [1010, 0.9], [1180, 1.1]]) K.shrub(c, x, 604, s, '#86A060');
  },
};

window.STORY_SCENES = [s1, s2, s3, s4, s5, s6, s7, s8, s9, s10, s11, s12];
})();
