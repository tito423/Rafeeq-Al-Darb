import 'package:flutter/material.dart';

/// Root navigator key so a notification tap (or a cold launch caused by one)
/// can push a route from outside the widget tree — `main.dart` and
/// `AdhanAlarmService`'s callbacks have no `BuildContext` of their own.
final rootNavigatorKey = GlobalKey<NavigatorState>();
