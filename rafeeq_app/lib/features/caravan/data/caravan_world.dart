/// The state of one journey in «قافلة الدرب», stepped once per frame.
///
/// Units are fractions of the screen (x of its width, y of its height), and
/// every height that touches the camel is in camel heights, so the journey
/// plays the same on a phone, a tablet and a TV, either way up.
///
/// The road is a short story, not one repeated jump (owner, 2026-10-07:
/// «القفز مدته طويلة … خليهم يعملوا اي حاجة جذابة وجيمي في الطريق»):
/// rocks to jump, a low flock of birds to duck under, an oasis with an arc
/// of lanterns, a sandstorm, and a golden star only a double jump reaches.
library;

import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';

enum CaravanMode { kids, adults }

enum CaravanPhase { running, arriving, atGate, won, lost }

/// One leg of the journey: the two cities, the question at the far gate (an
/// id in the verified quiz bank - never a question written here), and the
/// banners of its road.
class CaravanLeg {
  final int number;
  final String fromKey, toKey, titleKey, wonKey;
  final String gateQuestionId;

  /// The banner of the scenery stop in the middle of the road, and of the
  /// hard stretch after it.
  final String midKey, hardKey;
  const CaravanLeg({
    required this.number,
    required this.fromKey,
    required this.toKey,
    required this.titleKey,
    required this.wonKey,
    required this.gateQuestionId,
    required this.midKey,
    required this.hardKey,
  });

  /// Leg one: Makkah to Madinah, dawn to afternoon, an oasis and a
  /// sandstorm. Gate: «إلى أي مدينة أذن النبي ﷺ للمسلمين أن يهاجروا من
  /// مكة؟» (al-Fusul fi Sirat al-Rasul, p. 113).
  ///
  /// Leg two: Madinah to Bayt al-Maqdis, north into al-Sham, afternoon to
  /// night, olive groves and a dark stretch lit by the lanterns. Gate: «في
  /// خلافة من فُتح بيت المقدس؟» (al-Suyuti, Tarikh al-Khulafa, p. 238:
  /// «سار عمر ففتح بيت المقدس»).
  static const first = CaravanLeg(
    number: 1,
    fromKey: 'caravan.makkah',
    toKey: 'caravan.madinah',
    titleKey: 'caravan.leg1',
    wonKey: 'caravan.won_title',
    gateQuestionId: 'ef3e67153c',
    midKey: 'caravan.ev_oasis',
    hardKey: 'caravan.ev_storm',
  );

  static const all = [
    first,
    CaravanLeg(
      number: 2,
      fromKey: 'caravan.madinah',
      toKey: 'caravan.quds',
      titleKey: 'caravan.leg2',
      wonKey: 'caravan.won_title2',
      gateQuestionId: '96c6f015e7',
      midKey: 'caravan.ev_olives',
      hardKey: 'caravan.ev_night',
    ),
  ];

  bool get isLast => number == all.length;
  CaravanLeg get next => all[number];
}

class Rock {
  double x;
  bool hit = false;
  Rock(this.x);
}

/// A low flock: its bottom edge is below a standing camel's head, above a
/// crouching one.
class Birds {
  double x;
  bool hit = false;
  Birds(this.x);
}

class Lantern {
  double x;

  /// Height above the road in camel heights.
  final double lift;

  /// The golden star: worth five, only reachable with a double jump.
  final bool golden;
  bool taken = false;
  Lantern(this.x, this.lift, {this.golden = false});
}

class Spark {
  final double x, y;
  double age = 0;
  Spark(this.x, this.y);
}

/// Floating text over the road: «+١», «سلسلة ×٣».
class Popup {
  final String text;
  final double x, y;
  final bool gold;
  double age = 0;
  Popup(this.text, this.x, this.y, {this.gold = false});
}

class CaravanWorld extends ChangeNotifier {
  CaravanWorld({
    required this.mode,
    this.leg = CaravanLeg.first,
    this.lang = 'ar',
    int seed = 1,
  }) : _rnd = math.Random(seed) {
    _layOut();
  }

