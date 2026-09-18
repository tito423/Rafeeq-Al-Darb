import 'package:shared_preferences/shared_preferences.dart';

/// Which voice reads books aloud.
///
///  * [open] — the downloadable open voice, chosen for its tafkhim of the
///    divine name. Used only when its pack is installed; otherwise the
///    phone's voice reads, so the choice never leaves the reader silent.
///  * [device] — the phone's own engine, taking its male Arabic voice
///    (`pickArabicVoice`). The owner asked for it to stay available as a
///    deliberate choice, not only as a fallback: it needs no 252 MB download
///    and starts at once.
enum BookVoice { open, device }

class BookVoicePref {
  static const _key = 'book_voice';

  static Future<BookVoice> load() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_key) == BookVoice.device.name
        ? BookVoice.device
        : BookVoice.open;
  }

  static Future<void> save(BookVoice v) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, v.name);
  }
}
