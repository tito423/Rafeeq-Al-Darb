"""Check that every quote in the kids-story narration docs is verbatim in the
app's own text.

For each row of docs/kids_stories/<id>_narration.md, every top-level «…»
quote in the source column is split on «…» ellipses and each piece must be
found character for character (tashkeel and punctuation kept; only the « »
marks, U+200F/U+200E and runs of whitespace are normalised) in:
  * quran_sciences.db  table tafseer_texts (every source: muyassar,
    ibn_kathir, sadi, qurtubi, tabari, baghawi, tantawi), or
  * hadith.db          table hadiths (arabic) - for rows that cite al-Bukhari.

Why (2026-10-01): the first drafts of 21 docs quoted al-Muyassar from another
copy (spa5k/tafsir_api) which differs from the app's quran_sciences.db in
tashkeel, punctuation and some words. Quotes must be the text the app shows.

    py -3 scripts/check_kids_narration_quotes.py                 (all docs)
    py -3 scripts/check_kids_narration_quotes.py ayyub kaaba     (some)
    --sciences <path> --hadith <path>   (defaults: rafeeq_app/assets/data/)

Exit code 1 if any segment is not found.
"""
import re
import sqlite3
import sys
import unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DOCS = ROOT / 'docs' / 'kids_stories'


def arg(name, default):
    return Path(sys.argv[sys.argv.index(name) + 1]) if name in sys.argv else default


def norm(x):
    x = unicodedata.normalize('NFC', x)
    for ch in '«»‏‎':
        x = x.replace(ch, '')
    return re.sub(r'\s+', ' ', x).strip()


def top_quotes(s):
    out, depth, cur = [], 0, ''
    for ch in s:
        if ch == '«':
            depth += 1
            if depth == 1:
                cur = ''
                continue
        elif ch == '»':
            depth -= 1
            if depth == 0:
                out.append(cur)
                continue
        if depth >= 1:
            cur += ch
    return out


def main():
    data = ROOT / 'rafeeq_app' / 'assets' / 'data'
    sciences = arg('--sciences', data / 'quran_sciences.db')
    hadith = arg('--hadith', data / 'hadith.db')
    tafsir = norm(' \n '.join(r[0] for r in sqlite3.connect(sciences).execute('select text from tafseer_texts')))
    hadiths = norm(' \n '.join(r[0] for r in sqlite3.connect(hadith).execute('select arabic from hadiths')))
    names = [a for a in sys.argv[1:] if not a.startswith('--') and not a.endswith('.db')]
    files = [DOCS / f'{n}_narration.md' for n in names] or sorted(DOCS.glob('*_narration.md'))
    total = missing = 0
    for f in files:
        for line in f.read_text(encoding='utf-8').splitlines():
            if not line.startswith('| ') or line.count('|') < 4:
                continue
            source = line.split('|')[3]
            for q in top_quotes(source):
                for seg in q.split('…'):
                    seg = norm(seg).strip(' /')
                    if not seg:
                        continue
                    total += 1
                    if seg in tafsir or ('البخاري' in source and seg in hadiths):
                        continue
                    missing += 1
                    print(f'{f.stem}: NOT FOUND: {seg}')
    print(f'{total} quoted segments, {missing} not verbatim in the app\'s text')
    sys.exit(1 if missing else 0)


if __name__ == '__main__':
    main()