  final CaravanMode mode;
  final CaravanLeg leg;
  final String lang;

  /// Leg two goes from afternoon into night; leg one from dawn into day.
  bool get toNight => leg.number == 2;
  final math.Random _rnd;

  static const groundY = 0.80;
  static const leadX = 0.45;

  /// Seconds of road from the first city to the next.
  static const legSeconds = 30.0;

  // Where each part of the road is, as a fraction of the leg.
  static const birdsFrom = 0.28;
  static const oasisAt = 0.45;
  static const stormFrom = 0.6, stormTo = 0.8;
  static const starAt = 0.88;

  /// The camel's size: the smaller of a fifth of the width or a sixth of
  /// the height. [camelW] is a fraction of the width, [camelH] of the
  /// height. Set by the screen from its layout.
  double camelW = 0.16, camelH = 0.16;

  void fit(double width, double height) {
    final px = math.min(width * 0.2, height * 0.16);
    camelW = px / width;
    camelH = px / height;
  }

  /// Each leg is a little faster than the one before it.
  double get _baseSpeed =>
      (mode == CaravanMode.kids ? 0.36 : 0.46) * (1 + 0.08 * (leg.number - 1));

  /// Screen widths per second.
  double get speed => _baseSpeed * _slow;
  double _slow = 1;

  double time = 0;
  double distance = 0;
  double get progress => (time / legSeconds).clamp(0, 1);
  double stride = 0;
  CaravanPhase phase = CaravanPhase.running;

  final rocks = <Rock>[];
  final birds = <Birds>[];
  final lanterns = <Lantern>[];
  final sparks = <Spark>[];
  final popups = <Popup>[];
  int collected = 0;
  int lanternsTotal = 0;
  int streak = 0;
  int hearts = 3;
  double hurtFor = 0;

  /// The oasis scenery's x while it passes, else null.
  double? oasisX;

  /// 0..1, how thick the sandstorm is (leg one).
  double storm = 0;

  /// 0..1, how dark the night is (leg two): it falls with the hard stretch
  /// and stays, so the caravan reaches the city under its lamps.
  double night = 0;

  /// A banner across the screen when a part of the road begins, by key.
  String? banner;
  double bannerAge = 0;
  final _shown = <String>{};

  /// The city gate's x once it is on screen, and how open its doors are.
  double? gateX;
  double gateOpen = 0;

  // The lead camel: height, speed up, whether its air jump is used, and how
  // long it stays crouched. Its recent heights let the followers repeat it.
  double _y = 0, _vy = 0;
  bool _doubled = false;
  double duckFor = 0;
  double get _g => camelH * 28;
  final _trail = <double>[];
  final _duckTrail = <double>[];

  void _layOut() {
    final d = legSeconds * _baseSpeed;
    double at(double f) => leadX + 1.2 + f * (d - 1.6);
    // Warm-up: rocks and lanterns.
    var f = 0.04;
    while (f < birdsFrom) {
      _rockOrLantern(at(f));
      f += 0.045 + _rnd.nextDouble() * 0.03;
    }
    // Birds join the rocks.
    while (f < oasisAt - 0.04) {
      if (_rnd.nextDouble() < 0.5) {
        birds.add(Birds(at(f)));
        lanterns.add(Lantern(at(f) + 0.25, 0.6));
      } else {
        _rockOrLantern(at(f));
      }
      f += 0.05 + _rnd.nextDouble() * 0.03;
    }
    // The oasis: an arc of seven lanterns over the water.
    for (var i = 0; i < 7; i++) {
      final t = i / 6;
      lanterns.add(
        Lantern(at(oasisAt) + i * 0.12, 0.9 + math.sin(t * math.pi) * 1.1),
      );
    }
    f = oasisAt + 0.08;
    // Then the storm, then the run to the star.
    while (f < starAt - 0.03) {
      final r = _rnd.nextDouble();
      if (r < 0.35) {
        rocks.add(Rock(at(f)));
      } else if (r < 0.55) {
        birds.add(Birds(at(f)));
      } else {
        lanterns.add(Lantern(at(f), 1.0 + _rnd.nextDouble() * 0.9));
      }
      f += 0.045 + _rnd.nextDouble() * 0.03;
    }
    // A rock to launch from, and the golden star above it.
    rocks.add(Rock(at(starAt)));
    lanterns.add(Lantern(at(starAt) + 0.05, 3.3, golden: true));
    lanternsTotal = lanterns.length;
  }

