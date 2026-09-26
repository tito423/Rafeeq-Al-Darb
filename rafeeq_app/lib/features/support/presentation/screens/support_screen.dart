import '../../../../core/widgets/readable_insets.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../app/rafeeq_app.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/external_link.dart';
import '../../../../core/widgets/fitted_sheet.dart';

/// «شاشة الدونيشن … بأسلوب راقي في الحديث وإظهار ليه سبب طلب الدونيشن».
///
/// The rules this screen was written under, and they are the owner's:
///
///   * **It asks once.** [supportShownProvider] remembers that it has been
///     seen, and after that the only way back is the card in «المزيد». No
///     pop-ups, no reminders, no badge.
///   * **It never appears over worship.** It is shown from the More tab's
///     first frame, not from the mushaf, not from the adhan, not from the
///     adhkar.
///   * **It says why.** The app has no ads and no tracking — that is a
///     deliberate refusal, and it costs storage and bandwidth every month.
///     Naming the reason is the difference between asking and begging.
///   * **It promises what stays free.** The Qur'an, the prayer times, the
///     adhkar, the hadith and the lessons are the app; they are not a tier.
///
/// The button appears only when [AppConfig.supportUrl] is set. A support
/// button that opens nothing is a dead control, and this project has shipped
/// one of those before.
class SupportScreen extends ConsumerWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final gold = goldOn(scheme);

    return Scaffold(
      appBar: AppBar(title: Text('support.title'.tr())),
      body: ListView(
        padding: readableInsets(context, const EdgeInsets.fromLTRB(20, 8, 20, 32)),
        children: [
          Icon(Icons.volunteer_activism_outlined, size: 56, color: gold),
          const SizedBox(height: 18),
          Text(
            'support.headline'.tr(),
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'support.why'.tr(),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.9),
          ),
          const SizedBox(height: 22),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'support.free_forever_title'.tr(),
                    style: theme.textTheme.titleSmall
                        ?.copyWith(color: gold, height: 1.6),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'support.free_forever'.tr(),
                    style: theme.textTheme.bodySmall?.copyWith(height: 1.9),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          if (AppConfig.supportUrl.isNotEmpty) ...[
            FilledButton.icon(
              onPressed: () => openLink(AppConfig.supportUrl, inApp: true),
              icon: const Icon(Icons.favorite_outline),
              label: Text('support.action'.tr()),
            ),
            const SizedBox(height: 8),
            // «المستخدم يحط القيمة اللي عايز يحطها، إحنا مش هنفرض عليه».
            Text(
              'support.any_amount'.tr(),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: goldText(context),
                height: 1.8,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Text(
            'support.no_obligation'.tr(),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.8,
            ),
          ),
        ],
      ),
    );
  }
}

/// Whether the one-time introduction has been shown.
///
/// Write-once, and never shown to the reader as a setting: «تظهر مرة واحدة في
/// الأول». A reader who dismisses it has answered, and the answer is kept.
class SupportShown extends StateNotifier<bool> {
  SupportShown(this._prefs) : super(_prefs.getBool(_key) ?? false);

  final SharedPreferences _prefs;
  static const _key = 'support_intro_shown_v1';

  Future<void> markShown() async {
    if (state) return;
    state = true;
    await _prefs.setBool(_key, true);
  }
}

final supportShownProvider =
    StateNotifierProvider<SupportShown, bool>((ref) {
  return SupportShown(ref.watch(sharedPrefsProvider));
});

/// The one-time sheet. Returns once it has been dismissed.
///
/// A sheet rather than a pushed screen on purpose: it can be swiped away
/// without deciding anything, which is the right weight for a request nobody
/// has to answer.
Future<void> showSupportIntro(BuildContext context, WidgetRef ref) async {
  if (ref.read(supportShownProvider)) return;
  await ref.read(supportShownProvider.notifier).markShown();
  if (!context.mounted) return;

  final theme = Theme.of(context);
  final gold = goldOn(theme.colorScheme);
  await showFittedSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheet) => Padding(
      padding: const EdgeInsets.fromLTRB(22, 4, 22, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.volunteer_activism_outlined, size: 44, color: gold),
          const SizedBox(height: 14),
          Text(
            'support.headline'.tr(),
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700, height: 1.6),
          ),
          const SizedBox(height: 12),
          Text(
            'support.intro_short'.tr(),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.9),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.of(sheet).pop(),
                  child: Text('support.later'.tr()),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(sheet).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const SupportScreen(),
                      ),
                    );
                  },
                  child: Text('support.read_more'.tr()),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
