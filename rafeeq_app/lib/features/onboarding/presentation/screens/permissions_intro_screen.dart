import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/alarm_permissions_service.dart';
import '../../../../core/i18n/supported_locales.dart';
import '../../../../core/theme/app_colors.dart';

/// EVERY PERMISSION, ONCE, BEFORE ANYTHING ELSE — and told why first.
///
/// «عايزك في الاول الاسبلاش ثم كل الاذونات مباشرة مش تستنى لما اضغط حاجة
/// بعدين تظهر لا كلها ورا بعضها مباشرة والافضل تعرض صفحة بجميع الاذونات
/// ونبذه بسيط جدا ليه مطلوب الاذن».
///
/// They used to be asked from `AppShell`'s first frame - which on a first run
/// is after the whole of onboarding - so the system dialogs landed on top of
/// whatever the reader had started doing, one at a time, with nothing saying
/// what any of them was for. An earlier session had already moved them OFF
/// the splash for that same reason; the answer was never "later", it was
/// "explain them first".
///
/// This page explains, then `requestStartupGrants()` runs the whole sequence
/// back to back. Nothing here blocks: «لاحقًا» goes straight on, and every
/// one of these is optional - the app works without all of them, only less
/// well, which is what each line says.
class PermissionsIntroScreen extends ConsumerStatefulWidget {
  final VoidCallback onDone;
  const PermissionsIntroScreen({super.key, required this.onDone});

  @override
  ConsumerState<PermissionsIntroScreen> createState() =>
      _PermissionsIntroScreenState();
}

class _PermissionsIntroScreenState
    extends ConsumerState<PermissionsIntroScreen> {
  bool _busy = false;

  Future<void> _allow() async {
    if (_busy) return;
    setState(() => _busy = true);
    // One call, one sequence: location, notifications, exact alarms, audio.
    // Each request no-ops when it is already granted, so a reader who comes
    // back to this page is not asked twice.
    await AlarmPermissionsService.instance.requestStartupGrants();
    if (!mounted) return;
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const rows = <(IconData, String)>[
      (Icons.location_on_outlined, 'location'),
      (Icons.notifications_active_outlined, 'notifications'),
      (Icons.alarm_on_outlined, 'alarms'),
      (Icons.audiotrack_outlined, 'audio'),
      (Icons.battery_saver_outlined, 'battery'),
    ];

    return Scaffold(
      body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                child: Column(
                  children: [
                    Icon(Icons.verified_user_outlined,
                        size: 44, color: AppColors.gold),
                    const SizedBox(height: 12),
                    Text(
                      'permissions_intro.title'.tr(),
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'permissions_intro.subtitle'.tr(),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  children: [
                    // THE LANGUAGE COMES FIRST, on this page.
                    //
                    // It used to live on the onboarding screen, one step
                    // later - so the very first thing a first-run reader saw,
                    // this page, asked him for five permissions in whatever
                    // language his phone happened to be set to. Seen on
                    // emulator-5554: «Permissions the app needs» in English
                    // in front of an Arabic reader. Asking in a language
                    // someone may not read is worse than asking late.
                    Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.language,
                                    color: AppColors.gold, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'settings.language'.tr(),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final e in kLanguageNames.entries)
                                  ChoiceChip(
                                    label: Text(e.value),
                                    selected:
                                        context.locale.languageCode == e.key,
                                    onSelected: (_) {
                                      if (context.locale.languageCode !=
                                          e.key) {
                                        context.setLocale(Locale(e.key));
                                      }
                                    },
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    for (final (icon, key) in rows)
                      Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          leading: Icon(icon, color: AppColors.gold),
                          title: Text(
                            'permissions_intro.$key'.tr(),
                            style:
                                const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text('permissions_intro.${key}_why'.tr()),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.gold,
                          foregroundColor: AppColors.night,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: _busy ? null : _allow,
                        child: _busy
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.4),
                              )
                            : Text(
                                'permissions_intro.allow'.tr(),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 16),
                              ),
                      ),
                    ),
                    TextButton(
                      onPressed: _busy ? null : widget.onDone,
                      child: Text('permissions_intro.later'.tr()),
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
