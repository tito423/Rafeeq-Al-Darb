"""Build «مراجعة محتوى رفيق الدرب» - a static site for a scholar to review
every religious text the app ships, on his phone.

    cd rafeeq_app && flutter test --tags export test/export_review_texts_test.dart
    py -3 scripts/build_review_site.py

Writes ../rafeeq-review/ (its own git repo, published with GitHub Pages).
Everything is read from what the app really ships - the bundled databases,
the bundled books cut by the app's own code, the Arabic locale file - never
retyped. Stage 1: adhkar, quotes, app texts, Hajj, tajweed, sources.
"""
import json
import os
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

    shutil.copy(os.path.join(APP, 'assets', 'icon', 'app_icon.png'),
                os.path.join(OUT, 'icon.png'))
    print('ok', OUT)


if __name__ == '__main__':
    main()