  void _rockOrLantern(double x) {
    if (_rnd.nextDouble() < 0.55) {
      rocks.add(Rock(x));
      if (_rnd.nextDouble() < 0.6) lanterns.add(Lantern(x, 1.9));
    } else {
      lanterns.add(Lantern(x, 1.1 + _rnd.nextDouble() * 0.8));
    }
  }

  /// A lantern's height on the screen, as a fraction of its height.
  double ly(Lantern l) => groundY - l.lift * camelH;

  bool get _onGround => _y <= 0.0001;
  bool get crouching => duckFor > 0;

  /// Tap: jump; tap again in the air: one more jump.
  void jump() {
    if (phase != CaravanPhase.running) return;
    if (_onGround) {
      _doubled = false;
    } else if (_doubled) {
      return;
    } else {
      _doubled = true;
    }
    duckFor = 0;
    _vy = math.sqrt(2 * _g * camelH * 2.0);
  }

  /// Swipe down: crouch; in the air, drop fast and crouch on landing.
  void duck() {
    if (phase != CaravanPhase.running) return;
    if (!_onGround) _vy = -math.sqrt(2 * _g * camelH * 4);
    duckFor = 0.75;
  }

  /// Height above the ground of camel [i] (0 = lead), as a screen fraction.
  double liftAt(int i) {
    if (i == 0) return _y;
    final back = i * 9; // frames behind the lead
    if (_trail.length <= back) return 0;
    return _trail[_trail.length - 1 - back];
  }

  /// How crouched camel [i] is, 0 or 1.
  double crouchAt(int i) {
    final back = i * 9;
    if (_duckTrail.length <= back) return 0;
    return _duckTrail[_duckTrail.length - 1 - back];
  }

  void _pop(String text, double x, double y, {bool gold = false}) =>
      popups.add(Popup(text, x, y, gold: gold));

  void _announce(String key) {
    if (_shown.add(key)) {
      banner = key;
      bannerAge = 0;
    }
  }

  String _n(int v) => lang == 'ar'
      ? '$v'.replaceAllMapped(
          RegExp('[0-9]'),
          (m) => String.fromCharCode(0x0660 + int.parse(m[0]!)),
        )
      : '$v';

