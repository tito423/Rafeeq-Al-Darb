import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/islamic_pattern.dart';
import '../../../../core/utils/arabic_normalize.dart';
import '../../../../core/utils/byte_formatter.dart';
import '../../../quran/data/mushaf_data_provider.dart';
import '../../data/mp3quran_api.dart';
import '../../data/quran_audio_library.dart';
import '../../data/quran_audio_player.dart';

bool isArabicScript(String locale) => locale == 'ar' || locale == 'ur';

/// The surah's name from the app's own Qur'an database — not the audio
/// host's — so it is spelled the way the rest of the app spells it.
String surahTitle(MushafData? data, int surah, String locale) {
  final s = data?.surahs.where((x) => x.id == surah).firstOrNull;
  if (s == null) return 'quran_audio.surah_number'.tr(args: ['$surah']);
  return isArabicScript(locale) ? surahNameForDisplay(s.nameAr) : s.nameEn;
}

String trackIdFor(int moshafId, int surah) => 'm$moshafId-s$surah';

/// A recitation's surahs as a queue: the file where it is downloaded, the
/// stream where it is not, so «تشغيل الكل» never waits for a download.
List<PlayerTrack> recitationTracks({
  required String reciterName,
  required Mp3Moshaf moshaf,
  required MushafData? data,
  required String locale,
  bool downloadedOnly = false,
}) {
  final lib = QuranAudioLibrary.instance;
  return [
    for (final s in moshaf.surahs)
      if (!downloadedOnly || lib.isDownloaded(moshaf.id, s))
        PlayerTrack(
          id: trackIdFor(moshaf.id, s),
          title: surahTitle(data, s, locale),
          artist: reciterName,
          album: moshaf.name,
          url: moshaf.urlFor(s),
          filePath: lib.isDownloaded(moshaf.id, s)
              ? lib.fileFor(moshaf.id, s).path
              : null,
        ),
  ];
}

String formatClock(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(h > 0 ? 2 : 1, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return ltr(h > 0 ? '$h:$m:$s' : '$m:$s');
}

/// A reciter's monogram on a gold disc — the one image every reciter has.
class ReciterAvatar extends StatelessWidget {
  final String name;
  final double size;
  const ReciterAvatar({super.key, required this.name, this.size = 44});

  @override
  Widget build(BuildContext context) {
    final letter = name.trim().isEmpty ? '•' : name.trim().characters.first;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.goldSoft, AppColors.gold, AppColors.goldContainer],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.25),
            blurRadius: size * 0.25,
          ),
        ],
      ),
      child: Text(
        letter,
        style: TextStyle(
          fontSize: size * 0.45,
          fontWeight: FontWeight.w800,
          color: AppColors.night,
          height: 1.1,
        ),
      ),
    );
  }
}

/// The player's artwork, drawn from what is playing — «غيّر صورة حرف الأ
/// ديناميكيًا لاسم القارئ واسم السورة بشكل جميل بصريًا».
///
/// No reciter has a photograph the app could honestly use, and a monogram
/// said nothing. So the cover is typeset: the surah's name in the Qur'an's own
/// face, the reciter and the recitation under it, on a lattice in the app's
/// colours. The ground is picked from the reciter's name, so each reciter
/// keeps one colour and two reciters rarely share one.
class RecitationCover extends StatelessWidget {
  final String title;
  final String artist;
  final String? album;
  final double size;

  /// A small square for the mini player: the lattice and a sound mark only —
  /// there is no room for type that would still be legible.
  final bool compact;

  const RecitationCover({
    super.key,
    required this.title,
    required this.artist,
    this.album,
    required this.size,
    this.compact = false,
  });

  static const _grounds = <List<Color>>[
    [Color(0xFF0F3D33), Color(0xFF071625)],
    [Color(0xFF3A2F14), Color(0xFF0C2135)],
    [Color(0xFF12343B), Color(0xFF071625)],
    [Color(0xFF2B1D3F), Color(0xFF0C2135)],
    [Color(0xFF3B1E24), Color(0xFF071625)],
    [Color(0xFF1B3A22), Color(0xFF10293F)],
  ];

  @override
  Widget build(BuildContext context) {
    var h = 0;
    for (final c in artist.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    final ground = _grounds[h % _grounds.length];
    final radius = size * 0.12;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: ground,
        ),
        border: Border.all(
          color: AppColors.gold.withValues(alpha: compact ? 0.45 : 0.6),
          width: compact ? 1 : 1.4,
        ),
        boxShadow: compact
            ? null
            : [
                BoxShadow(
                  color: AppColors.gold.withValues(alpha: 0.18),
                  blurRadius: size * 0.12,
                  spreadRadius: 1,
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              painter: IslamicPatternPainter(
                tile: size / (compact ? 2 : 4),
                color: AppColors.gold.withValues(alpha: compact ? 0.16 : 0.09),
                strokeWidth: compact ? 0.8 : 1,
              ),
            ),
            if (compact)
              const Center(
                child: Icon(Icons.graphic_eq_rounded, color: AppColors.goldSoft),
              )
            else ...[
              Padding(
                padding: EdgeInsets.all(size * 0.055),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(radius * 0.7),
                    border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: size * 0.12,
                  vertical: size * 0.1,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.auto_awesome, size: size * 0.07, color: AppColors.gold),
                    SizedBox(height: size * 0.04),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          title,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          style: TextStyle(
                            fontFamily: 'AmiriQuran',
                            fontSize: size * 0.15,
                            height: 1.5,
                            color: AppColors.goldSoft,
                            shadows: const [
                              Shadow(color: Colors.black54, blurRadius: 12),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: size * 0.035),
                    Container(
                      width: size * 0.34,
                      height: 1.4,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(colors: [
                          Colors.transparent,
                          AppColors.gold,
                          Colors.transparent,
                        ]),
                      ),
                    ),
                    SizedBox(height: size * 0.04),
                    Text(
                      artist,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: size * 0.062,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textHigh,
                      ),
                    ),
                    if ((album ?? '').isNotEmpty) ...[
                      SizedBox(height: size * 0.02),
                      Text(
                        album!,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: size * 0.044,
                          color: AppColors.textMedium,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

Future<bool> confirmAction(BuildContext context, String message) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text('common.cancel'.tr()),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text('downloads.delete'.tr()),
        ),
      ],
    ),
  );
  return ok ?? false;
}

void showPlayFailed(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('quran_audio.play_failed'.tr())),
  );
}
