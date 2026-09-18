import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/library/data/tts/book_voice_pref.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('the enhanced voice is the default; the phone voice is a kept choice',
      () async {
    SharedPreferences.setMockInitialValues({});
    expect(await BookVoicePref.load(), BookVoice.open);
    await BookVoicePref.save(BookVoice.device);
    expect(await BookVoicePref.load(), BookVoice.device);
    await BookVoicePref.save(BookVoice.open);
    expect(await BookVoicePref.load(), BookVoice.open);
  });
}
