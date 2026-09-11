import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
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
