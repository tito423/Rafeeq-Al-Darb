/// The cards «قافلة الدرب» shows over the road: speech bubbles, the gate
/// question, the arrival card with its source, and the lost card.
part of 'caravan_screen.dart';

class _Bubble extends StatelessWidget {
  final String text;
  const _Bubble({required this.text});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(30),
    ),
    child: Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _Panel extends StatelessWidget {
  final Widget child;
  const _Panel({required this.child});

  @override
  Widget build(BuildContext context) => Center(
    child: TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutBack,
      builder: (_, t, c) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.scale(scale: 0.85 + 0.15 * t, child: c),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Container(
          margin: const EdgeInsets.all(18),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8E8),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE8C766), width: 2),
            boxShadow: const [BoxShadow(blurRadius: 30, color: Colors.black45)],
          ),
          child: SingleChildScrollView(child: child),
        ),
      ),
    ),
  );
}

class _GateQuestion extends StatelessWidget {
  final QuizQuestion question;
  final List<String> choices;
  final String? wrong;
  final bool kids;
  final void Function(String) onAnswer;
  const _GateQuestion({
    required this.question,
    required this.choices,
    required this.wrong,
    required this.kids,
    required this.onAnswer,
  });

  @override
  Widget build(BuildContext context) => _Panel(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(
          Icons.door_front_door_outlined,
          color: Color(0xFFB8892A),
          size: 40,
        ),
        Text(
          'caravan.gate_title'.tr(),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.ink,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          'caravan.gate_hint'.tr(),
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.inkSoft, fontSize: 13),
        ),
        const SizedBox(height: 12),
        Text(
          question.question,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.ink,
            fontSize: 17,
            fontWeight: FontWeight.w700,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        for (final c in choices)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: c == wrong
                    ? const Color(0xFFC0392B)
                    : const Color(0xFF1F6B5A),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(46),
              ),
              onPressed: c == wrong ? null : () => onAnswer(c),
              child: Text(c, textAlign: TextAlign.center),
            ),
          ),
        if (wrong != null)
          Text(
            (kids ? 'caravan.try_again_kids' : 'caravan.try_again').tr(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFC0392B),
              fontWeight: FontWeight.w700,
            ),
          ),
      ],
    ),
  );
}

class _Arrived extends StatelessWidget {
  final CaravanWorld world;
  final QuizQuestion question;
  final VoidCallback onAgain, onExit;
  const _Arrived({
    required this.world,
    required this.question,
    required this.onAgain,
    required this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;
    final book = libraryBookCatalog
        .where((b) => b.id == question.book)
        .firstOrNull;
    return _Panel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.auto_awesome, color: Color(0xFFB8892A), size: 44),
          Text(
            'caravan.won_title'.tr(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            localizeDigits(
              'caravan.won_lanterns'.tr(
                args: ['${world.collected}', '${world.lanternsTotal}'],
              ),
              lang,
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.inkSoft, fontSize: 15),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF3E7C9),
              borderRadius: BorderRadius.circular(14),
              border: const BorderDirectional(
                start: BorderSide(color: Color(0xFFB8892A), width: 4),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  question.explain,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '«${question.quote}»',
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontFamily: 'AmiriQuran',
                    fontSize: 14,
                    height: 1.7,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'quiz.source'.tr(
                    args: [
                      book == null
                          ? question.book
                          : '${properName(book.titleAr, book.titleEn)} — '
                                '${properName(book.authorAr, book.authorEn)}',
                      localizeDigits('${question.page}', lang),
                    ],
                  ),
                  style: const TextStyle(
                    color: AppColors.inkSoft,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onAgain,
            icon: const Icon(Icons.replay_rounded),
            label: Text('caravan.play_again'.tr()),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1F6B5A),
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
            ),
          ),
          TextButton(onPressed: onExit, child: Text('caravan.exit'.tr())),
        ],
      ),
    );
  }
}

class _Lost extends StatelessWidget {
  final VoidCallback onAgain, onExit;
  const _Lost({required this.onAgain, required this.onExit});

  @override
  Widget build(BuildContext context) => _Panel(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(
          Icons.landscape_outlined,
          color: Color(0xFFB8572A),
          size: 44,
        ),
        Text(
          'caravan.lost_title'.tr(),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.ink,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: onAgain,
          icon: const Icon(Icons.replay_rounded),
          label: Text('caravan.play_again'.tr()),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFB8572A),
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(48),
          ),
        ),
        TextButton(onPressed: onExit, child: Text('caravan.exit'.tr())),
      ],
    ),
  );
}
