import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

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
class AdhkarListenHubScreen extends StatelessWidget {
  const AdhkarListenHubScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('home.ql_azkar_listen'.tr())),
    body: ListView(children: const [AdhkarListenRow()]),
  );
}