  void step(double dt) {
    dt = dt.clamp(0, 1 / 20);
    if (phase == CaravanPhase.running) time += dt;
    for (final s in sparks) {
      s.age += dt;
    }
    sparks.removeWhere((s) => s.age > 0.6);
    for (final p in popups) {
      p.age += dt;
    }
    popups.removeWhere((p) => p.age > 1.1);
    bannerAge += dt;
    if (bannerAge > 2.2) banner = null;
    if (hurtFor > 0) hurtFor -= dt;
    if (duckFor > 0 && _onGround) duckFor -= dt;

    final p = progress;
    final hard = toNight ? p > stormFrom : p > stormFrom && p < stormTo;
    final k = math.min(1.0, dt * (toNight ? 0.6 : 1.5));
    if (toNight) {
      night += ((hard ? 1.0 : 0.0) - night) * k;
    } else {
      storm += ((hard ? 1.0 : 0.0) - storm) * k;
    }
    if (phase == CaravanPhase.running) {
      if (p > birdsFrom - 0.02) _announce('caravan.ev_birds');
      if (p > oasisAt - 0.03) _announce(leg.midKey);
      if (p > stormFrom) _announce(leg.hardKey);
      if (p > starAt - 0.06) _announce('caravan.ev_star');
    }

    final moving =
        phase == CaravanPhase.running || phase == CaravanPhase.arriving;
    if (moving) {
      final dx = speed * dt;
      distance += dx;
      stride = (stride + dt * 1.6) % 1.0;
      for (final r in rocks) {
        r.x -= dx;
      }
      for (final b in birds) {
        b.x -= dx;
      }
      for (final l in lanterns) {
        l.x -= dx;
      }
      if (gateX != null) gateX = gateX! - dx;
      _slow = math.min(1, _slow + dt * 0.8);
      // The oasis passes in the middle distance, behind its lantern arc.
      final o = (p - oasisAt) * legSeconds * _baseSpeed;
      oasisX = o > -1.6 && o < 1.4 ? leadX + 0.9 - o : null;
    }

    // Jump physics.
    _vy -= _g * dt;
    _y = math.max(0, _y + _vy * dt);
    if (_y == 0 && _vy < 0) _vy = 0;
    _trail.add(_y);
    _duckTrail.add(crouching ? 1 : 0);
    if (_trail.length > 40) _trail.removeAt(0);
    if (_duckTrail.length > 40) _duckTrail.removeAt(0);

    void hurt() {
      hurtFor = 0.5;
      streak = 0;
      if (mode == CaravanMode.kids) {
        _slow = 0.5; // a stumble, never a loss
      } else {
        hearts -= 1;
        if (hearts <= 0) phase = CaravanPhase.lost;
      }
    }

    // The lead camel's top above the road: a crouch takes it to about half.
    final camelTop = _y + camelH * (crouching ? 0.5 : 0.9);
    for (final r in rocks) {
      if (!r.hit && (r.x - leadX).abs() < camelW * 0.35 && _y < camelH * 0.3) {
        r.hit = true;
        hurt();
      }
    }
    for (final b in birds) {
      // The flock spans 0.65..1.3 camel heights above the road.
      final low = camelH * 0.65, high = camelH * 1.3;
      if (!b.hit &&
          (b.x - leadX).abs() < camelW * 0.4 &&
          camelTop > low &&
          _y < high) {
        b.hit = true;
        hurt();
      }
    }
    for (final l in lanterns) {
      final top = groundY - camelTop;
      if (!l.taken &&
          (l.x - leadX).abs() < camelW * 0.45 &&
          ly(l) > top - camelH * 0.3 &&
          ly(l) < groundY - _y) {
        l.taken = true;
        sparks.add(Spark(l.x, ly(l)));
        if (l.golden) {
          collected += 5;
          _pop('+${_n(5)}', l.x, ly(l), gold: true);
        } else {
          collected += 1;
          streak += 1;
          _pop('+${_n(1)}', l.x, ly(l));
          if (streak >= 3) {
            _pop(
              'caravan.streak'.tr(args: [_n(streak)]),
              leadX,
              groundY - camelTop - camelH * 0.6,
              gold: true,
            );
          }
        }
      }
    }
    rocks.removeWhere((r) => r.x < -0.3);
    birds.removeWhere((b) => b.x < -0.3);

    // The end of the leg: the city rises, the caravan walks up to its gate.
    if (phase == CaravanPhase.running && time >= legSeconds) {
      phase = CaravanPhase.arriving;
      gateX = 1.35;
      rocks.clear();
      birds.clear();
    }
    if (phase == CaravanPhase.arriving && gateX! <= leadX + 0.36) {
      phase = CaravanPhase.atGate;
    }
    if (phase == CaravanPhase.won && gateOpen < 1) {
      gateOpen = math.min(1, gateOpen + dt * 0.7);
    }
    notifyListeners();
  }

  void open() {
    phase = CaravanPhase.won;
  }
}
