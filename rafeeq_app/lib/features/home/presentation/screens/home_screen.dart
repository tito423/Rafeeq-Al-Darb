import 'dart:async';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hijri/hijri_calendar.dart';

import '../../../../core/models/prayer_times.dart';
import '../../../../core/services/prayer_times_service.dart';
import '../../../hadith_daily/presentation/daily_hadith_card.dart';
import '../../../khatma/presentation/khatma_card.dart';
import '../../../quran/presentation/widgets/continue_reading_card.dart';
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
    // P3‑22: ticks every second so the new prayer card's live HH:MM:SS clock
    // actually moves (was 30s, fine for the old static "متبقي" text but not
    // for a real ticking clock).
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
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
              // P3‑4: split out of KhatmaCard's own "اقرأ اليوم" nudge —
              // the reference shows a "متابعة القراءة" bookmark-style card
              // ("where you left off") as its own thing, separate from the
              // khatma daily-goal card below it. Renders nothing when
              // there's no real last-read page yet (see its own doc).
              const ContinueReadingCard(),
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

/// One colour per prayer, matching `design_refs/old_app_frames`' chip
/// palette (green/blue/brown/purple…) — cosmetic only, doesn't encode
/// anything.
const _prayerChipColors = {
  'fajr': Color(0xFF7C4DFF), // violet
  'sunrise': Color(0xFF8D6E63), // brown
  'dhuhr': Color(0xFF2F80A9), // blue
  'asr': Color(0xFF2E9D6F), // green
  'maghrib': Color(0xFFD4AF37), // gold
  'isha': Color(0xFF15C7B0), // teal
};

/// P3‑4/P3‑22: the animated, interactive prayer card — rebuilt to match a
/// video the owner sent of an earlier working build of this same app
/// (`design_refs/old_app_video.mp4`, frames in `old_app_frames/`), which
/// turned out to be a much more precise target than the static
/// `ref_home.jpg` mock: a live ticking `HH:MM:SS` clock, a "next prayer +
/// countdown" pill, a real location line, and coloured per-prayer chips
/// with a badge on the next one.
class _PrayerTimesTable extends StatelessWidget {
  final PrayerTimes times;
  const _PrayerTimesTable({required this.times});

  String _clockDigits(String localeCode) {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final s = '${two(now.hour)}:${two(now.minute)}:${two(now.second)}';
    if (localeCode != 'ar') return s;
    const west = '0123456789';
    const east = '٠١٢٣٤٥٦٧٨٩';
    final b = StringBuffer();
    for (final ch in s.split('')) {
      final i = west.indexOf(ch);
      b.write(i >= 0 ? east[i] : ch);
    }
    return b.toString();
  }

  @override
  Widget build(BuildContext context) {
    final next = PrayerTimesService().nextPrayer(times, DateTime.now());
    final location = [times.cityName, times.countryName]
        .where((s) => s.isNotEmpty)
        .join('، ');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        // P3‑4: "RGB في جميع الثيمات" — same fixed dark/teal/violet gradient
        // as the Home header card, so this reads as one visual family
        // regardless of the app's selected theme.
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0B0F1A), Color(0xFF102A3A), Color(0xFF1B1533)],
        ),
        border: Border.all(color: const Color(0xFF15C7B0).withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          Text(
            _clockDigits(context.locale.languageCode),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 40,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          if (next != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  Text.rich(
                    TextSpan(
                      text: '${'home.next_prayer'.tr()}: ',
                      style: const TextStyle(color: Colors.white70),
                      children: [
                        TextSpan(
                          text: _prayerLabelKeys[next.$1]!.tr(),
                          style: TextStyle(
                            color: _prayerChipColors[next.$1],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(_remaining(next),
                      style: const TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),
          ],
          if (location.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.location_on, size: 14, color: Colors.white54),
                const SizedBox(width: 4),
                Text(location, style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ],
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            reverse: Directionality.of(context) == TextDirection.rtl,
            child: Row(
              children: [
                for (final key in _prayerOrder)
                  _PrayerChip(
                    label: _prayerLabelKeys[key]!.tr(),
                    time: times.byName(key),
                    color: _prayerChipColors[key]!,
                    isNext: next?.$1 == key,
                  ),
              ],
            ),
          ),
        ],
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

class _PrayerChip extends StatelessWidget {
  final String label;
  final String time;
  final Color color;
  final bool isNext;
  const _PrayerChip({
    required this.label,
    required this.time,
    required this.color,
    required this.isNext,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 84,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isNext ? color : color.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(14),
          boxShadow: isNext
              ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 10)]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isNext ? Colors.white : color,
                )),
            const SizedBox(height: 4),
            Text(time,
                style: TextStyle(
                  fontSize: 13,
                  color: isNext ? Colors.white : Colors.white70,
                )),
            if (isNext) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('home.upcoming'.tr(),
                    style: const TextStyle(fontSize: 9, color: Colors.white)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

