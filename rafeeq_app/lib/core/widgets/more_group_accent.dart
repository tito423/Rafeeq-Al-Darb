import 'package:flutter/widgets.dart';

/// The accent a [MoreGroup] hands down to the cards inside it.
///
/// «الكارت الذي تحته كروت يأخذ لونًا مميزًا، والكروت التي تحته تأخذ لونه
/// وتكون أقصر عرضًا، وبشكل كروت المصادر والمراجع». Each nested card used to
/// carry its own accent, so an opened group was a row of unrelated colours
/// under one heading. Rather than edit twenty call sites — and rather than
/// take the accent away from a card that is used outside a group too — the
/// group (`MoreGroup`, in the `more` feature) publishes its colour here and [IslamicActionCard] prefers it when
/// there is one.
class MoreGroupAccent extends InheritedWidget {
  final Color accent;

  const MoreGroupAccent({
    super.key,
    required this.accent,
    required super.child,
  });

  static Color? of(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<MoreGroupAccent>()
      ?.accent;

  @override
  bool updateShouldNotify(MoreGroupAccent old) => old.accent != accent;
}
