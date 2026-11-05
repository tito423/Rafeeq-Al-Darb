import 'package:shared_preferences/shared_preferences.dart';

/// Which voice reads books aloud.
///
///  * [open] — the downloadable open voice, chosen for its tafkhim of the
///    divine name. Used only when its pack is installed; otherwise the
///    phone's voice reads, so the choice never leaves the reader silent.
///  * [device] — the phone's own engine (Google's when installed, see
///    `BookSpeaker`), taking its male Arabic voice (`pickArabicVoice`). The
///    DEFAULT since 2026-11-05 (owner: «جوجل اللي على الموبايل»): no
///    download, starts at once.
enum BookVoice { open, device }

class BookVoicePref {
  static const _key = 'book_voice';

  static Future<BookVoice> load() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_key) == BookVoice.open.name
        ? BookVoice.open
        : BookVoice.device;
  }

  static Future<void> save(BookVoice v) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, v.name);
  }
}
