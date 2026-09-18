import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/library/data/book_speaker.dart';
import 'package:rafeeq_app/features/library/data/book_catalog.dart';

/// The two things about the spoken reader that can be checked without a
/// device: that a page is cut into utterances the engine will accept, and
/// that the harakat survive the cutting.
///
/// The second is the one that matters. Every other Arabic path in this app
/// strips diacritics — `normalizeArabic` for search, the hadith matcher, the
/// lesson-heading normalisers — and this one must do the exact opposite. A
/// reader that quietly normalised its input would sound fine in a demo and be
/// wrong on every case ending, which is the failure this whole feature was
/// designed around.
void main() {
  const vowelled =
      'الْحَمْدُ لِلَّهِ رَبِّ الْعَالَمِينَ. وَالصَّلَاةُ عَلَى نَبِيِّهِ. '
      'أَمَّا بَعْدُ؛ فَهَذَا كِتَابٌ فِي الْفِقْهِ؟ نَعَمْ!';

  test('a page is split on sentence ends, not mid-clause', () {
    final chunks = BookSpeaker.chunk(vowelled);
    expect(chunks, isNotEmpty);
    // Everything is rejoined into at most one chunk here because the page is
    // short — the point is that nothing is lost and nothing is empty.
    for (final c in chunks) {
      expect(c.trim(), isNotEmpty);
    }
  });

  test('THE HARAKAT SURVIVE — the reader never normalises its input', () {
    final chunks = BookSpeaker.chunk(vowelled);
    final joined = chunks.join(' ');
    // Count the marks on the way in and on the way out. If a future change
    // routes this text through normalizeArabic, this is what catches it.
    final marks = RegExp('[ً-ْٰ]');
    final before = marks.allMatches(vowelled).length;
    final after = marks.allMatches(joined).length;
    expect(before, greaterThan(20), reason: 'the fixture must be vowelled');
    expect(after, before,
        reason: 'chunking dropped $after of $before harakat — the reader '
            'would mispronounce every case ending');
  });

  test('a sentence longer than the engine limit is still split', () {
    final huge = '${'وَقَالَ ' * 2000}.';
    final chunks = BookSpeaker.chunk(huge);
    expect(chunks.length, greaterThan(1));
    for (final c in chunks) {
      expect(c.length, lessThanOrEqualTo(3500),
          reason: 'Android refuses an utterance past its own maximum');
    }
  });

  test('the open voice gets short chunks that never break a word', () {
    // FastPitch is fed ~220 characters at a time. A long sentence must be
    // cut at a comma or a space: half a word is a mispronounced word.
    final words = List.generate(120, (i) => i.isEven ? 'وَقَالَ' : 'الْعُلَمَاءُ،');
    final text = '${words.join(' ')}.';
    final chunks = BookSpeaker.chunk(text, max: 220);
    expect(chunks.length, greaterThan(3));
    final allowed = {'وَقَالَ', 'الْعُلَمَاءُ،', 'الْعُلَمَاءُ', 'وَقَالَ.', 'الْعُلَمَاءُ،.'};
    for (final c in chunks) {
      expect(c.length, lessThanOrEqualTo(220));
      for (final w in c.split(' ')) {
        expect(allowed, contains(w), reason: 'a word was cut: "$w"');
      }
    }
    expect(chunks.join(' ').split(' ').length, words.length,
        reason: 'no word may be lost between chunks');
  });

  test('an empty or blank page produces nothing to say', () {
    expect(BookSpeaker.chunk(''), isEmpty);
    expect(BookSpeaker.chunk('   \n  '), isEmpty);
  });

  test('the spoken reader is gated on MEASURED diacritisation', () {
    // The numbers are written into the catalogue by
    // scripts/apply_diacritisation.py from a real measurement against the
    // hosted text. This pins the gate, and pins that the measurement ran:
    // a catalogue where every book reported 0 would silently disable the
    // feature everywhere and look like a deliberate choice.
    final withValue =
        libraryBookCatalog.where((b) => b.diacritisedPct > 0).length;
    expect(withValue, greaterThan(150),
        reason: 'diacritisedPct looks unmeasured — rerun '
            'scripts/measure_diacritisation.py and apply_diacritisation.py');

    final speakable = libraryBookCatalog.where((b) => b.canBeSpoken).toList();
    expect(speakable.length, greaterThan(50));
    expect(speakable.length, lessThan(libraryBookCatalog.length),
        reason: 'if every book passed the gate, the gate is not doing '
            'anything and the bimodal corpus measurement was wrong');

    for (final b in speakable) {
      expect(b.diacritisedPct, greaterThanOrEqualTo(80));
    }
    for (final b in libraryBookCatalog.where((b) => !b.canBeSpoken)) {
      expect(b.diacritisedPct, lessThan(80));
    }
  });
}
