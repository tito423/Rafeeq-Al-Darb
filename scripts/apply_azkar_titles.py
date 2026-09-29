"""Write azkar.section.<id> into all seven locale files from
scripts/azkar_hisn/section_titles.tsv (six languages) and azkar.db (Arabic).

    py -3 scripts/apply_azkar_titles.py
"""
import csv
import json
import os
import sqlite3

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
TSV = os.path.join(ROOT, 'scripts', 'azkar_hisn', 'section_titles.tsv')
DB = os.path.join(ROOT, 'rafeeq_app', 'assets', 'data', 'azkar.db')
TR = os.path.join(ROOT, 'rafeeq_app', 'assets', 'translations')


def main():
    ar = {str(i): t for i, t in sqlite3.connect(DB).execute(
        'select id, title from azkar_sections')}
    rows = list(csv.DictReader(open(TSV, encoding='utf-8'), delimiter=chr(9)))
    assert len(rows) == len(ar), (len(rows), len(ar))
    by = {l: {r['id']: r[l].strip() for r in rows} for l in
          ('en', 'es', 'fr', 'pt', 'ru', 'ur')}
    by['ar'] = ar
    for loc, titles in by.items():
        assert set(titles) == set(ar), loc
        assert all(titles.values()), loc
        p = os.path.join(TR, loc + '.json')
        d = json.load(open(p, encoding='utf-8'))
        d['azkar']['section'] = {k: titles[k] for k in sorted(titles, key=int)}
        json.dump(d, open(p, 'w', encoding='utf-8', newline=chr(10)),
                  ensure_ascii=False, indent=2)
        open(p, 'a', encoding='utf-8').write(chr(10))
        print(loc, len(titles))


main()
