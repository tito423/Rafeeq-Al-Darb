import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/library/data/book_speaker.dart';

/// «عاوزه رجل مش أنثى». The list below is the one Google's engine returned on
/// emulator-5554 (2026-09-18), IN ITS ORDER — which puts the female `arz`
/// first, and is exactly why "first local voice" read books in a woman's
/// voice. Pitch measured on the host: ard 135.6 Hz, are 144.6 Hz (male);
/// arz 206.9 Hz, arc 235.3 Hz (female).
void main() {
  Map<String, String> v(String name) => {'name': name, 'locale': 'ar'};
  final google = [
    v('ar-xa-x-arz-local'),
    v('ar-xa-x-ard-local'),
    v('ar-xa-x-arc-network'),
    v('ar-xa-x-are-local'),
    v('ar-xa-x-ard-network'),
    v('ar-xa-x-arz-network'),
    v('ar-xa-x-arc-local'),
    v('ar-language'),
    v('ar-xa-x-are-network'),
  ];

  test('Google\'s list gives the male voice on the device', () {
    expect(pickArabicVoice(google)['name'], 'ar-xa-x-ard-local');
  });

  test('the other male voice when the first is missing', () {
    final l = google.where((x) => !x['name']!.startsWith('ar-xa-x-ard')).toList();
    expect(pickArabicVoice(l)['name'], 'ar-xa-x-are-local');
  });

  test('a male network voice beats a female local one', () {
    final l = [v('ar-xa-x-arz-local'), v('ar-xa-x-ard-network')];
    expect(pickArabicVoice(l)['name'], 'ar-xa-x-ard-network');
  });

  test('an engine that names its voices by sex', () {
    final l = [v('ar-SA-female-1'), v('ar-SA-male-1')];
    expect(pickArabicVoice(l)['name'], 'ar-SA-male-1');
  });

  test('an engine with no male voice still reads', () {
    final l = [v('ar-xa-x-arz-network'), v('ar-xa-x-arz-local')];
    expect(pickArabicVoice(l)['name'], 'ar-xa-x-arz-local');
  });
}
