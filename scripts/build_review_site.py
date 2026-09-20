"""Build «مراجعة محتوى رفيق الدرب» - a static site for a scholar to review
every religious text the app ships, on his phone.

    cd rafeeq_app && flutter test --tags export --run-skipped test/export_review_texts_test.dart
    py -3 scripts/build_review_site.py

Writes ../rafeeq-review/ (its own git repo, published with GitHub Pages).
Everything is read from what the app really ships - the bundled databases,
the bundled books cut by the app's own code, the Arabic locale file - never
retyped. Stage 1: adhkar, quotes, app texts, Hajj, tajweed, sources.
Stage 2: the nine hadith books, every hadith with the grade and the GRADER
the app shows beside it.

Stage 2 is split by chapter and not dumped whole. The corpus is 36.2 million
characters - roughly 69 MB of UTF-8 - and Musnad Ahmad alone is 27,584
hadiths; one file per book would be a fetch no phone should be asked to make,
and one page of 27,584 items is not a page. So the site loads
`hadith/index.json` (the nine books and their 1,482 chapters) and then one
chapter at a time.
"""
import json
import os
import re
import shutil
import sqlite3

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
APP = os.path.join(ROOT, 'rafeeq_app')
OUT = os.path.join(os.path.dirname(ROOT), 'rafeeq-review')
DATA = os.path.join(OUT, 'data')

# Groups of the Arabic locale file that carry religious content the app
# wrote or selected (hadith citations, rulings, du'a, biographies...).
TEXT_GROUPS = {
    'sunan_suwar': 'سنن السور',
    'hadith_daily': 'حديث اليوم',
    'fasting': 'تذكير الصيام',
    'ruqyah': 'الرقية الشرعية',
    'guide': 'دليل المسلم الجديد',
    'new_muslim': 'دليل المسلم الجديد (عناوين)',
    'imam_bio': 'تراجم الأئمة',
    'book_desc': 'أوصاف الكتب',
    'hijri_day': 'الأيام الهجرية',
    'tasbih': 'المسبحة',
    'dedication': 'الإهداءات',
    'hajj': 'مناسك الحج (نصوص الواجهة)',
    'tajweed': 'التجويد (نصوص الواجهة)',
    'makharij': 'مخارج الحروف',
    'azkar': 'الأذكار (نصوص الواجهة)',
    'quotes': 'المقولات (نصوص الواجهة)',
}


def grade_tables():
    """The app's own Arabic terms, parsed out of `hadith_grade_i18n.dart`.

    The bundled dataset's grade and grader columns are English free text
    ("Hasan Sahih", "Al-Albani"), and the reviewers are Arabic speakers:
    «انا عاوزه عربي لان الشيوخ كلهم عرب». The app already restores those
    terms; reading its table here instead of writing a second one means the
    site and the app can never drift, and nobody is shown a transliteration.
    """
    src = open(os.path.join(APP, 'lib', 'core', 'i18n',
                            'hadith_grade_i18n.dart'), encoding='utf-8').read()
    quote = chr(34)
    bs = chr(92)

    def table(name):
        head = 'const ' + name + ' = <String, String>{'
        i = src.index(head) + len(head)
        block = src[i:src.index(bs.join([]) + '\n};', i)]
        out = []
        for line in block.split('\n'):
            line = line.strip()
            # The grade table is double-quoted and the grader table is
            # single-quoted; reading only one of them is how 18,047 rulings
            # kept an English grader name on an Arabic screen.
            quote = line[:1]
            if quote not in ('"', chr(39)):
                continue
            # "key": "value",
            j = line.index(quote, 1)
            key = line[1:j]
            rest = line[j + 1:]
            k = rest.index(quote)
            val = rest[k + 1:rest.index(quote, k + 1)]
            key = key.replace(bs + 'u2019', chr(0x2019)).replace(bs + "'", "'")
            out.append((key, val))
        return out

    return table('_kGradeTermsArabic'), dict(table('_kGraderNamesArabic'))


def dump(name, obj):
    with open(os.path.join(DATA, name), 'w', encoding='utf-8') as f:
        json.dump(obj, f, ensure_ascii=False, separators=(',', ':'))


