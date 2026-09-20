"""Emit test/basmala_split_test.dart with the REAL stored verse texts.

Typing the basmala by hand does not work: the stored text uses U+0671 alef
wasla and, in al-Tin and al-Qadr, an extra shadda, so a literal typed into a
source file silently fails to match. Every Arabic string below is escaped
codepoint by codepoint straight out of quran_local.db.
"""
import io
import os
import sqlite3

DB = os.path.join('rafeeq_app', 'assets', 'data', 'quran_local.db')
OUT = os.path.join('rafeeq_app', 'test', 'basmala_split_test.dart')

CASES = [
    (1, 1, 'al-Fatiha verse 1 IS the basmala and counts as a verse', False),
    (2, 1, 'al-Baqara opens with the basmala welded to the verse', True),
    (9, 1, 'at-Tawbah has no basmala at all', False),
    (27, 30, 'an-Naml 30 quotes the basmala INSIDE the verse', False),
    (95, 1, 'al-Tin writes the basmala with a shadda', True),
    (97, 1, 'al-Qadr writes the basmala with a shadda', True),
    (112, 1, 'al-Ikhlas, an ordinary short surah', True),
    (114, 1, 'an-Nas, the last surah', True),
]


def dart(s):
    q = chr(39)
    out = []
    for ch in s:
        o = ord(ch)
        if 32 <= o < 127 and ch not in (q, chr(92), '$'):
            out.append(ch)
        else:
            out.append(chr(92) + 'u{%X}' % o)
    return q + ''.join(out) + q


def main():
    c = sqlite3.connect(DB)
    rows = {}
    for s, a, _, _ in CASES:
        rows[(s, a)] = c.execute(
            'select text_uthmani from ayahs where surah_id=? and ayah_number=?',
            (s, a)).fetchone()[0]
    first = c.execute(
        'select surah_id, text_uthmani from ayahs where ayah_number=1'
        ' order by surah_id').fetchall()

    L = []
    w = L.append
    w("import 'package:flutter_test/flutter_test.dart';")
    w("import 'package:rafeeq_app/core/db/models.dart';")
    w("import 'package:rafeeq_app/features/quran/data/basmala.dart';")
    w('')
    w('// GENERATED beside the real quran_local.db: every Arabic literal here')
    w('// is the database\\u{2019}s own bytes, escaped codepoint by codepoint.')
    w('// Typing the basmala by hand does not match - the stored text uses')
    w('// U+0671 alef wasla, and al-Tin and al-Qadr add a shadda.')
    w('')
    w('Ayah _ayah(int surah, int number, String text) => Ayah(')
    w('      id: surah * 1000 + number,')
    w('      surahId: surah,')
    w('      ayahNumber: number,')
    w('      textUthmani: text,')
    w('      pageNumber: 1,')
    w('      juzNumber: 1,')
    w('    );')
    w('')
    w('void main() {')
    w("  group('basmala split', () {")
    for s, a, why, has in CASES:
        t = rows[(s, a)]
        w('    test(%s, () {' % dart('%d:%d - %s' % (s, a, why)))
        w('      final a = _ayah(%d, %d, %s);' % (s, a, dart(t)))
        if has:
            w('      expect(basmalaOf(a), isNotNull);')
            w('      expect(bodyOf(a), isNot(a.textUthmani));')
            w('      expect(bodyOf(a), isNotEmpty);')
            w("      expect('%s{basmalaOf(a)} %s{bodyOf(a)}', a.textUthmani);"
              % (chr(36), chr(36)))
        else:
            w('      expect(basmalaOf(a), isNull);')
            w('      expect(bodyOf(a), a.textUthmani);')
        w('    });')
        w('')
    w('    // The whole mushaf: exactly 112 surahs carry a welded basmala,')
    w('    // and every split puts the verse back together verbatim.')
    w("    test('all 114 opening verses', () {")
    w('      const texts = <int, String>{')
    for s, t in first:
        w('        %d: %s,' % (s, dart(t)))
    w('      };')
    w('      var withBasmala = 0;')
    w('      texts.forEach((surah, text) {')
    w('        final a = _ayah(surah, 1, text);')
    w('        final b = basmalaOf(a);')
    w('        if (b == null) {')
    w('          expect(bodyOf(a), text);')
    w('          return;')
    w('        }')
    w('        withBasmala++;')
    w("        expect('%sb %s{bodyOf(a)}', text);" % (chr(36), chr(36)))
    w('        expect(bodyOf(a), isNotEmpty);')
    w('      });')
    w('      expect(withBasmala, 112);')
    w('      expect(basmalaOf(_ayah(1, 1, texts[1]!)), isNull);')
    w('      expect(basmalaOf(_ayah(9, 1, texts[9]!)), isNull);')
    w('    });')
    w('  });')
    w('}')
    io.open(OUT, 'w', encoding='utf-8', newline='\n').write('\n'.join(L) + '\n')
    print('wrote', OUT, len(L), 'lines')


main()
