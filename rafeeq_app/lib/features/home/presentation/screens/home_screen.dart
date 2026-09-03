import 'dart:async';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hijri/hijri_calendar.dart';

import '../../../../core/models/prayer_times.dart';
import '../../../../core/services/prayer_times_service.dart';
import '../../../hadith_daily/presentation/daily_hadith_card.dart';
import '../../../khatma/presentation/khatma_card.dart';
import '../../../sunan_suwar/presentation/sunan_suwar_card.dart';
import '../../data/prayer_controller.dart';

const _prayerOrder = ['fajr', 'sunrise', 'dhuhr', 'asr', 'maghrib', 'isha'];
const _prayerLabelKeys = {
  'fajr': 'prayer.fajr',
  'sunrise': 'prayer.sunrise',
  'dhuhr': 'prayer.dhuhr',
  'asr': 'prayer.asr',
  'maghrib': 'prayer.maghrib',
  'isha': 'prayer.isha',
};

/// Home tab — real prayer times (once location is granted) + quick access.
class HomeScreen extends ConsumerStatefulWidget {
  /// [onNavigate] is the shell tab index (1=quran, 2=azkar, 3=hadith, 4=settings).
  final void Function(int tab) onNavigate;

  const HomeScreen({super.key, required this.onNavigate});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(prayerControllerProvider.notifier).refresh());
    _clock = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prayerState = ref.watch(prayerControllerProvider);

    return HomeNavigate(
      onNavigate: widget.onNavigate,
      child: Scaffold(
      // P3‑4: the old AppBar just repeated "app.name" as a plain title —
      // dropped in favour of the header card below carrying the app's
      // identity through its own presence, freeing a full row of vertical
      // space for content.
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(prayerControllerProvider.notifier).refresh(),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const SizedBox(height: 4),
              const _HeaderCard(),
              const SizedBox(height: 16),
              _PrayerCard(state: prayerState),
              const SizedBox(height: 16),
              const KhatmaCard(),
              const SizedBox(height: 16),
              const SunanSuwarCard(),
              const SizedBox(height: 16),
              const DailyHadithCard(),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

/// P3‑4: replaces the old "رفيق الدرب" title + time-of-day greeting with a
/// single fixed card — same look in every app theme (a static version of
/// the RGB theme's own teal/violet/gold palette, `rgb_backdrop.dart`), the
/// Hijri date at the row's start, a centred welcome, the Gregorian date at
/// the end. "Start"/"end" (not literal left/right) so this reads correctly
/// mirrored in both RTL and LTR locales without special-casing either.
///
/// The welcome text is honestly generic ("مرحبا بك") rather than a fake
/// name — P3‑5 (login, answered: optional) hasn't been built yet, so there
/// is no real username to show for a guest session. Once accounts exist,
/// swap this for the signed-in user's real name; do **not** invent one in
/// the meantime — that would be exactly the kind of placeholder data rule
/// 1 forbids.
class _HeaderCard extends StatelessWidget {
  const _HeaderCard();

  String _hijriLine(String localeCode) {
    final lang = localeCode == 'ar' ? 'ar' : 'en';
    HijriCalendar.setLocal(lang);
    final h = HijriCalendar.now();
    const monthsAr = [
      '', 'محرم', 'صفر', 'ربيع الأول', 'ربيع الآخر', 'جمادى الأولى',
      'جمادى الآخرة', 'رجب', 'شعبان', 'رمضان', 'شوال', 'ذو القعدة', 'ذو الحجة',
    ];
    const monthsEn = [
      '', 'Muharram', 'Safar', 'Rabiʿ al-Awwal', 'Rabiʿ al-Akhir',
      'Jumada al-Awwal', 'Jumada al-Akhira', 'Rajab', 'Shaʿban', 'Ramadan',
      'Shawwal', 'Dhu al-Qaʿda', 'Dhu al-Hijja',
    ];
    final months = lang == 'ar' ? monthsAr : monthsEn;
    final suffix = lang == 'ar' ? ' هـ' : ' AH';
    return '${h.hDay} ${months[h.hMonth]} ${h.hYear}$suffix';
  }

  String _gregorianLine(BuildContext context) {
    final now = DateTime.now();
    return DateFormat.yMMMd(context.locale.toString()).format(now);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0B0F1A), Color(0xFF102A3A), Color(0xFF1B1533)],
        ),
        border: Border.all(color: const Color(0xFF15C7B0).withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD4AF37).withValues(alpha: 0.12),
            blurRadius: 22,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        children: [
          Text(_hijriLine(context.locale.languageCode),
              style: const TextStyle(
                  color: Color(0xFF7DEBDA), fontSize: 12, fontWeight: FontWeight.w600)),
          Expanded(
            child: Text(
              'home.welcome_guest'.tr(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'AmiriQuran',
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(_gregorianLine(context),
              style: TextStyle(
                  color: const Color(0xFFD4AF37).withValues(alpha: 0.9),
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _PrayerCard extends StatelessWidget {
  final AsyncValue<PrayerTimesResult> state;
  const _PrayerCard({required this.state});

  @override
  Widget build(BuildContext context) {
    return state.when(
      loading: () => const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (e, _) => _MessageCard(
        icon: Icons.error_outline,
        message: 'errors.generic'.tr(),
      ),
      data: (result) {
        if (result.locationDenied) {
          return _MessageCard(
            icon: Icons.location_off_outlined,
            message: 'home.location_needed'.tr(),
          );
        }
        if (result.times.isEmpty) {
          return _MessageCard(
            icon: Icons.wifi_off,
            message: 'errors.offline'.tr(),
          );
        }
        return _PrayerTimesTable(times: result.times);
      },
    );
  }
}

class _MessageCard extends StatelessWidget {
  final IconData icon;
  final String message;
  const _MessageCard({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(icon, size: 32, color: scheme.onSurfaceVariant),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _PrayerTimesTable extends StatelessWidget {
  final PrayerTimes times;
  const _PrayerTimesTable({required this.times});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final next = PrayerTimesService().nextPrayer(times, DateTime.now());

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (next != null) ...[
              Text('home.next_prayer'.tr(),
                  style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
              const SizedBox(height: 4),
              Text(
                '${_prayerLabelKeys[next.$1]!.tr()} • ${times.byName(next.$1)}',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(color: scheme.primary, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(_remaining(next), style: TextStyle(color: scheme.onSurfaceVariant)),
              const Divider(height: 28),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final key in _prayerOrder)
                  Expanded(
                    child: Column(
                      children: [
                        Text(_prayerLabelKeys[key]!.tr(),
                            style: TextStyle(
                                fontSize: 11, color: scheme.onSurfaceVariant)),
                        const SizedBox(height: 4),
                        Text(
                          times.byName(key),
                          style: TextStyle(
                            fontWeight: next?.$1 == key ? FontWeight.bold : FontWeight.normal,
                            color: next?.$1 == key ? scheme.primary : null,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            if (times.hijriDate.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(times.hijriDate,
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
            ],
          ],
        ),
      ),
    );
  }

  String _remaining((String, DateTime) next) {
    final diff = next.$2.difference(DateTime.now());
    if (diff.isNegative) return '';
    final h = diff.inHours;
    final m = diff.inMinutes % 60;
    final label = 'home.remaining'.tr();
    if (h > 0) return '$label: $hس $mد';
    return '$label: $mد';
  }
}

