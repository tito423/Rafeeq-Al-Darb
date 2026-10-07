/// The state of one journey in «قافلة الدرب», stepped once per frame.
///
/// Units are fractions of the screen (x of its width, y of its height), so
/// the journey plays the same on a phone, a tablet and a TV, either way up.
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart';

enum CaravanMode { kids, adults }

enum CaravanPhase { running, arriving, atGate, won, lost }

class Rock {
  double x;
  bool hit = false;
  Rock(this.x);
}

class Lantern {
  double x;

  /// Height above the road in camel heights, so a lantern sits where a
  /// jump reaches it on any screen.
  final double lift;
  bool taken = false;
  Lantern(this.x, this.lift);
}

class Spark {
  final double x, y;
  double age = 0;
  Spark(this.x, this.y);
}

class CaravanWorld extends ChangeNotifier {
  CaravanWorld({required this.mode, int seed = 1}) : _rnd = math.Random(seed) {
    _layOut();
  }

  final CaravanMode mode;
  final math.Random _rnd;

  /// The camel's size in pixels, whichever is smaller: a fifth of the
  /// width or a sixth of the height - so a phone held upright does not get
  /// camels taller than its width, and a TV does not get tiny ones. Set by
  /// the screen from its layout; [camelW] is that size as a fraction of the
  /// width, [camelH] of the height.
  double camelW = 0.16, camelH = 0.16;

  void fit(double width, double height) {
    final px = math.min(width * 0.2, height * 0.16);
    camelW = px / width;
    camelH = px / height;
  }

  static const groundY = 0.80;
  static const leadX = 0.45;

  /// Seconds of road from the first city to the next.
  static const legSeconds = 38.0;

  /// Screen widths per second.
  double get speed => (mode == CaravanMode.kids ? 0.34 : 0.44) * _slow;
  double _slow = 1;

  double time = 0;
  double distance = 0;
  double get progress => (time / legSeconds).clamp(0, 1);
  double stride = 0;
  CaravanPhase phase = CaravanPhase.running;

  final rocks = <Rock>[];
  final lanterns = <Lantern>[];
  final sparks = <Spark>[];
  int collected = 0;
  int lanternsTotal = 0;
  int hearts = 3;
  double hurtFor = 0;

  /// The city gate's x once it is on screen, and how open its doors are.
  double? gateX;
  double gateOpen = 0;

  // The lead camel's jump, and its recent heights so the followers can
  // repeat it a beat later.
  double _y = 0, _vy = 0;

  /// Gravity, in screen heights per second squared; a jump lasts about
  /// 0.75 s on any screen because its height scales with the camel.
  double get _g => camelH * 28;
  final _trail = <double>[];

  void _layOut() {
    // Rocks and lanterns along the road, spaced so every rock can be
    // cleared and the lanterns sit where a jump reaches them.
    var x = 1.6;
    final end = legSeconds * speed - 1.2;
    while (x < end) {
      if (_rnd.nextDouble() < 0.55) {
        rocks.add(Rock(x));
        // A lantern above the rock rewards the jump.
        if (_rnd.nextDouble() < 0.6) lanterns.add(Lantern(x, 1.9));
      } else {
        lanterns.add(Lantern(x, 1.2 + _rnd.nextDouble() * 0.8));
      }
      x += 0.9 + _rnd.nextDouble() * 0.9;
    }
    lanternsTotal = lanterns.length;
  }

  /// A lantern's height on the screen, as a fraction of its height.
  double ly(Lantern l) => groundY - l.lift * camelH;

  bool get canJump => _y <= 0.0001 && phase == CaravanPhase.running;

  void jump() {
    if (!canJump) return;
    // A jump that peaks at about twice the camel's height: enough to clear
    // a rock and reach the highest lantern, whatever the screen.
    _vy = math.sqrt(2 * _g * camelH * 2.0);
  }

  /// Height above the ground of camel [i] (0 = lead), as a screen fraction.
  double liftAt(int i) {
    if (i == 0) return _y;
    final back = i * 9; // frames behind the lead
    if (_trail.length <= back) return 0;
    return _trail[_trail.length - 1 - back];
  }

  void step(double dt) {
    dt = dt.clamp(0, 1 / 20);
    time += phase == CaravanPhase.running ? dt : 0;
    for (final s in sparks) {
      s.age += dt;
    }
    sparks.removeWhere((s) => s.age > 0.6);
    if (hurtFor > 0) hurtFor -= dt;

    final moving =
        phase == CaravanPhase.running || phase == CaravanPhase.arriving;
    if (moving) {
      final dx = speed * dt;
      distance += dx;
      stride = (stride + dt * 1.6) % 1.0;
      for (final r in rocks) {
        r.x -= dx;
      }
      for (final l in lanterns) {
        l.x -= dx;
      }
      if (gateX != null) gateX = gateX! - dx;
      _slow = math.min(1, _slow + dt * 0.8);
    }

    // Jump physics.
    _vy -= _g * dt;
    _y = math.max(0, _y + _vy * dt);
    if (_y == 0 && _vy < 0) _vy = 0;
    _trail.add(_y);
    if (_trail.length > 40) _trail.removeAt(0);

    // Collisions with the lead camel.
    for (final r in rocks) {
      if (!r.hit && (r.x - leadX).abs() < camelW * 0.35 && _y < camelH * 0.3) {
        r.hit = true;
        hurtFor = 0.5;
        if (mode == CaravanMode.kids) {
          _slow = 0.5; // a stumble, never a loss
        } else {
          hearts -= 1;
          if (hearts <= 0) phase = CaravanPhase.lost;
        }
      }
    }
    for (final l in lanterns) {
      final camelTop = groundY - camelH - _y;
      if (!l.taken &&
          (l.x - leadX).abs() < camelW * 0.45 &&
          ly(l) > camelTop - camelH * 0.3 &&
          ly(l) < groundY - _y) {
        l.taken = true;
        collected += 1;
        sparks.add(Spark(l.x, ly(l)));
      }
    }
    rocks.removeWhere((r) => r.x < -0.2);

    // The end of the leg: the city rises, the caravan walks up to its gate.
    if (phase == CaravanPhase.running && time >= legSeconds) {
      phase = CaravanPhase.arriving;
      gateX = 1.35;
      rocks.clear();
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
