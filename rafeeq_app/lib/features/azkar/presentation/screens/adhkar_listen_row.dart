import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/utils/digits.dart';
import '../../data/adhkar_recitations.dart';
import 'adhkar_listen_screen.dart';

/// The two «استمع» cards (morning / evening). Shown at the top of the adhkar
/// screen and as the whole of [AdhkarListenHubScreen], which the Home
/// quick-access card opens (owner, 2026-10-03).
class AdhkarListenRow extends StatelessWidget {
  const AdhkarListenRow({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
    child: Row(
      children: [
        Expanded(
          child: _ListenCard(
            time: AdhkarTime.morning,
            icon: Icons.wb_sunny_rounded,
            colors: const [Color(0xFFF7B733), Color(0xFFD35400)],
            label: 'azkar.listen_morning'.tr(),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ListenCard(
            time: AdhkarTime.evening,
            icon: Icons.nights_stay_rounded,
            colors: const [Color(0xFF3A4F9C), Color(0xFF1E2A5A)],
            label: 'azkar.listen_evening'.tr(),
          ),
        ),
      ],
    ),
  );
}

class _ListenCard extends StatelessWidget {
  final AdhkarTime time;
  final IconData icon;
  final List<Color> colors;
  final String label;
  const _ListenCard({
    required this.time,
    required this.icon,
    required this.colors,
    required this.label,
  });

  @override
  Widget build(BuildContext context) => Material(
    borderRadius: BorderRadius.circular(18),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => AdhkarListenScreen(time: time)),
      ),
      child: Ink(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 26),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                maxLines: 2,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
            const Icon(Icons.headphones_rounded, color: Colors.white, size: 20),
          ],
        ),
      ),
    ),
  );
}

/// «استمع إلى الأذكار» from Home: the morning and the evening, nothing else.
///
/// Two small buttons on an empty screen was «الشاشة فاضية … واخد يا دوبك
/// أول حاجة منها من فوق» (owner, 2026-10-08). Each is now a tall card on
/// its own photograph - the Faisal Mosque at sunrise, minarets at sunset -
/// sharing the screen between them, with how many voices it holds.
class AdhkarListenHubScreen extends StatelessWidget {
  const AdhkarListenHubScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('home.ql_azkar_listen'.tr())),
    body: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          children: [
            for (final t in const [AdhkarTime.morning, AdhkarTime.evening]) ...[
              Expanded(child: _PhotoCard(time: t)),
              if (t == AdhkarTime.morning) const SizedBox(height: 14),
            ],
          ],
        ),
      ),
    ),
  );
}

class _PhotoCard extends StatelessWidget {
  final AdhkarTime time;
  const _PhotoCard({required this.time});

  @override
  Widget build(BuildContext context) {
    final evening = time == AdhkarTime.evening;
    final voices = adhkarRecitations.where((r) => r.fits(time)).length;
    return Material(
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      elevation: 3,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => AdhkarListenScreen(time: time),
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(adhkarListenBackground(time), fit: BoxFit.cover),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.05),
                    Colors.black.withValues(alpha: 0.65),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    evening
                        ? Icons.nights_stay_rounded
                        : Icons.wb_sunny_rounded,
                    color: const Color(0xFFFFE08A),
                    size: 34,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    (evening ? 'azkar.listen_evening' : 'azkar.listen_morning')
                        .tr(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      shadows: [Shadow(blurRadius: 8, color: Colors.black54)],
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(
                        Icons.headphones_rounded,
                        color: Colors.white70,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        trn(
                          'azkar.listen_voices',
                          namedArgs: {
                            'n': localizeDigits(
                              '$voices',
                              context.locale.languageCode,
                            ),
                          },
                        ),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
