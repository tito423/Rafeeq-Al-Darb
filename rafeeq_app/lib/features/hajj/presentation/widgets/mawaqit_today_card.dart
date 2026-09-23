/// «المواقيت اليوم» under the miqat steps of the Hajj and Umrah guide.
///
/// «الميقات في الحج والعمرة اسماءهم اتغيرت من زمن النووي لزمانا» (the owner,
/// 2026-09-23). The step's own text above is left as its book writes it;
/// this card adds what a pilgrim needs today — the name each miqat goes by now and
/// where people actually enter ihram — in the words of the Saudi Ministry of
/// Hajj and Umrah, read from its own page (`assets/data/mawaqit_today.json`,
/// which records the URL and the date it was read). A miqat the ministry
/// gives no modern name for (Dhat Irq) is shown without one.
library;

import 'dart:convert';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/digits.dart';
import '../../../../core/widgets/arabic_text.dart';

/// The steps this card belongs under.
const mawaqitStepKeys = {'mawaqit', 'umrah_miqaat'};

class MiqatToday {
  final String name;
  final String? today;
  final String text;
  const MiqatToday({required this.name, required this.today, required this.text});

  static MiqatToday fromJson(Map<String, dynamic> j) => MiqatToday(
        name: j['name'] as String,
        today: j['today'] as String?,
        text: j['text'] as String,
      );
}

class MawaqitToday {
  final String sourceName;
  final String sourceUrl;
  final List<MiqatToday> mawaqit;
  const MawaqitToday(this.sourceName, this.sourceUrl, this.mawaqit);

  static MawaqitToday parse(String raw) {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    final src = j['source'] as Map<String, dynamic>;
    return MawaqitToday(
      src['name'] as String,
      src['url'] as String,
      [
        for (final m in j['mawaqit'] as List)
          MiqatToday.fromJson(m as Map<String, dynamic>),
      ],
    );
  }
}

Future<MawaqitToday>? _cache;
Future<MawaqitToday> loadMawaqitToday() => _cache ??= rootBundle
    .loadString('assets/data/mawaqit_today.json')
    .then(MawaqitToday.parse);

class MawaqitTodayCard extends StatelessWidget {
  final double scale;
  const MawaqitTodayCard({super.key, this.scale = 1});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FutureBuilder<MawaqitToday>(
      future: loadMawaqitToday(),
      builder: (context, snap) {
        final data = snap.data;
        if (data == null) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.gold.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.place_outlined, color: AppColors.gold),
                  const SizedBox(width: 6),
                  Text(
                    'hajj.mawaqit_today_title'.tr(),
                    style: TextStyle(
                      fontSize: 16 * scale,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'hajj.mawaqit_today_note'.tr(),
                style: TextStyle(
                  fontSize: 12.5 * scale,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              for (final m in data.mawaqit) ...[
                const Divider(height: 18),
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ArabicText(
                      m.name,
                      style: TextStyle(
                        fontSize: 15 * scale,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (m.today != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.gold.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'hajj.mawaqit_today_name'.tr(args: [m.today!]),
                          style: TextStyle(
                            fontSize: 12.5 * scale,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                ArabicText(
                  localizeDigits(m.text, 'ar'),
                  style: TextStyle(fontSize: 14 * scale, height: 1.7),
                ),
              ],
              // No citation line under the card (the owner, 2026-09-23): the
              // note above names the ministry, and the Sources screen links it.
            ],
          ),
        );
      },
    );
  }
}
