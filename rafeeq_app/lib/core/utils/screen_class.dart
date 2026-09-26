import 'package:flutter/widgets.dart';

/// Layout decisions from the WINDOW'S SIZE, not from the device's
/// orientation or type.
///
/// Owner, 2026-09-26: the app must be laid out right on every phone, tablet
/// and smart screen, upright and sideways - «مش عايز أي مفاجآت». Flutter's
/// adaptive guide says the same thing in its words: decide from
/// `MediaQuery.sizeOf`, never from orientation or device type
/// (docs.flutter.dev/ui/adaptive-responsive/general, read 2026-09-26).
///
/// Orientation was the wrong question in 33 places: «sideways» was used to
/// mean «there is room for two columns», which is true of a phone on its
/// side (~900 dp wide) and ALSO of a tablet held upright (800 dp) - and the
/// tablet got one column of 760 dp cards.
///
/// Breakpoints are Android's window size classes
/// (developer.android.com, page updated 2026-09-22): width compact < 600,
/// medium < 840, expanded >= 840; height compact < 480 - the height of
/// 99.78 % of phones held sideways.
abstract final class ScreenClass {
  static const double mediumWidth = 600;
  static const double expandedWidth = 840;
  static const double compactHeight = 480;

  /// Room for two phone-width columns side by side: a phone sideways, any
  /// tablet, a TV.
  static bool twoColumns(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= mediumWidth;

  /// Height is the scarce direction: a phone on its side.
  static bool shortHeight(BuildContext context) =>
      MediaQuery.sizeOf(context).height < compactHeight;

  /// Wider than tall - for the few layouts that really follow the window's
  /// shape (a page image laid out across the width, a clock set beside its
  /// options). Same answer as the old orientation test, asked of the
  /// window rather than the sensor.
  static bool wide(BuildContext context) {
    final s = MediaQuery.sizeOf(context);
    return s.width > s.height;
  }
}
