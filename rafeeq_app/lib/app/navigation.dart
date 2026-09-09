import 'package:flutter/material.dart';

/// Root navigator key so a notification tap (or a cold launch caused by one)
/// can push a route from outside the widget tree — `main.dart` and
/// `AdhanAlarmService`'s callbacks have no `BuildContext` of their own.
final rootNavigatorKey = GlobalKey<NavigatorState>();

/// The app's one `ScaffoldMessenger`, so a snackbar can be dismissed from
/// outside the widget that showed it.
///
/// A root-messenger snackbar deliberately survives a push to another screen —
/// that is what makes an undo offer usable. It also survived a LANGUAGE change,
/// which is not: `.tr()` is read once, at build, and nothing rebuilds a
/// snackbar. «Lu aujourd'hui» was photographed sitting over an English Library
/// and over an Arabic hadith page.
final rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
