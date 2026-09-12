import 'package:flutter/material.dart';

import '../../../app/navigation.dart';
import '../../quran_audio/presentation/quran_audio_screen.dart';
import '../../ruqyah/presentation/screens/ruqyah_audio_screen.dart';
import 'screens/downloads_screen.dart';

/// Where a tapped download notification lands.
///
/// «تحميل تلاوة يروح لتنزيل التلاوات، تحميل رقية يروح لتحميل الرقية، تحميل
/// مصحف يروح مباشرة لتحميل المصحف، وهكذا». Before this every download
/// notification did the same thing a tap on the launcher icon does — bring
/// the app forward on whatever screen it was last on — which for someone who
/// tapped «تنزيل التلاوة · ٢٢ من ٣٤٢» is indistinguishable from the tap doing
/// nothing.
///
/// Pushed onto the ROOT navigator, not a tab: these are screens, not tabs, and
/// the reader gets a back button to wherever they were.
Future<void> openDownloadFromPayload(String what) async {
  final navigator = rootNavigatorKey.currentState;
  if (navigator == null) return;

  final builder = switch (what) {
    'recitations' => (BuildContext _) => const QuranAudioScreen(),
    'ruqyah' => (BuildContext _) => const RuqyahAudioScreen(),
    // A mushaf's pages and a book's file both land on the Downloads hub: it
    // is the screen that lists what is on the device, per edition and per
    // book, with its size and a way to remove it.
    'mushaf' || 'files' => (BuildContext _) => const DownloadsScreen(),
    // An unknown payload from an older build still in AlarmManager. Bring the
    // app forward and leave it where it is rather than guessing a screen.
    _ => null,
  };
  if (builder == null) return;

  await navigator.push(MaterialPageRoute<void>(builder: builder));
}