def main():
    os.makedirs(DATA, exist_ok=True)

    db = sqlite3.connect(os.path.join(APP, 'assets', 'data', 'quran_sciences.db'))
    sections = []
    for sid, title in db.execute('select id, title from azkar_sections order by id'):
        items = [{'id': i, 'text': b, 'note': f or ''} for i, b, f in db.execute(
            'select id, body, footnote from azkar_items where section_id=? order by id', (sid,))]
        sections.append({'title': title, 'items': items})
    dump('azkar.json', sections)

    shutil.copy(os.path.join(APP, 'assets', 'data', 'quotes.json'),
                os.path.join(DATA, 'quotes.json'))

    ar = json.load(open(os.path.join(APP, 'assets', 'translations', 'ar.json'),
                        encoding='utf-8'))
    dump('texts.json', [
        {'title': t, 'items': [{'id': f'{g}.{k}', 'text': v}
                               for k, v in ar[g].items() if isinstance(v, str)]}
        for g, t in TEXT_GROUPS.items() if g in ar])
    dump('sources.json', [{'id': k, 'text': v} for k, v in ar['about'].items()
                          if k.startswith('src_')])

    for f in ('hajj.json', 'tajweed.json'):
        shutil.copy(os.path.join(APP, 'build', 'review', f), os.path.join(DATA, f))

    hadith(db)

    shutil.copy(os.path.join(APP, 'assets', 'icon', 'app_icon.png'),
                os.path.join(OUT, 'icon.png'))
    print('ok', OUT)


def hadith(_unused):
    """The nine books, chapter by chapter, with each hadith's ruling.

    `grade` without `grader` is not shown as a ruling: the app's own rule is
    that a grading must name whose it is, and Bukhari and Muslim ship
    deliberately ungraded («من الصحيحين»). The site says which of the three
    states each hadith is in rather than leaving a blank column to be read as
    an omission.
    """
    terms, graders = grade_tables()
    con = sqlite3.connect(os.path.join(APP, 'assets', 'data', 'hadith.db'))
    root = os.path.join(DATA, 'hadith')
    os.makedirs(root, exist_ok=True)

    chapters = {}
    for bid, no, name in con.execute(
            'select book_id, chapter_no, name_ar from chapters'
            ' order by book_id, chapter_no'):
        chapters.setdefault(bid, []).append((no, name))

    index, graded, ungraded, files = [], 0, 0, 0
    for (bid, key, name, author, count) in con.execute(
            'select id, book_key, name_ar, author_ar, hadith_count from books'
            ' order by sort_order'):
        os.makedirs(os.path.join(root, key), exist_ok=True)
        chs = []
        for no, cname in chapters.get(bid, []):
            rows = con.execute(
                'select number_in_book, arabic, grade, grader from hadiths'
                ' where book_id=? and chapter_no=? order by number_in_book',
                (bid, no)).fetchall()
            if not rows:
                continue
            items = []
            for num, arabic, grade, grader in rows:
                g = (grade or '').strip()
                r = (grader or '').strip()
                # Longest phrase first, exactly as the app
                # applies them.
                for en, ar in terms:
                    g = g.replace(en, ar)
                r = graders.get(r, r)
                if g and r:
                    graded += 1
                else:
                    ungraded += 1
                items.append({'n': num, 't': arabic,
                              'g': g if (g and r) else '',
                              'r': r if (g and r) else ''})
            # `chapter_no` is not always an integer - Nasa'i's كتاب المزارعة
            # is 35.2 (trap #42) - so the file is named by the number as the
            # source writes it.
            fname = str(no).rstrip('0').rstrip('.') if isinstance(no, float)                 else str(no)
            with open(os.path.join(root, key, fname + '.json'), 'w',
                      encoding='utf-8') as f:
                json.dump(items, f, ensure_ascii=False, separators=(',', ':'))
            files += 1
            chs.append({'no': fname, 'name': cname, 'count': len(items)})
        index.append({'key': key, 'name': name, 'author': author,
                      'count': count, 'chapters': chs})

    with open(os.path.join(root, 'index.json'), 'w', encoding='utf-8') as f:
        json.dump(index, f, ensure_ascii=False, separators=(',', ':'))
    print('hadith: %d books, %d chapter files, %d with a named grader, '
          '%d without' % (len(index), files, graded, ungraded))


if __name__ == '__main__':
    main()
