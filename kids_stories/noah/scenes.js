// Story 1 - Nuh (Noah), peace be upon him. VISUALS ONLY - v2.
// Scene list and the verse each rests on: docs/kids_stories_brief.md.
// Rules kept here (brief rule 1 as updated 2026-09-30): ordinary people may
// appear, flat and featureless (no eyes, no mouth); Nuh is NEVER drawn - his
// presence is only a soft warm light (K.presence); no angels; no text; nothing
// beyond the scene list (no rainbow, no dove, no oven, no labels).
//
// v2 (owner on v1: «باين خالص انه تصميم آلي … المشهد بيطول ساكن»):
// - every scene is built from 4-7 parallax layers (K.par) under a camera that
//   always moves; ambient life everywhere (birds, dust, grass, rain, spray);
// - story events are keyed to the spoken word that names them, from
//   words.json (K.beat(scene, word, fallbackSeconds)) - the fallback is the
//   measured time, used only if the recogniser spelt the word differently.
// Each scene: draw(ctx, t, d, p) with t = local seconds, d = duration, p = t/d.
'use strict';
(() => {
const { W, H } = K;
const TAU = Math.PI * 2;
const E = K.easeInOut;
const B = K.beat, A = K.after;

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
const valleySide = (c, y0, rise, seed, col) => {
  c.fillStyle = col;
  c.beginPath(); c.moveTo(-420, H + 420);
  for (let x = -420; x <= W + 420; x += 8) {
    const d = Math.abs(x - W / 2) / (W / 2);
    c.lineTo(x, y0 - rise * Math.pow(d, 1.8) - K.ridgeY(x, seed, 14, 1.4));
  }
  c.lineTo(W + 420, H + 420); c.closePath(); c.fill();
};
const ground = (c, y, light, col = '#D9A86C') => {
  const g = c.createLinearGradient(0, y, 0, H + 60);
  g.addColorStop(0, K.tone(col, light)); g.addColorStop(1, K.tone(K.mix(col, '#8A5A3C', 0.35), light));
  c.fillStyle = g; c.fillRect(-420, y, W + 840, H - y + 420);
};
const palm = (c, x, gy, h, light, t, ph = 0, wind = 1) =>
  K.palm(c, x, gy, h, K.tone('#6B4A34', light), K.tone('#5E7A45', light), wind * (Math.sin(t * 0.9 + ph) + 0.35 * Math.sin(t * 2.3 + ph * 2)));
// The valley town under a light level, as layers. glow = window light.
const valleyTown = (c, t, light, glow, opt = {}) => {
  K.par(c, 0.3, () => {
    K.ridge(c, 405, 60, 1.3, 0.7, K.tone('#C49A8C', light));
    K.haze(c, 300, 470, K.mix('#E9A58A', '#8A90C0', 1 - light), 0.22);
  });
  K.par(c, 0.5, () => { K.ridge(c, 440, 40, 4.2, 1.1, K.tone('#B98368', light)); valleySide(c, 470, 190, 2.2, K.tone('#B77A55', light)); });
  K.par(c, 0.72, () => { valleySide(c, 505, 120, 7.7, K.tone('#C98E5E', light)); ground(c, opt.gy || 540, light); });
  K.par(c, 0.88, () => {
    K.town(c, opt.seed || 12, opt.n || 22, opt.x0 ?? 170, opt.x1 ?? 1110, opt.ty || 548, opt.scale || 1.15, light, glow);
    palm(c, 120, 640, 190, light, t, 0); palm(c, 1170, 650, 210, light, t, 2);
  });
};
const foreGrass = (c, t, light, y = 742, wind = 1) => K.par(c, 1.32, () => {
  const col = K.tone('#5E6B3A', light * 0.7);
  K.grass(c, 91, -380, 260, y, 46, col, t, wind);
  K.grass(c, 92, 1040, 1680, y, 52, col, t + 0.7, wind);
});
// One day/night cycle: u in [0,1): 0 sunrise, .25 noon, .5 sunset, .75 midnight.
const cycle = (u) => ({ light: K.smooth(0.5 + 0.9 * Math.sin(u * TAU)), u });
const arcPos = (v, h, horizon) => [K.lerp(-80, W + 80, v), horizon - Math.sin(Math.PI * v) * h];

// ---- 1. Stone idols in an old valley town at dusk (Nuh 71:23) ----
// «تماثيل» -> the idols come into focus; «يعبدونها» -> the camera settles on them.
const IDOLS = [['boulder', 400, 118], ['slab', 515, 150], ['obelisk', 640, 178], ['stepped', 765, 142], ['column', 880, 124]];
const s1 = {
  cam: (p, t, d) => {
    const tm = B(1, 'تماثيل', 6.72), ya = B(1, 'يعبدونها', 9.12);
    const a = E(K.clamp(t / (tm + 0.8))), b = A(t, ya - 0.3, 1.3);
    return [K.lerp(1.0, 1.12, a) + 0.1 * b, K.lerp(520, 640, a), K.lerp(320, 440, a) + 30 * b, 0];
  },
  draw(c, t, d, p) {
    const tm = B(1, 'تماثيل', 6.72), ya = B(1, 'يعبدونها', 9.12);
    const light = K.lerp(0.52, 0.36, p), focus = A(t, tm - 0.25, 0.9, K.easeOut);
    K.par(c, 0, () => {
      K.sky(c, skyAt(light), 0, 470);
      K.stars(c, 23, 90, K.seg(p, 0.45, 1) * 0.75, t, 330);
      const sy = K.lerp(430, 505, E(p));
      K.rays(c, 250, sy, 9, 760, -Math.PI + 0.25, -0.35, '#FFC98A', 0.07 * (1 - p * 0.6), t);
      K.sun(c, 250, sy, 30, '#FFE1A0', '#FF9E5E', 0.5);
      for (const [x, y, s, v] of [[420, 150, 0.9, 6], [880, 110, 1.1, 4], [1220, 180, 0.8, 7]]) K.cloud(c, K.mod(x + t * v + 200, W + 500) - 250, y, s, K.mix('#C77A86', '#5E4A73', p), 0.55);
    });
    K.par(c, 0.15, () => K.birds(c, t, 31, 7, 240, 250, 170, 30, 9, '#3B2A3A', 0.65));
    valleyTown(c, t, light, K.seg(p, 0.3, 0.9), { seed: 71, n: 16, x0: 250, x1: 1030, ty: 505, scale: 0.85, gy: 520 });
    K.par(c, 1, () => {
      c.fillStyle = K.tone('#B08E70', light); c.beginPath(); c.roundRect(300, 598, 690, 22, 6); c.fill();
      c.fillStyle = K.tone('#8C6E56', light); c.fillRect(306, 616, 678, 18);
      // behind the stones: the last dusk light gathers as they come into focus
      K.glow(c, 640, 520, 330, '#FFB27A', 0.18 * focus);
      c.save();
      c.globalAlpha = 0.4 + 0.6 * focus;
      for (const [kind, x, h] of IDOLS) {
        c.fillStyle = K.rgba('#3A2433', 0.28 * focus);
        c.beginPath(); c.moveTo(x - h * 0.2, 604); c.lineTo(x + h * 0.2, 604); c.lineTo(x + h * 1.2, 612); c.lineTo(x + h * 0.9, 614); c.closePath(); c.fill();
      }
      IDOLS.forEach(([kind, x, h], i) => {
        const k = K.easeOutBack(K.clamp((t - tm + 0.25 - i * 0.09) / 0.7));
        const hh = h * (0.9 + 0.1 * k);
        K.stone(c, kind, x, 606, hh, K.tone('#9C8A78', light), K.tone(K.mix('#C7AE8E', '#FFD2A0', 0.4 * focus), light * 1.1), K.tone('#6E5E54', light));
      });
      c.restore();
      // haze over the stones before they are named, gone as they are named
      K.glow(c, 640, 540, 420, K.mix('#C98A86', '#4A3B60', p), 0.45 * (1 - focus));
      ground(c, 634, light, '#C99A62');
    });
    K.par(c, 1.08, () => K.dust(c, t, 11, 40, '#FFD9A8', 0.45, -100, W + 100, 380, 700, 5));
    K.par(c, 1.3, () => {
      palm(c, 30, 790, 360, light * 0.75, t, 4);
      palm(c, 1290, 800, 330, light * 0.75, t, 1.5);
    });
    foreGrass(c, t, light);
  },
};

// ---- 2. Day and night over the town; the call by night and by day (Nuh 71:5) ----
// «نوحًا» -> a warm light appears at the town's edge; «يدعوهم» -> it goes from
// door to door; «الليل» / «النهار» -> the sky turns.
const STOPS2 = [250, 420, 590, 760, 930, 1060];
const s2 = {
  cam: (p, t, d) => {
    const nu = B(2, 'نوح', 3.76), da = B(2, 'يدعوهم', 6.0), la = B(2, 'الليل', 10.16);
    const f = A(t, da, la - da, (x) => x);
    return [K.lerp(1.04, 1.16, A(t, nu - 0.4, 1.6)) - 0.08 * A(t, la - 0.3, 1.4), K.lerp(470, 820, f), K.lerp(360, 420, A(t, nu - 0.4, 1.6)) - 30 * A(t, la - 0.3, 1.4), 0];
  },
  draw(c, t, d, p) {
    const nu = B(2, 'نوح', 3.76), da = B(2, 'يدعوهم', 6.0), la = B(2, 'الليل', 10.16), na = B(2, 'النهار', 11.2);
    // light: morning -> late afternoon while he calls -> night on «الليل» -> day on «النهار»
    let light = K.lerp(0.95, 0.62, A(t, da, la - da));
    light = K.lerp(light, 0.04, A(t, la - 0.15, 0.55));
    light = K.lerp(light, 0.92, A(t, na - 0.15, 0.6));
    const night = K.clamp(1 - light * 2);
    K.par(c, 0, () => {
      K.sky(c, skyAt(light), 0, 500);
      K.stars(c, 5, 110, night * 0.9, t, 360);
      const sunA = K.clamp((light - 0.3) / 0.4), su = K.lerp(0.62, 0.78, A(t, 0, la));
      if (sunA > 0) { const [x, y] = arcPos(su, 340, 540); K.sun(c, x, y, 34, '#FFE8A8', '#FFC46B', 0.55, sunA); }
      if (night > 0.02) K.moon(c, 980, 150, 30, '#FFF4D6', night);
      for (const [x, y, s, v] of [[200, 120, 0.9, 7], [640, 80, 0.7, 5], [1100, 140, 1.0, 6]]) K.cloud(c, K.mod(x + t * v + 200, W + 500) - 250, y, s, K.tone('#FFF6E6', light), 0.85);
    });
    K.par(c, 0.15, () => K.birds(c, t, 17, 5, 300, 200, 150, 34, 8, '#4A3A40', 0.6 * K.clamp(light * 2 - 1)));
    valleyTown(c, t, light, K.clamp(night * 1.2 + 0.25 * A(t, da, 1.5)));
    // Nuh's presence: a warm light only, going from door to door as he calls
    K.par(c, 0.88, () => {
      const appear = A(t, nu - 0.2, 0.9);
      const q = K.clamp((t - da) / Math.max(0.5, la - 0.3 - da)) * (STOPS2.length - 1);
      const k = Math.floor(q), fr = q - k, mv = K.easeInOut(K.clamp((fr - 0.55) / 0.45));
      const x = k >= STOPS2.length - 1 ? STOPS2[STOPS2.length - 1] : K.lerp(STOPS2[k], STOPS2[k + 1], mv);
      K.presence(c, t < da ? STOPS2[0] : x, 574, 24, t, appear * (0.85 + 0.15 * night));
    });
    K.par(c, 1.06, () => K.dust(c, t, 21, 26, light > 0.4 ? '#FFE8C0' : '#C8D2FF', 0.35, -100, W + 100, 420, 700, 4));
    K.par(c, 1.3, () => { palm(c, -10, 800, 380, light * 0.75, t, 3); });
    foreGrass(c, t, light);
  },
};

// ---- 3. Sun and moon racing: very many years (al-Ankabut 29:14) ----
// The days speed up to «سنة», then slow and settle on a clear day on «صابرًا»;
// the light at the town's edge stays steady through it all («لا يتعب»).
// Capped at 1.2 cycles/s with the sky's contrast softened as it speeds up,
// well under the 3-flashes-per-second photosensitivity guideline.
const MEAN_SKY = ['#2A2E5E', '#58577F', '#A28C8A'];
const s3 = {
  cam: (p) => [K.lerp(1.16, 1.0, E(K.seg(p, 0, 0.7))) + 0.06 * E(K.seg(p, 0.7, 1)), K.lerp(560, 660, E(p)), K.lerp(410, 360, E(p)), 0],
  draw(c, t, d, p) {
    const tS = B(3, 'سنة', 4.8), sb = B(3, 'صابر', 5.36), ya = B(3, 'يتعب', 6.72);
    const v0 = 0.3, v1 = 1.2, stop = sb + 0.9;
    const spd = (x) => (x < tS ? v0 + (v1 - v0) * x / tS : v1 * K.smooth(1 - (x - tS) / (stop - tS)));
    const integ = (x) => { let s = 0; const n = 160, h = Math.max(0, x) / n; for (let i = 0; i < n; i++) s += spd((i + 0.5) * h) * h; return s; };
    const phi = 0.25 - K.fract(integ(d)) + integ(K.clamp(t, 0, d)) + (t < 0 ? v0 * t : 0);
    const speed = t > d ? 0 : spd(K.clamp(t, 0, d));
    const blur = K.smooth((speed - 0.45) / 0.75) * 0.6;
    const { light: l0, u } = cycle(K.fract(phi));
    const light = K.lerp(l0, 0.45, blur);
    K.par(c, 0, () => {
      K.sky(c, skyAt(l0).map((col, i) => K.mix(col, MEAN_SKY[i], blur)), 0, 500);
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
      // clouds stream past faster as the years run
      for (let i = 0; i < 5; i++) K.cloud(c, K.mod(i * 300 + phi * 520, W + 500) - 250, 100 + (i % 3) * 40, 0.9, K.tone('#FFF2E0', light), 0.6);
    });
    valleyTown(c, t, light, K.clamp(1 - light * 1.8) * 0.8);
    K.par(c, 0.88, () => K.presence(c, 250, 574, 24 + 6 * A(t, ya - 0.2, 0.5) * (1 - A(t, ya + 0.6, 0.8)), t, 0.95));
    foreGrass(c, t, light, 742, 1 + blur);
  },
};

// ---- 4. The ark takes shape from planks and pegs (Hud 11:37, al-Qamar 54:13) ----
// «سفينة» -> its outline draws on in light; «ألواح» -> planks fly in from the
// pile and stack; «ومسامير» -> pegs tap in with puffs of dust; «برعاية الله
// وحفظه» -> soft rays over it.
const ARK4 = { x: 640, y: 452, s: 0.8 };
const openLand = (c, t, light) => {
  K.par(c, 0, () => {
    K.sky(c, ['#78B6D6', '#B9DDEA', '#F6E7C6'], 0, 520);
    K.sun(c, 1040, 130, 36, '#FFF1C4', '#FFD68A', 0.45);
    for (const [x, y, s, v] of [[180, 120, 0.9, 7], [520, 80, 0.7, 5], [860, 150, 1.0, 6], [1250, 90, 0.8, 4]]) K.cloud(c, K.mod(x + t * v + 200, W + 500) - 250, y, s, '#FFF8EC', 0.92);
  });
  K.par(c, 0.12, () => K.birds(c, t, 44, 6, 200, 210, 200, 26, 8, '#5A5060', 0.55));
  K.par(c, 0.35, () => { K.ridge(c, 470, 50, 3.3, 0.8, K.tone('#B7A58E', light)); K.haze(c, 380, 520, '#F2E2C8', 0.3); });
  K.par(c, 0.6, () => K.ridge(c, 515, 34, 8.1, 1.2, K.tone('#C9A77A', light)));
  K.par(c, 1, () => ground(c, 540, light, '#DDB679'));
};
const plankPile = (c, x, y, n, light) => {
  for (let i = 0; i < n; i++) {
    const r = Math.floor(i / 2), off = (i % 2) * 58 + (r % 2) * 12;
    c.fillStyle = K.tone('#5E3A22', light); c.fillRect(x + off, y - (r + 1) * 11, 110, 11);
    c.fillStyle = K.tone(i % 3 ? '#A86C40' : '#B27849', light); c.fillRect(x + off + 1.5, y - (r + 1) * 11 + 1.5, 107, 8);
  }
};
const s4 = {
  cam: (p, t, d) => {
    const al = B(4, 'ألواح', 4.08);
    return [K.lerp(1.0, 1.16, E(p)), K.lerp(740, 650, E(p)) + 26 * Math.sin(t * 0.45), K.lerp(370, 420, E(p)) - 12 * A(t, al, 0.8) * (1 - A(t, al + 1.6, 1)), 0];
  },
  draw(c, t, d, p) {
    const sf = B(4, 'سفينة', 2.88), al = B(4, 'ألواح', 4.08), ms = B(4, 'مسامير', 5.12), ri = B(4, 'برعاية', 6.24);
    openLand(c, t, 1);
    K.par(c, 1, () => {
      for (const [x, s] of [[120, 1.3], [260, 0.9], [1180, 1.1], [980, 0.7]]) K.shrub(c, x, 600, s, '#8E9A55');
      const n0 = 4 / K.arkPlankCount;
      const build = n0 * A(t, 0.5, Math.max(0.6, sf - 0.7), (x) => x) + (1 - n0) * A(t, al - 0.1, ri + 0.5 - al, (x) => x);
      c.fillStyle = K.rgba('#6B4A2E', 0.18); c.beginPath(); c.ellipse(640, 612, 300, 14, 0, 0, TAU); c.fill();
      // the outline in light, drawn on as the ark is named
      const ol = A(t, sf - 0.15, 0.9, (x) => x), olA = A(t, sf - 0.15, 0.3) * (1 - A(t, ri, 1.0));
      if (olA > 0.01) {
        c.save(); c.translate(ARK4.x, ARK4.y); c.scale(ARK4.s, ARK4.s);
        c.setLineDash([2600, 2600]); c.lineDashOffset = 2600 * (1 - ol);
        c.strokeStyle = K.rgba('#FFE6A8', 0.85 * olA); c.lineWidth = 4; c.shadowColor = '#FFD27A'; c.shadowBlur = 18;
        c.beginPath(); K.arkOutline(c); c.stroke();
        c.restore();
      }
      K.ark(c, ARK4.x, ARK4.y, ARK4.s, { build, blocks: true, door: 'none', from: [525, 220], pegs: K.clamp((t - ms) / 1.7) });
      plankPile(c, 1000, 640, Math.round((1 - build) * 14) + 2, 1);
      K.presence(c, 300, 588, 28, t, A(t, 0.2, 1.0));
    });
    K.par(c, 1, () => K.rays(c, 1120, -140, 8, 1100, 2.05, 2.55, '#FFF0C8', 0.14 * A(t, ri - 0.1, 1.2), t));
    K.par(c, 1.08, () => K.dust(c, t, 41, 34, '#FFF1D2', 0.4, -100, W + 100, 300, 700, 6));
    foreGrass(c, t, 1, 748);
  },
};

// ---- 5. Some of his people pass and mock; he works on, patient (Hud 11:38) ----
// «جماعة» -> a few townspeople walk up; «سخروا» -> they stop and point,
// shoulders shaking (body language only, no faces); «يعمل صابرًا» -> the camera
// goes to the ark, still being built, the warm light beside it.
const PEOPLE5 = [
  { off: 0, robe: '#7A5A48', cloth: '#E9DCC4', s: 1.36 },
  { off: -52, robe: '#5E6A7A', cloth: '#D8CBB0', s: 1.28 },
  { off: -102, robe: '#8A6E3E', cloth: '#EFE4CC', s: 1.4 },
  { off: -150, robe: '#6E4E5A', cloth: '#DCCFB8', s: 1.22 },
];
const s5 = {
  cam: (p, t, d) => {
    const sk = B(5, 'سخروا', 4.32), ya = B(5, 'يعمل', 6.0);
    return [K.lerp(1.1, 1.2, E(p)), K.lerp(470, 600, A(t, 0.3, sk)) + 280 * A(t, ya - 0.5, 1.4), 405, 0];
  },
  draw(c, t, d, p) {
    const jm = B(5, 'جماعة', 2.24), sk = B(5, 'سخروا', 4.32);
    const light = 0.8;
    K.par(c, 0, () => {
      K.sky(c, ['#6E9CC6', '#DDBE98', '#F6D29A'], 0, 520);
      K.sun(c, 150, 300, 32, '#FFE7B0', '#FFB870', 0.45);
      for (const [x, y, s, v] of [[300, 120, 0.8, 5], [760, 90, 0.9, 4], [1180, 140, 0.7, 6]]) K.cloud(c, K.mod(x + t * v + 200, W + 500) - 250, y, s, '#FFF1DE', 0.8);
    });
    K.par(c, 0.12, () => K.birds(c, t, 52, 5, 700, 190, 160, 22, 8, '#5A4A50', 0.5));
    K.par(c, 0.35, () => { K.ridge(c, 440, 55, 1.9, 0.7, K.tone('#C49A8C', light)); K.haze(c, 360, 500, '#F2D6B0', 0.3); });
    K.par(c, 0.6, () => K.ridge(c, 490, 35, 5.4, 1.1, K.tone('#C0906A', light)));
    K.par(c, 1, () => {
      ground(c, 540, light);
      K.town(c, 33, 16, -140, 470, 556, 1.0, light, 0);
      palm(c, 505, 600, 150, light, t, 1);
      // the ark keeps growing, plank by plank, all through the mocking
      const build = K.lerp(0.74, 0.93, p);
      c.fillStyle = K.rgba('#6B4A2E', 0.18); c.beginPath(); c.ellipse(930, 612, 240, 11, 0, 0, TAU); c.fill();
      K.ark(c, 930, 612 - 200 * 0.64, 0.64, { build, blocks: true, light, door: 'none' });
      plankPile(c, 1150, 640, 6, light);
      K.presence(c, 1205, 590, 26, t, 1);
      for (const [x, s] of [[640, 1.2], [700, 0.8], [1260, 1.0]]) K.shrub(c, x, 650, s, K.tone('#8E9A55', light));
      // the passers-by: walk up, stop, point and laugh, then walk away
      const arrive = jm + 0.7, leave = sk + 1.9;
      const lead = t < leave ? K.lerp(-180, 650, K.easeOut(K.clamp((t - 0.1) / (arrive - 0.1)))) : 650 - 300 * K.easeIn(K.clamp((t - leave) / 1.4));
      const moving = t < arrive || t > leave;
      const point = A(t, sk - 0.15, 0.35) * (1 - A(t, leave - 0.25, 0.3));
      const back = PEOPLE5.slice().sort((a, b) => a.s - b.s);
      for (const pp of back) {
        const x = lead + pp.off * (t > leave ? -1 : 1);
        K.person(c, x, 660 + (pp.s - 1.3) * 30, pp.s, { phase: x / 11, walk: moving ? 1 : 0, point, shake: point, robe: pp.robe, cloth: pp.cloth, dir: t > leave ? -1 : 1 });
      }
    });
    K.par(c, 1.08, () => K.dust(c, t, 51, 30, '#FFE9C8', 0.4, -100, W + 100, 320, 700, 5));
    foreGrass(c, t, light, 748);
  },
};

// ---- 6. God's command comes; water wells up from the ground (Hud 11:40) ----
// «جاء أمر الله» -> the sky darkens, wind rises; «وبدأ الماء» -> the cracks
// fill; «يفور» -> it wells up and spreads. No oven is drawn (the exegetes
// differ on al-tannur) - only water rising from the earth.
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
  cam: (p, t, d) => {
    const yf = B(6, 'يفور', 4.96);
    const sh = A(t, yf - 0.05, 0.1) * (1 - A(t, yf + 0.5, 0.6));
    return [K.lerp(1.0, 1.12, E(p)) + 0.06 * A(t, yf - 0.1, 0.8), 640 + 4 * Math.sin(t * 43) * sh, K.lerp(410, 455, E(p)) + 3 * Math.sin(t * 37) * sh, 0];
  },
  draw(c, t, d, p) {
    const ja = B(6, 'جاء', 1.12), bd = B(6, 'وبدأ', 3.36), yf = B(6, 'يفور', 4.96);
    const dark = A(t, ja - 0.2, 1.3), cx = 640, cy = 505;
    K.par(c, 0, () => {
      K.sky(c, [K.mix('#8BA9C8', '#3E4560', dark), K.mix('#CDBFA8', '#6B6878', dark), K.mix('#E8D2AE', '#9A8C86', dark)], 0, 400);
      for (let i = 0; i < 8; i++) {
        const side = i < 4 ? -1 : 1, x0 = i < 4 ? 80 + i * 150 : 640 + (i - 4) * 150 + 80;
        K.cloud(c, x0 + side * (1 - dark) * 620 + Math.sin(t * 0.4 + i) * 10, 80 + (i % 2) * 40, 1.4, i % 2 ? '#4E5470' : '#5C6280', 0.9 * dark);
      }
    });
    K.par(c, 0.35, () => { K.ridge(c, 360, 40, 2.6, 0.8, K.tone(K.mix('#A99589', '#5A5868', dark), 0.85)); K.haze(c, 300, 420, K.mix('#E8D2AE', '#7A7486', dark), 0.3); });
    K.par(c, 0.6, () => K.ridge(c, 395, 26, 6.3, 1.2, K.mix('#B99270', '#6E6266', dark)));
    K.par(c, 1, () => {
      const g = c.createLinearGradient(0, 390, 0, H);
      g.addColorStop(0, K.mix('#C9A06C', '#8E7A62', dark)); g.addColorStop(1, K.mix('#A87A4E', '#6E5A44', dark));
      c.fillStyle = g; c.fillRect(-420, 390, W + 840, 800);
      for (const [x, y, r] of STONES) {
        c.fillStyle = K.mix('#8E7560', '#5E5048', dark); c.beginPath(); c.ellipse(cx + x, cy + y, r, r * 0.55, 0, 0, TAU); c.fill();
        c.fillStyle = K.mix('#A88D74', '#7A6A5E', dark); c.beginPath(); c.ellipse(cx + x - r * 0.2, cy + y - r * 0.15, r * 0.6, r * 0.3, 0, 0, TAU); c.fill();
      }
      const wet = A(t, bd - 0.3, 0.8, (x) => x);
      c.lineCap = 'round'; c.lineJoin = 'round';
      for (const pts of CRACKS) {
        c.strokeStyle = K.mix('#6E4C32', '#4FB6C0', wet); c.lineWidth = 3 + wet * 2.5;
        c.shadowColor = '#7FE0E8'; c.shadowBlur = 10 * wet;
        c.beginPath(); pts.forEach(([x, y], i) => (i ? c.lineTo(cx + x, cy + y) : c.moveTo(cx + x, cy + y))); c.stroke();
      }
      c.shadowBlur = 0;
      const k = K.clamp((t - yf + 0.4) / (d - yf + 0.8));
      const rx = 16 + 1150 * (k * k * 0.6 + k * 0.4);
      if (k > 0) {
        const pg = c.createRadialGradient(cx, cy, 0, cx, cy, rx);
        pg.addColorStop(0, '#6CC0C2'); pg.addColorStop(0.6, '#4AA0AA'); pg.addColorStop(1, '#3B8A9A');
        c.save(); c.translate(cx, cy); c.scale(1, 0.3);
        c.fillStyle = pg; c.globalAlpha = 0.93; c.beginPath(); c.arc(0, 0, rx, 0, TAU); c.fill();
        c.globalAlpha = 1; c.strokeStyle = K.rgba('#E9FAF7', 0.7); c.lineWidth = 5; c.beginPath(); c.arc(0, 0, rx, 0, TAU); c.stroke();
        for (let i = 0; i < 4; i++) {
          const q = K.fract(t / 1.2 + i / 4), rr = q * rx;
          c.strokeStyle = K.rgba('#E9FAF7', 0.5 * (1 - q)); c.lineWidth = 4;
          c.beginPath(); c.arc(0, 0, rr, 0, TAU); c.stroke();
        }
        c.restore();
      }
      // the welling: starts on «وبدأ», bursts up on «يفور»
      const w = A(t, bd, 0.8), burst = A(t, yf - 0.1, 0.5, K.easeOutBack);
      if (w > 0) {
        const hb = w * (14 + 5 * Math.sin(t * 5.2)) + burst * (38 + 10 * Math.sin(t * 7.1) + 5 * Math.sin(t * 11.3));
        c.fillStyle = '#8AD3D0';
        c.beginPath(); c.ellipse(cx, cy, 40 * w + 30 * burst + 10, hb + 4, 0, Math.PI, TAU); c.fill();
        c.fillStyle = K.rgba('#FFFFFF', 0.5); c.beginPath(); c.ellipse(cx - 8, cy - hb * 0.6, 12 * w + 8 * burst, hb * 0.22 + 1, 0, 0, TAU); c.fill();
        K.spray(c, t, 611, 16 + Math.round(24 * burst), cx - 40, cx + 40, cy - hb * 0.8, 50 + 110 * burst, '#D9F4F2', 0.85 * w);
      }
    });
    // wind: dust streaks and bending grass once the command comes
    K.par(c, 1.1, () => K.rain(c, t, 61, 70, 0.22 * dark, 900, 40, 1.6, '#E6CFA6', 2));
    foreGrass(c, t, 0.9 - 0.3 * dark, 748, 1 + 2.2 * dark);
  },
};

// ---- 7. Animals in pairs walk up into the ark (Hud 11:40) ----
// «السفينة» -> the ramp comes down, warm light at the door; «زوجين اثنين» ->
// the first pair walks in exactly on the words; more pairs keep coming.
const GY7 = 600, ARK7 = { x: 860, s: 0.8 };
const ark7y = GY7 - 200 * ARK7.s;
const RAMP0 = ARK7.x - 500 * ARK7.s, DOORX = ARK7.x + K.ARK.doorX0 * ARK7.s, DOORY = ark7y + 122 * ARK7.s;
const pathY = (x) => (x < RAMP0 ? GY7 : x < DOORX ? GY7 - (x - RAMP0) * (GY7 - DOORY) / (DOORX - RAMP0) : DOORY);
const RAMP_ANG = -Math.atan((GY7 - DOORY) / (DOORX - RAMP0));
const QUEUE = ['elephant', 'camel', 'lion', 'horse', 'sheep', 'camel', 'horse', 'sheep'];
const SA = 0.7, V7 = 112;
const s7 = {
  cam: (p, t, d) => {
    const zw = B(7, 'زوجين', 4.72);
    const inn = A(t, zw - 1.6, 1.6), back = A(t, zw + 1.4, d - zw - 1.4);
    return [K.lerp(1.02, 1.26, inn) - 0.12 * back, K.lerp(K.lerp(800, 700, E(K.clamp(t / zw))), DOORX - 30, inn) - 170 * back, K.lerp(420, DOORY - 40, inn) + 20 * back, 0];
  },
  draw(c, t, d, p) {
    const sf = B(7, 'السفينة', 2.64), zw = B(7, 'زوجين', 4.72), ah = B(7, 'وأهله', 6.24);
    const light = K.lerp(0.78, 0.62, p), rain = 0.35 * A(t, ah, 3);
    K.par(c, 0, () => {
      K.sky(c, [K.mix('#7E8AA6', '#5E6680', p), '#A99D9A', '#D8BE98'], 0, 520);
      for (const [x, y, s, v] of [[160, 110, 1.3, 6], [520, 70, 1.5, 5], [900, 120, 1.4, 7], [1250, 80, 1.2, 4]]) K.cloud(c, K.mod(x + t * v + 200, W + 500) - 250, y, s, K.mix('#9A94A0', '#6E6A7A', p), 0.9);
    });
    K.par(c, 0.35, () => { K.ridge(c, 470, 50, 3.3, 0.8, K.tone('#A7968C', light)); K.haze(c, 380, 520, '#CFC2B6', 0.3); });
    K.par(c, 0.6, () => K.ridge(c, 520, 30, 8.1, 1.2, K.tone('#B99270', light)));
    K.par(c, 1, () => {
      ground(c, 560, light, '#C39A66');
      for (const [x, y, rx] of [[220, 640, 70], [420, 680, 50], [1120, 650, 80], [980, 700, 60]]) {
        c.fillStyle = K.rgba('#6FA6AE', 0.75); c.beginPath(); c.ellipse(x, y, rx, rx * 0.16, 0, 0, TAU); c.fill();
        for (let i = 0; i < 2; i++) {
          const q = K.fract(t * 0.9 + i * 0.5 + x * 0.01);
          c.strokeStyle = K.rgba('#E6F4F5', 0.5 * (1 - q) * (0.3 + rain * 2)); c.lineWidth = 1.5;
          c.beginPath(); c.ellipse(x + (i - 0.5) * rx * 0.5, y, rx * 0.3 * q, rx * 0.05 * q, 0, 0, TAU); c.stroke();
        }
      }
      const rd = A(t, sf - 0.2, 0.9, K.easeOut);
      K.ark(c, ARK7.x, ark7y, ARK7.s, { build: 1, blocks: true, door: 'open', ramp: true, rampDown: rd, light });
      K.glow(c, (DOORX + ARK7.x + K.ARK.doorX1 * ARK7.s) / 2, ark7y + 70 * ARK7.s, 90, '#FFC878', 0.45 * rd);
      // the queue: the first animal crosses the door on «زوجين», its partner
      // on «اثنين»; a clear gap between one pair and the next
      const lead = DOORX + 2 + V7 * (t - zw);
      c.save();
      c.beginPath(); c.rect(-1000, -1000, DOORX + 1000, 3000); c.clip();
      let off = 0;
      const draws = [];
      for (const type of QUEUE) {
        const L = K.ANIMALS[type].len * SA;
        draws.push([type, lead - off, 0], [type, lead - off - L - 6, 0.18]);
        off += 2 * L + 6 + 64;
      }
      for (const [type, ax, sh] of draws.reverse()) {
        if (ax > DOORX + 160 || ax < -300) continue;
        const onRamp = ax > RAMP0 && ax < DOORX;
        K.animal(c, type, ax, pathY(ax), SA, ax / 20, onRamp ? RAMP_ANG : 0, sh);
      }
      c.restore();
    });
    K.par(c, 1.1, () => K.rain(c, t, 77, 160, rain, -60, 900, 22));
    foreGrass(c, t, light, 748, 1.4);
  },
};

// ---- 8. The sky's gates pour, springs burst, the waters meet (al-Qamar 54:11-12) ----
// «أبواب السماء» -> the clouds split with light; «بماء» -> torrents fall;
// «وتفجرت الأرض» -> the ground cracks; «عيونًا» -> springs burst up;
// «فالتقى الماء» -> the rising water meets the torrents. No architecture in the sky.
const GATES = [200, 500, 800, 1090];
const SPRINGS = [[350, 0.0], [650, 0.25], [950, 0.12], [90, 0.4], [1200, 0.33]];
const s8 = {
  cam: (p, t, d) => {
    const tf = B(8, 'وتفجرت', 5.52), lt = B(8, 'فالتقى', 8.56);
    return [K.lerp(1.12, 1.06, A(t, tf - 0.5, 1.2)) - 0.06 * A(t, lt - 0.3, 1.2), 640 + 30 * Math.sin(t * 0.3), K.lerp(290, 450, A(t, tf - 0.6, 1.3)) - 70 * A(t, lt - 0.3, 1.3), 0];
  },
  draw(c, t, d, p) {
    const ab = B(8, 'أبواب', 1.84), ma = B(8, 'بماء', 3.68), tf = B(8, 'وتفجرت', 5.52), uy = B(8, 'عيون', 7.6), lt = B(8, 'فالتقى', 8.56);
    const open = A(t, ab - 0.1, 1.0, K.easeOut), pour = A(t, ma - 0.2, 0.9, K.easeIn);
    const level = K.lerp(720, 600, A(t, tf, uy - tf, (x) => x)) - 140 * A(t, lt - 0.4, 1.2);
    K.par(c, 0, () => {
      K.sky(c, ['#2F3856', '#4D5A7C', '#7D8CA6'], 0, 520);
      K.rays(c, 640, 120, 10, 900, 0.5, Math.PI - 0.5, '#CFE2F0', 0.08 * open, t);
    });
    K.par(c, 0.4, () => { K.ridge(c, 470, 45, 2.9, 0.8, '#4E566F'); K.haze(c, 380, 520, '#8A98B4', 0.3); });
    K.par(c, 0.65, () => K.ridge(c, 520, 30, 6.1, 1.2, '#5F6377'));
    K.par(c, 1, () => {
      c.fillStyle = '#6A6470'; c.fillRect(-420, 540, W + 840, 600);
      // cracks in the ground on «وتفجرت الأرض»
      const cr = A(t, tf - 0.1, 0.7, (x) => x);
      if (cr > 0) {
        c.strokeStyle = K.rgba('#9FE3EE', 0.8); c.lineWidth = 3; c.shadowColor = '#9FE3EE'; c.shadowBlur = 8;
        for (const [x] of SPRINGS) { c.beginPath(); c.moveTo(x - 60 * cr, 650); c.lineTo(x - 15, 644); c.lineTo(x + 20, 652); c.lineTo(x + 70 * cr, 646); c.stroke(); }
        c.shadowBlur = 0;
      }
      // torrents from the lit breaks, reaching further down as they pour
      for (let i = 0; i < GATES.length; i++) {
        const x = GATES[i], w = 64 * open * (0.85 + 0.15 * Math.sin(i * 2.1));
        if (w < 1 || pour <= 0) continue;
        const bot = K.lerp(150, level, pour);
        const g = c.createLinearGradient(0, 150, 0, bot);
        g.addColorStop(0, K.rgba('#CFE3EE', 0.9)); g.addColorStop(1, K.rgba('#7FA9C4', 0.75));
        c.fillStyle = g; c.fillRect(x - w / 2, 150, w, bot - 150);
        c.strokeStyle = K.rgba('#FFFFFF', 0.45); c.lineWidth = 2;
        c.beginPath();
        for (let k = 0; k < 5; k++) {
          const lx = x - w / 2 + (k + 0.5) * w / 5;
          for (let y = K.mod(t * 420 + k * 37, 90) + 150; y < bot; y += 90) { c.moveTo(lx, y); c.lineTo(lx, Math.min(bot, y + 38)); }
        }
        c.stroke();
        if (pour > 0.98) { c.fillStyle = K.rgba('#E6F2F6', 0.8); c.beginPath(); c.ellipse(x, level, w * 0.9, 9 + Math.sin(t * 9 + i) * 2, 0, 0, TAU); c.fill(); K.spray(c, t, 80 + i, 12, x - w, x + w, level, 60, '#E6F2F6', 0.8); }
      }
      // springs burst up on «عيونًا»
      c.lineCap = 'round';
      for (const [x, delay] of SPRINGS) {
        const k = A(t, uy - 0.15 + delay, 0.6, K.easeOutBack);
        if (k <= 0) continue;
        const hj = k * (120 + 22 * Math.sin(t * 4 + x)), base = Math.min(level, 650);
        for (let j = -3; j <= 3; j++) {
          const sp = j * 22 * K.clamp(k), ah = hj * (1 - Math.abs(j) * 0.16);
          c.strokeStyle = K.rgba(Math.abs(j) % 2 ? '#8CC8DB' : '#B9E3EE', 0.9);
          c.lineWidth = 8 - Math.abs(j) * 1.4;
          c.beginPath(); c.moveTo(x, base);
          if (j === 0) c.lineTo(x, base - ah);
          else c.quadraticCurveTo(x + sp, base - 2 * ah, x + 2 * sp, base - ah * 0.25);
          c.stroke();
        }
        K.spray(c, t, x | 0, 14, x - 30, x + 30, base - hj, 60, '#D9F1F6', 0.85 * K.clamp(k));
      }
      K.water(c, (x) => level + 7 * Math.sin(x * 0.02 + t * 2.2) + 4 * Math.sin(x * 0.047 - t * 3.1), level - 20, H + 60, '#4E8FAD', '#23506E', K.rgba('#CFE6EE', 0.8), 3);
      // the meeting: a ring of light where the rising water touches the torrents
      const meet = A(t, lt + 0.2, 0.3) * (1 - A(t, lt + 0.9, 0.8));
      for (const x of GATES) K.glow(c, x, level, 140, '#E8F6FF', 0.35 * meet);
    });
    K.par(c, 0.95, () => {
      for (let i = 0; i < 9; i++) {
        const gap = GATES.some((g) => Math.abs(-60 + i * 175 - g) < 90) ? open * 26 : 0;
        K.cloud(c, -60 + i * 175 + Math.sin(t * 0.3 + i) * 6, 110 + (i % 2) * 30 - gap, 1.5, i % 2 ? '#454F6C' : '#525C7A');
      }
      for (const x of GATES) K.glow(c, x, 150, 100 * open + 1, '#C9DCE8', 0.55 * open);
    });
    K.par(c, 1.12, () => K.rain(c, t, 88, 240, 0.25 + 0.2 * pour, -60, 900, 26));
  },
};

// ---- 9. The ark sails on waves like mountains (Hud 11:42) ----
// «موج» -> the swell grows; «كالجبال» -> a mountain of water lifts the ark and
// the camera tilts up with it.
const swell = (x, t, base, Am, L, v, ph = 0) => {
  const th = ((x - v * t) / L) * TAU + ph;
  return base - Am * (Math.sin(th) + 0.28 * Math.sin(2 * th - Math.PI / 2));
};
const amp9 = (t) => 60 + 40 * A(t, B(9, 'موج', 3.12) - 0.3, 1.0) + 70 * A(t, B(9, 'كالجبال', 5.04) - 0.4, 1.2);
const s9 = {
  cam: (p, t) => {
    const y = swell(640, t, 470, amp9(t), 820, 70);
    return [1.1, K.lerp(600, 690, p), K.lerp(360, y - 30, 0.45), Math.sin(t * 0.8) * 0.012];
  },
  draw(c, t, d, p) {
    const Am = amp9(t);
    K.par(c, 0, () => {
      K.sky(c, ['#3B4668', '#5B6B8C', '#8D9EB3'], 0, 480);
    });
    K.par(c, 0.3, () => { for (let i = 0; i < 7; i++) K.cloud(c, K.mod(-100 + i * 230 + t * 40, W + 500) - 250, 90 + (i % 3) * 30, 1.4, i % 2 ? '#4A5576' : '#56627F'); });
    K.par(c, 0.55, () => K.water(c, (x) => swell(x, t, 380, 45 + Am * 0.3, 520, 40, 1.3), 300, H, '#3F6F8F', '#2A4F6C', K.rgba('#B8D4E0', 0.5), 2));
    K.par(c, 1, () => {
      const surf = (x) => swell(x, t, 470, Am, 820, 70);
      K.water(c, surf, 360, H + 100, '#3F86A2', '#1F4F6A', K.rgba('#E3F2F4', 0.85), 4);
      for (let x = -200; x < W + 200; x += 410) K.spray(c, t, 900 + x, 10, x - 80, x + 80, surf(x), 40 + Am * 0.3, '#E8F6F8', 0.6);
      const ax = 640, s = 0.42, y0 = surf(ax), slope = (surf(ax + 20) - surf(ax - 20)) / 40;
      c.save(); c.translate(ax, y0 - 70 * s); c.rotate(K.clamp(Math.atan(slope) * 0.4, -0.2, 0.2));
      K.ark(c, 0, 0, s, { build: 1, door: 'closed', light: 0.72 });
      c.restore();
    });
    K.par(c, 1.25, () => {
      c.globalAlpha = 0.92;
      K.water(c, (x) => swell(x, t, 640, 50 + Am * 0.25, 600, 90, 2.2) + 30, 520, H + 160, '#357A97', '#1C4861', K.rgba('#E3F2F4', 0.8), 3);
      c.globalAlpha = 1;
    });
    K.par(c, 1.15, () => K.rain(c, t, 9, 220, 0.35, -160, 900, 26));
  },
};

// ---- 10. He calls his son; a great wave comes between them (Hud 11:42-43) ----
// Only the sea, the ark and one far lone peak are drawn - no person. The light
// on the ark (Nuh's presence) pulses on «ونادى» and on «فقال نوح»; «جبلًا»
// -> the camera finds the lone peak; «الموج بينهما» -> a great wave rises
// between the ark and the peak and covers it; then calm.
const PEAK10 = 1020;
const s10 = {
  cam: (p, t, d) => {
    const jb = B(10, 'جبل', 6.64), qa = B(10, 'فقال', 8.96), mw = B(10, 'الموج', 15.28);
    const toPeak = A(t, jb - 0.6, 1.4), wide = A(t, qa + 1.6, 2.4);
    let x = K.lerp(K.lerp(470, 500, E(K.clamp(t / jb))), 900, toPeak);
    x = K.lerp(x, 640, wide);
    let z = K.lerp(K.lerp(1.38, 1.3, E(K.clamp(t / jb))), 1.2, toPeak);
    z = K.lerp(z, 1.02, wide) + 0.05 * A(t, mw, 1.2);
    return [z, x, K.lerp(K.lerp(430, 380, toPeak), 360, wide), Math.sin(t * 0.7) * 0.01];
  },
  draw(c, t, d, p) {
    const nd = B(10, 'ونادى', 0.32), qa = B(10, 'فقال', 8.96), mw = B(10, 'الموج', 15.28), gh = B(10, 'الغارق', 17.52);
    const calm = A(t, gh - 0.4, 1.4);
    K.par(c, 0, () => K.sky(c, [K.mix('#3E4868', '#58648A', calm), K.mix('#5E6C8E', '#7E8CA8', calm), K.mix('#8E9CB2', '#A8B4C4', calm)], 0, 480));
    K.par(c, 0.25, () => { for (let i = 0; i < 6; i++) K.cloud(c, K.mod(-100 + i * 260 + t * 26, W + 500) - 250, 100 + (i % 2) * 40, 1.3, '#56607F'); });
    // the lone peak, far: it sinks while the wave hides it, so after the wave it is gone
    const wave = A(t, mw - 0.4, 1.0) * (1 - A(t, gh - 0.2, 1.6));
    const sink = A(t, mw + 0.5, 1.2);
    K.par(c, 0.5, () => {
      const top = K.lerp(300, 520, sink);
      K.mountain(c, PEAK10, 560, 360, 560 - top, '#5E6884', '#4C5570');
      K.water(c, (x) => 470 + 6 * Math.sin(x * 0.02 + t * 1.8), 440, H + 100, '#3F7590', '#24506A', K.rgba('#C8DEE6', 0.6), 2);
    });
    // the great wave between them, travelling toward the peak
    K.par(c, 0.75, () => {
      const cx = K.lerp(720, 1060, A(t, mw - 0.4, gh - mw + 1.4, (x) => x)), Aw = 380 * wave, sg = 170;
      const surf = (x) => { const dx = x - cx, s = dx < 0 ? sg * 1.1 : sg * 0.7; return 500 - Aw * Math.exp(-(dx / s) * (dx / s)) + 6 * Math.sin(x * 0.02 + t * 2.4); };
      K.water(c, surf, 500 - Aw, H + 100, '#4A97AE', '#1E5A74', K.rgba('#EEF8F8', 0.9), 5);
      if (Aw > 40) {
        c.strokeStyle = K.rgba('#F4FBFB', 0.75); c.lineWidth = 9; c.lineCap = 'round';
        c.beginPath();
        for (let x = cx - sg * 0.2; x <= cx + sg * 0.9; x += 6) (x === cx - sg * 0.2 ? c.moveTo(x, surf(x) + 7) : c.lineTo(x, surf(x) + 7));
        c.stroke();
        K.spray(c, t, 1043, 26, cx - 60, cx + 120, surf(cx) + 10, 70, '#F0FAFA', 0.7 * wave);
      }
    });
    K.par(c, 1, () => {
      const Am = K.lerp(70, 22, calm);
      const surf = (x) => swell(x, t, 520, Am, 700, 60, 0.4);
      K.water(c, surf, 420, H + 100, '#3F86A2', '#1F4F6A', K.rgba('#E3F2F4', 0.85), 4);
      const ax = 440, s = 0.4, y0 = surf(ax), slope = (surf(ax + 20) - surf(ax - 20)) / 40;
      c.save(); c.translate(ax, y0 - 70 * s); c.rotate(K.clamp(Math.atan(slope) * 0.4, -0.18, 0.18));
      K.ark(c, 0, 0, s, { build: 1, door: 'closed', light: 0.7 });
      // his presence on deck, calling - stronger on «ونادى» and on «فقال نوح»
      const call = Math.max(A(t, nd, 0.4) * (1 - A(t, nd + 2.6, 1.0)), A(t, qa, 0.4) * (1 - A(t, qa + 4.6, 1.2)));
      K.presence(c, 108, -16, 18 + 8 * call, t, 0.7 + 0.3 * call);
      c.restore();
    });
    K.par(c, 1.15, () => K.rain(c, t, 17, 200, 0.32 * (1 - calm * 0.5), -100, 900, 24));
  },
};

// ---- 11. «يا أرض ابلعي ماءك ويا سماء أقلعي» - the earth swallows the water,
// the rain stops, the ark rests on al-Judi (Hud 11:44) ----
// Beats from the recitation, then from the narration that follows it.
const SUMMIT = 300;
const restMountain = (c, col, shade, rock, green) => {
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
  if (green > 0.01) for (const [x, y, s] of [[430, 470, 1.1], [520, 420, 0.9], [360, 590, 1.2], [800, 430, 0.9], [900, 520, 1.1], [610, 560, 1.0]]) K.shrub(c, x, y, s * green, K.rgba('#7E9A5A', green));
};
const s11 = {
  cam: (p, t, d) => {
    const ist = B(11, 'واستوت', 20.72), jd = B(11, 'الجودي', 22.8), bu = B(11, 'للقوم', 26.56), ib = B(11, 'فابتلعت', 31.2), sq = B(11, 'واستقرت', 35.52);
    const a = A(t, 0, ist), b = A(t, ist - 0.5, jd - ist + 1.5), c2 = A(t, bu - 1, 4), e = A(t, sq - 0.4, d - sq + 0.4);
    let z = K.lerp(1.3, 1.16, a); z = K.lerp(z, 1.3, b); z = K.lerp(z, 1.02, c2); z = K.lerp(z, 1.4, e);
    let x = K.lerp(600, 620, a) + 40 * Math.sin(t * 0.12); x = K.lerp(x, 640, b);
    let y = K.lerp(280, 300, a); y = K.lerp(y, 260, b); y = K.lerp(y, 380, c2); y = K.lerp(y, 270, e);
    return [z, x, y + 10 * A(t, ib, 2), 0];
  },
  draw(c, t, d, p) {
    const ib0 = B(11, 'ابلعي', 3.92), aq = B(11, 'أقل', 10.32), gh = B(11, 'غيض', 11.68), qd = B(11, 'وقضي', 15.2), jd = B(11, 'الجودي', 22.8);
    const ib = B(11, 'فابتلعت', 31.2), sq = B(11, 'واستقرت', 35.52);
    const rainA = 0.38 * (1 - A(t, aq - 0.5, 2.5));
    const clear = A(t, aq, qd + 3 - aq);
    const sunA = A(t, qd - 0.5, 2.5);
    K.par(c, 0, () => {
      K.sky(c, [K.mix('#4B5575', '#78B6D6', clear), K.mix('#6E7D99', '#B9DDEA', clear), K.mix('#98A6B8', '#F4E4C4', clear)], 0, 500);
      K.rays(c, 1050, 150, 11, 1100, Math.PI * 0.55, Math.PI * 1.02, '#FFF0C8', 0.12 * sunA, t);
      K.sun(c, 1050, 150, 34, '#FFF1C4', '#FFD68A', 0.45, sunA);
    });
    K.par(c, 0.3, () => {
      for (let i = 0; i < 7; i++) {
        const dir = i < 3.5 ? -1 : 1;
        K.cloud(c, -80 + i * 230 + dir * clear * 560 + Math.sin(t * 0.2 + i) * 10, 90 + (i % 2) * 40, 1.4, K.mix('#56607F', '#F4F1EA', clear), 1 - clear * 0.6);
      }
    });
    K.par(c, 0.12, () => K.dust(c, t, 1144, 20, '#FFFFFF', 0.25 * clear, -100, W + 100, 0, 500, 3));
    K.par(c, 0.5, () => {
      K.mountain(c, 190, 700, 640, 300, K.mix('#6F7A94', '#A7A3B5', clear), K.mix('#5E6882', '#8E8AA0', clear));
      K.mountain(c, 1110, 700, 700, 330, K.mix('#6F7A94', '#A7A3B5', clear), K.mix('#5E6882', '#8E8AA0', clear));
      K.haze(c, 380, 720, K.mix('#8090A8', '#E6EEF2', clear), 0.25);
    });
    K.par(c, 1, () => {
      restMountain(c, K.mix('#7A6A63', '#B09279', clear), K.mix('#62544F', '#90735F', clear), K.mix('#5A4B45', '#8A6E5A', clear), A(t, ib, 4));
      // the water: begins to sink on «ابلعي», faster on «وغيض», reaches the
      // summit on «الجودي»; on «فابتلعت» it sinks the rest of the way
      let level = K.lerp(200, 240, A(t, ib0, gh - ib0, (x) => x));
      level = K.lerp(level, SUMMIT + 4, A(t, gh, jd - gh - 0.4));
      level = K.lerp(level, 430, A(t, jd, ib - jd, (x) => x));
      level = K.lerp(level, 680, A(t, ib, sq - ib + 1.5));
      const s = 0.33, float = K.clamp((SUMMIT - level) / 30);
      const bottom = Math.min(level, SUMMIT) + 18 * s * float;
      const ax = K.lerp(560, 640, A(t, 0, jd));
      const bob = Math.sin(t * 1.7) * 4 * float, rot = Math.sin(t * 1.3) * 0.05 * float;
      c.save(); c.translate(ax, bottom - 140 * s + bob); c.rotate(rot);
      K.ark(c, 0, 0, s, { build: 1, door: 'closed', light: K.lerp(0.72, 1, clear) });
      K.presence(c, 84, -10, 14, t, 0.55 + 0.45 * A(t, sq, 2));
      c.restore();
      const calmW = K.lerp(6, 2, A(t, aq, 6));
      K.water(c, (x) => level + calmW * Math.sin(x * 0.02 + t * 1.6) + calmW * 0.5 * Math.sin(x * 0.05 - t), level - 10, H + 100, K.mix('#3F7F98', '#5FA6B8', clear), K.mix('#1F4F6A', '#2F6F88', clear), K.rgba('#EAF6F6', 0.8), 3);
      // sparkle on the calm water once the sun is out
      if (sunA > 0.05) {
        const r = K.rng(1144);
        for (let i = 0; i < 30; i++) {
          const x = r() * W, yy = level + 10 + r() * 140, ph = r() * TAU;
          c.fillStyle = K.rgba('#FFFFFF', 0.6 * sunA * Math.max(0, Math.sin(t * 2.4 + ph)));
          c.fillRect(x, yy, 10, 2);
        }
      }
    });
    K.par(c, 1.12, () => K.rain(c, t, 21, 200, rainA, -60, 900, 24));
  },
};

// ---- 12. He and those with him were saved; the lesson (Hud 11:44, al-Ankabut 29:15) ----
// Sunrise, birds, green shoots growing; the ark on its mountain with the warm
// light beside it (brighter on «نوحًا»). «آية للعالمين» -> the camera pulls
// back to the whole wide land. The lower third stays open for the lesson line.
const s12 = {
  cam: (p, t, d) => {
    const ay = B(12, 'آية', 6.0);
    const back = A(t, ay - 0.6, 2.2);
    return [K.lerp(1.55, 1.04, back) + 0.02 * Math.sin(t * 0.3), K.lerp(470, 640, back), K.lerp(330, 362, back), 0];
  },
  draw(c, t, d, p) {
    const nu = B(12, 'نوح', 1.92), ay = B(12, 'آية', 6.0), ta = B(12, 'تعلمنا', 8.08), sb = B(12, 'الصبر', 9.84);
    const up = E(K.seg(p, 0, 0.8));
    K.par(c, 0, () => {
      K.sky(c, ['#8EC3DE', '#CFE0E2', '#F7D6A8', '#F3B98A'], 0, 470);
      const sy = K.lerp(470, 350, up);
      K.rays(c, 820, sy, 12, 950, Math.PI + 0.2, TAU - 0.2, '#FFF1C8', 0.07 * up, t);
      K.sun(c, 820, sy, 38, '#FFF0C2', '#FFB36B', 0.55);
      for (const [x, y, s, v] of [[250, 120, 0.8, 5], [600, 90, 0.6, 4], [1100, 140, 0.7, 6]]) K.cloud(c, K.mod(x + t * v + 200, W + 500) - 250, y, s, '#FFF3E4', 0.85);
    });
    K.par(c, 0.15, () => {
      K.birds(c, t, 1201, 6, 100, 210, 170, 38, 10, '#5A4A50', 0.7 * A(t, ay - 0.5, 1));
      K.birds(c, t + 3, 1202, 4, 700, 150, 120, 30, 8, '#5A4A50', 0.55);
    });
    K.par(c, 0.45, () => {
      K.mountain(c, 300, 520, 760, 250, '#B6A3B8', '#9E8CA6');
      K.mountain(c, 1020, 520, 820, 230, '#B6A3B8', '#9E8CA6');
      // the ark resting on the summit, small and far, the warm light beside it
      K.ark(c, 330, 270 - 140 * 0.12, 0.12, { build: 1, door: 'closed', light: 1 });
      K.presence(c, 362, 249, 10, t, 0.75 + 0.25 * A(t, nu - 0.2, 0.6));
      K.haze(c, 380, 560, '#FBE6CC', 0.3);
    });
    K.par(c, 0.7, () => {
      K.ridge(c, 500, 36, 3.1, 0.9, '#A7B97F');
      K.ridge(c, 535, 24, 6.9, 1.2, '#98B070');
      c.fillStyle = '#E9CFA6';
      c.beginPath(); c.moveTo(-420, 575); c.bezierCurveTo(300, 545, 500, 600, 800, 565); c.bezierCurveTo(1000, 545, 1200, 560, W + 420, 552);
      c.lineTo(W + 420, 572); c.bezierCurveTo(1200, 580, 1000, 565, 800, 588); c.bezierCurveTo(500, 622, 300, 568, -420, 598); c.closePath(); c.fill();
      c.strokeStyle = K.rgba('#FFF7E6', 0.6); c.lineWidth = 2;
      for (let i = 0; i < 6; i++) { const x = K.mod(150 + i * 240 + t * 14, W + 200) - 100; c.beginPath(); c.moveTo(x, 575 + (i % 2) * 6); c.lineTo(x + 40, 575 + (i % 2) * 6); c.stroke(); }
    });
    K.par(c, 1, () => {
      const g = c.createLinearGradient(0, 600, 0, H);
      g.addColorStop(0, '#B9C98A'); g.addColorStop(1, '#A9BC7C');
      c.fillStyle = g; c.fillRect(-420, 600, W + 840, 600);
      // green shoots grow from «تعلمنا»; small flowers open on «الصبر» -
      // kept to the sides, the centre of the lower third stays clear
      const grow = A(t, ta - 0.3, 2.5), bloom = A(t, sb - 0.2, 1.5, K.easeOutBack);
      const r = K.rng(1212);
      for (let i = 0; i < 26; i++) {
        const side = i % 2 ? 1 : -1, x = side < 0 ? 20 + r() * 300 : 960 + r() * 300, y = 612 + r() * 90, h = (10 + r() * 22) * grow, ph = r() * TAU;
        if (h < 0.5) continue;
        const sw = Math.sin(t * 1.5 + ph) * 3;
        c.strokeStyle = '#6E9A48'; c.lineWidth = 2.2; c.lineCap = 'round';
        c.beginPath(); c.moveTo(x, y); c.quadraticCurveTo(x + sw * 0.4, y - h * 0.6, x + sw, y - h); c.stroke();
        c.fillStyle = '#7FAE52';
        c.beginPath(); c.ellipse(x + sw * 0.6 - 4, y - h * 0.6, 5 * grow, 2.4 * grow, -0.5, 0, TAU); c.fill();
        c.beginPath(); c.ellipse(x + sw * 0.6 + 4, y - h * 0.7, 5 * grow, 2.4 * grow, 0.5, 0, TAU); c.fill();
        if (i % 3 === 0 && bloom > 0) { c.fillStyle = i % 2 ? '#F7E3A6' : '#F2C2C8'; c.beginPath(); c.arc(x + sw, y - h, 3.6 * bloom, 0, TAU); c.fill(); }
      }
      for (const [x, s] of [[120, 1.0], [260, 0.8], [1010, 0.9], [1180, 1.1]]) K.shrub(c, x, 604, s, '#86A060');
    });
    K.par(c, 1.08, () => K.dust(c, t, 1212, 30, '#FFF4D8', 0.4, -100, W + 100, 200, 650, 4));
  },
};

window.STORY_SCENES = [s1, s2, s3, s4, s5, s6, s7, s8, s9, s10, s11, s12];
})();
