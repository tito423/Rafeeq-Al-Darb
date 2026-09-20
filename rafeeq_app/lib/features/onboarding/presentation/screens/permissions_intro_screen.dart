import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/alarm_permissions_service.dart';
import '../../../../core/i18n/supported_locales.dart';
import '../../../../core/theme/app_colors.dart';
import 'onboarding_screen.dart';

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
  const PermissionsIntroScreen({super.key});

  @override
  ConsumerState<PermissionsIntroScreen> createState() =>
      _PermissionsIntroScreenState();
}

class _PermissionsIntroScreenState
    extends ConsumerState<PermissionsIntroScreen>
    with WidgetsBindingObserver {
  final _granted = <AppPermission, bool>{};
  AppPermission? _asking;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// The exact-alarm and battery prompts are full SETTINGS SCREENS on many
  /// phones, not dialogs, so the answer only exists once the app is resumed.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  /// ON TO THE APP. This page navigates ITSELF.
  ///
  /// 3.48.0 took an `onDone` callback built inside the SPLASH's
  /// `pushReplacement`, so the closure captured the splash state - which had
  /// already been replaced by the time anyone could press a button. Its own
  /// `if (!mounted) return` then swallowed every attempt in silence: «بضغط
  /// allow all او لاحقا برده الشاشة بتقف ومش بتفتح التكبيق». A screen that
  /// knows where it goes should use its own context to get there.
  void _continue() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const OnboardingScreen()),
    );
  }

  Future<void> _refresh() async {
    for (final which in AppPermission.values) {
      final ok = await AlarmPermissionsService.instance.isGranted(which);
      if (!mounted) return;
      setState(() => _granted[which] = ok);
    }
  }

  /// One row, one permission. NOTHING HERE BLOCKS THE PAGE.
  ///
  /// The first cut awaited the whole five-permission sequence and only then
  /// navigated, so «بعد اما اقبل اذنين الصفحة بالكامل بتعلق ومش بتدخلني ع
  /// التطبيق»: a request that opens a settings screen does not complete
  /// until the reader comes back, and the button had disabled itself and
  /// the page with it. Each row is asked on its own now, «لاحقًا» is never
  /// disabled, and a row being asked shows its own spinner rather than
  /// freezing the screen.
  Future<void> _ask(AppPermission which) async {
    if (_asking != null) return;
    setState(() => _asking = which);
    final ok = await AlarmPermissionsService.instance.request(which);
    if (!mounted) return;
    setState(() {
      _granted[which] = ok;
      _asking = null;
    });
  }

  Future<void> _askAll() async {
    for (final which in AppPermission.values) {
      if (_granted[which] == true) continue;
      await _ask(which);
      if (!mounted) return;
    }
    _continue();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const rows = <(IconData, String, AppPermission)>[
      (Icons.location_on_outlined, 'location', AppPermission.location),
      (
        Icons.notifications_active_outlined,
        'notifications',
        AppPermission.notifications
      ),
      (Icons.alarm_on_outlined, 'alarms', AppPermission.exactAlarms),
      (Icons.audiotrack_outlined, 'audio', AppPermission.audio),
      (Icons.battery_saver_outlined, 'battery', AppPermission.battery),
      (
        Icons.fullscreen_rounded,
        'full_screen',
        AppPermission.fullScreen
      ),
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
                    for (final (icon, key, which) in rows)
                      Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          onTap: _asking == null ? () => _ask(which) : null,
                          leading: Icon(icon, color: AppColors.gold),
                          title: Text(
                            'permissions_intro.$key'.tr(),
                            style:
                                const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text('permissions_intro.${key}_why'.tr()),
                          trailing: _asking == which
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2.2),
                                )
                              : Icon(
                                  _granted[which] == true
                                      ? Icons.check_circle_rounded
                                      : Icons.chevron_right_rounded,
                                  color: _granted[which] == true
                                      ? AppColors.primary
                                      : scheme.onSurfaceVariant,
                                ),
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
                        onPressed: _asking == null ? _askAll : null,
                        child: Text(
                          'permissions_intro.allow'.tr(),
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                      ),
                    ),
                    // NEVER disabled. Whatever a request does, the reader can
                    // always get into the app.
                    TextButton(
                      onPressed: _continue,
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
