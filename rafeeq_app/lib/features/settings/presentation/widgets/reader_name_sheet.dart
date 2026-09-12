/// Asks, once, what the reader would like to be called.
///
/// A sheet rather than a screen, and skippable: the app works perfectly well
/// greeting someone generically, and a first run that blocks on a form is a
/// first run people leave. It is asked after the guided tour rather than
/// before it, so the very first thing a new reader meets is still the app.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/islamic_pattern.dart';
import '../../data/reader_name_provider.dart';

Future<void> showReaderNameSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _ReaderNameSheet(),
  );
}

class _ReaderNameSheet extends ConsumerStatefulWidget {
  const _ReaderNameSheet();

  @override
  ConsumerState<_ReaderNameSheet> createState() => _ReaderNameSheetState();
}

class _ReaderNameSheetState extends ConsumerState<_ReaderNameSheet> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.text = ref.read(readerNameProvider);
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _done(bool save) async {
    final notifier = ref.read(readerNameProvider.notifier);
    if (save) await notifier.set(_controller.text);
    await notifier.markAsked();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = _controller.text.trim();
    return Padding(
      // The keyboard is the whole point of this sheet; it must not cover the
      // field it opened for.
      padding: EdgeInsets.only(
        left: 18,
        right: 18,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 18,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'home.name_ask_title'.tr(),
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'home.name_ask_body'.tr(),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          // A live preview of the greeting itself, in the very face the Home
          // card draws it in — so what you type is what you will see.
          IslamicPatternPanel(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'home.welcome_guest'.tr(),
                      style: TextStyle(
                        fontFamily: context.locale.languageCode == 'ar'
                            ? 'AmiriQuran'
                            : null,
                        fontSize: 18,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (name.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      ReaderNameFlourish(name: name, fontSize: 26),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            textAlign: TextAlign.center,
            textInputAction: TextInputAction.done,
            maxLength: 24,
            onSubmitted: (_) => _done(true),
            decoration: InputDecoration(
              hintText: 'home.name_hint'.tr(),
              counterText: '',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton(
                onPressed: () => _done(false),
                child: Text('home.name_skip'.tr()),
              ),
              const Spacer(),
              FilledButton(
                onPressed: name.isEmpty ? null : () => _done(true),
                child: Text('home.name_save'.tr()),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// The reader's name, set the way a name on a title page is set: the
/// calligraphic face, a gold gradient across the letters, and a small rule
/// with a diamond on each side.
///
/// Drawn with a shader rather than a flat colour because a single gold is
/// flat at this size — the sweep is what makes it read as leaf rather than as
/// yellow text. `ShaderMask` costs one layer and is not animated, so it is
/// cheap enough to sit on the Home header.
class ReaderNameFlourish extends StatelessWidget {
  final String name;
  final double fontSize;

  const ReaderNameFlourish({
    super.key,
    required this.name,
    this.fontSize = 22,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Diamond(size: fontSize * 0.28),
        SizedBox(width: fontSize * 0.32),
        ShaderMask(
          shaderCallback: (rect) => const LinearGradient(
            colors: [AppColors.goldSoft, AppColors.gold, AppColors.goldSoft],
            stops: [0, 0.5, 1],
          ).createShader(rect),
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'AmiriQuran',
              fontSize: fontSize,
              height: 1.6,
              fontWeight: FontWeight.w700,
              // ShaderMask paints over this, but a colour is still needed for
              // the glyphs to have coverage at all.
              color: Colors.white,
            ),
          ),
        ),
        SizedBox(width: fontSize * 0.32),
        _Diamond(size: fontSize * 0.28),
      ],
    );
  }
}

class _Diamond extends StatelessWidget {
  final double size;
  const _Diamond({required this.size});

  @override
  Widget build(BuildContext context) => Transform.rotate(
        angle: 0.785398,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: AppColors.gold.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(size * 0.18),
          ),
        ),
      );
}
