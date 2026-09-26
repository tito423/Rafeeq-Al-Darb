import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../shamela/data/shamela_import_service.dart' show kShamelaEnabled;
import '../data/dorar_check.dart';
import 'dorar_screen.dart';

/// Whether «تخريج من الدرر» is offered: the GitHub build only, the same gate
/// as the Dorar hub itself.
const bool kDorarCheckEnabled = kShamelaEnabled;

/// The «تخريج من الدرر» button placed next to a hadith.
class DorarCheckButton extends StatelessWidget {
  const DorarCheckButton(
      {super.key,
      required this.text,
      this.color,
      this.alignment = AlignmentDirectional.centerStart});

  /// The hadith as the app shows it (isnad and diacritics included).
  final String text;

  /// For a button drawn over a picture (the adhkar cards are white on a
  /// photograph); the theme's colour otherwise.
  final Color? color;

  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    if (!kDorarCheckEnabled) return const SizedBox.shrink();
    return Align(
      alignment: alignment,
      child: TextButton.icon(
        style: color == null
            ? null
            : TextButton.styleFrom(foregroundColor: color),
        onPressed: () => showDorarCheckSheet(context, text),
        icon: const Icon(Icons.fact_check_outlined, size: 18),
        label: Text('dorar.check'.tr()),
      ),
    );
  }
}

/// Gradings Dorar holds for [text], in a bottom sheet. Only results whose
/// own text matches the matn are listed (see [DorarCheck]); when there are
/// none, the sheet says so and offers Dorar's own search with the words it
/// used - it never lists a near-match as if it were this hadith.
Future<void> showDorarCheckSheet(BuildContext context, String text) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scroll) => _Body(text: text, scroll: scroll),
    ),
  );
}

class _Body extends StatefulWidget {
  const _Body({required this.text, required this.scroll});
  final String text;
  final ScrollController scroll;

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  late Future<DorarCheckResult> _future = DorarCheck.instance.check(widget.text);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final small =
        TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant, height: 1.6);
    return FutureBuilder<DorarCheckResult>(
      future: _future,
      builder: (context, snap) {
        final children = <Widget>[
          Text('dorar.check'.tr(),
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center),
          const SizedBox(height: 12),
        ];
        if (snap.connectionState != ConnectionState.done) {
          children.add(const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ));
        } else if (snap.hasError) {
          children.addAll([
            Text('dorar.failed'.tr(), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Center(
              child: TextButton.icon(
                onPressed: () => setState(() =>
                    _future = DorarCheck.instance.check(widget.text)),
                icon: const Icon(Icons.refresh),
                label: Text('dorar.retry'.tr()),
              ),
            ),
          ]);
        } else {
          final r = snap.data!;
          if (r.query.split(' ').length < DorarCheck.minWords) {
            children.add(Text('dorar.check_too_short'.tr(),
                textAlign: TextAlign.center));
          } else {
            children.add(Text('dorar.check_query'.tr(args: [r.query]),
                style: small));
            children.add(const SizedBox(height: 10));
            if (r.matches.isEmpty) {
              children.add(Text('dorar.check_none'.tr(),
                  textAlign: TextAlign.center));
            } else {
              children.add(Text(
                  'dorar.check_found'.tr(args: ['${r.matches.length}']),
                  style: small));
              children.add(const SizedBox(height: 8));
              for (final h in r.matches) {
                children.add(DorarGradingCard(h: h));
              }
            }
            children.add(Center(
              child: TextButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                      builder: (_) => DorarScreen(initialQuery: r.query)),
                ),
                icon: const Icon(Icons.search),
                label: Text('dorar.check_open_search'.tr()),
              ),
            ));
            children.add(Text('dorar.credit'.tr(),
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 11.5, color: scheme.onSurfaceVariant)));
          }
        }
        return ListView(
          controller: widget.scroll,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: children,
        );
      },
    );
  }
}
