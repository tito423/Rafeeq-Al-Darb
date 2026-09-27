import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../dorar/presentation/dorar_hub_screen.dart';
import '../../../shamela/presentation/shamela_screen.dart';

/// «الدرر السنية» and «المكتبة الشاملة» as two named cards at the top of the
/// library. They were two bare icons in the app bar, and the owner: «الدرر
/// والشاملة ايقونات بس المستخدم مش هيعرف دول ايه» (2026-09-27). Each card
/// says what it is and what it gives, slides in when the library opens,
/// and carries a slow sheen so the eye finds it. GitHub build only (the
/// caller checks `kShamelaEnabled`).
class ExternalSourcesStrip extends StatelessWidget {
  const ExternalSourcesStrip({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
      child: Row(
        children: [
          Expanded(
            child: _SourceCard(
              delayMs: 0,
              icon: Icons.fact_check_outlined,
              title: 'dorar.hub_title'.tr(),
              subtitle: 'library.dorar_card_sub'.tr(),
              colors: const [Color(0xFF0F5E4A), Color(0xFF1C8A6C)],
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => const DorarHubScreen(),
              )),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _SourceCard(
              delayMs: 90,
              icon: Icons.travel_explore,
              title: 'shamela.title'.tr(),
              subtitle: 'library.shamela_card_sub'.tr(),
              colors: const [Color(0xFF6B4A12), Color(0xFFA77B26)],
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => const ShamelaScreen(),
              )),
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceCard extends StatefulWidget {
  const _SourceCard({
    required this.delayMs,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.colors,
    required this.onTap,
  });

  final int delayMs;
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> colors;
  final VoidCallback onTap;

  @override
  State<_SourceCard> createState() => _SourceCardState();
}

class _SourceCardState extends State<_SourceCard>
    with TickerProviderStateMixin {
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );
  late final AnimationController _sheen = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4200),
  );
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: 120 + widget.delayMs), () {
      if (!mounted) return;
      _enter.forward();
      _sheen.repeat();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _enter.value = 1;
      _sheen.stop();
    }
  }

  @override
  void dispose() {
    _enter.dispose();
    _sheen.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enter = CurvedAnimation(parent: _enter, curve: Curves.easeOutBack);
    return AnimatedBuilder(
      animation: Listenable.merge([_enter, _sheen]),
      builder: (context, _) {
        final t = enter.value.clamp(0.0, 1.0);
        // The sheen crosses the card in the first third of each cycle and
        // rests for the other two.
        final s = (_sheen.value * 3).clamp(0.0, 1.0);
        return Opacity(
          opacity: _enter.value,
          child: Transform.translate(
            offset: Offset(0, 16 * (1 - t)),
            child: AnimatedScale(
              scale: _pressed ? 0.96 : 1,
              duration: const Duration(milliseconds: 120),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(18),
                clipBehavior: Clip.antiAlias,
                child: Ink(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: AlignmentDirectional.topStart,
                      end: AlignmentDirectional.bottomEnd,
                      colors: widget.colors,
                    ),
                  ),
                  child: InkWell(
                    onTap: widget.onTap,
                    onHighlightChanged: (v) => setState(() => _pressed = v),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment(-1.6 + 3.2 * s, -1),
                                  end: Alignment(-0.6 + 3.2 * s, 1),
                                  colors: [
                                    Colors.white.withValues(alpha: 0),
                                    Colors.white.withValues(alpha: 0.16),
                                    Colors.white.withValues(alpha: 0),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.18),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(widget.icon,
                                    color: Colors.white, size: 21),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      widget.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14.5,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      widget.subtitle,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.white
                                            .withValues(alpha: 0.88),
                                        fontSize: 11.5,
                                        height: 1.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
