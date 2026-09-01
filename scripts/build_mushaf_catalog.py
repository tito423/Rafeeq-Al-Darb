#!/usr/bin/env python3
"""
Generate the mushaf edition catalog from the polygon sets actually present.

Derived from the built data rather than hand-written, so the catalog can never
claim an edition or an ayah count the app does not really have.

Ayah numbering matters here. The bundled sciences database (tafsir, i'rab,
translations) is keyed to Hafs numbering. Shu'bah shares it exactly (both are
riwayat of 'Asim), but Warsh, Qalun and Duri split verses differently in many
surahs, and inside such a surah every later ayah shifts. Serving Hafs-keyed
tafsir there would quietly show the wrong commentary, so each edition records
exactly which surahs are unsafe.
"""
import json, os, glob, sqlite3

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MUSHAF_DIR = os.path.join(ROOT, 'rafeeq_app', 'assets', 'data', 'mushaf')
QURAN_DB   = os.path.join(ROOT, 'rafeeq_app', 'assets', 'data', 'quran_local.db')
OUT        = os.path.join(MUSHAF_DIR, 'editions.json')

META = {
    'hafs_kfqc':   dict(riwayah_ar='حفص عن عاصم',       riwayah_en='Hafs an Asim',
                        name_ar='مصحف المدينة — رواية حفص',
                        name_en='Madinah Mushaf — Hafs'),
    'shubah_kfqc': dict(riwayah_ar='شعبة عن عاصم',       riwayah_en='Shubah an Asim',
                        name_ar='مصحف المدينة — رواية شعبة',
                        name_en='Madinah Mushaf — Shubah'),
    'warsh_kfqc':  dict(riwayah_ar='ورش عن نافع',        riwayah_en='Warsh an Nafi',
                        name_ar='مصحف المدينة — رواية ورش',
                        name_en='Madinah Mushaf — Warsh'),
    'qalon_kfqc':  dict(riwayah_ar='قالون عن نافع',      riwayah_en='Qalun an Nafi',
                        name_ar='مصحف المدينة — رواية قالون',
                        name_en='Madinah Mushaf — Qalun'),
    'douri_kfqc':  dict(riwayah_ar='الدوري عن أبي عمرو', riwayah_en='Duri an Abu Amr',
                        name_ar='مصحف المدينة — رواية الدوري',
                        name_en='Madinah Mushaf — Duri'),
}

hafs_db = set(sqlite3.connect(QURAN_DB).execute(
    'SELECT surah_id, ayah_number FROM ayahs'))

editions = []
for path in sorted(glob.glob(os.path.join(MUSHAF_DIR, '*_polygons.json'))):
    eid = os.path.basename(path).replace('_polygons.json', '')
    doc = json.load(open(path, encoding='utf-8'))
    ayahs = {(s, a) for lst in doc['pages'].values() for s, a, _ in lst}
    diverging = sorted({su for su, _ in (ayahs ^ hafs_db)})
    meta = META.get(eid, {})
    editions.append({
        'id': eid,
        'source_path': doc['edition'],
        'name_ar': meta.get('name_ar', eid),
        'name_en': meta.get('name_en', eid),
        'riwayah_ar': meta.get('riwayah_ar', ''),
        'riwayah_en': meta.get('riwayah_en', ''),
        'pages': len(doc['pages']),
        'ayahs': len(ayahs),
        'polygons_asset': 'assets/data/mushaf/%s_polygons.json' % eid,
        'sciences_aligned': not diverging,
        'diverging_surahs': diverging,
        'is_default': eid == 'hafs_kfqc',
    })

editions.sort(key=lambda e: (not e['is_default'], not e['sciences_aligned'], e['id']))

doc = {
    'version': 1,
    'license': 'quranpedia/quran-svg — polygon metadata CC0-1.0; '
               'KFQC glyphs free for digital use',
    'pin': 'b91d39e1065b57bdda3e94aca8ecf3575e50e1e6',
    'editions': editions,
}
with open(OUT, 'w', encoding='utf-8', newline='\n') as f:
    json.dump(doc, f, ensure_ascii=False, indent=2)

print('%-14s %6s %6s  %s' % ('edition', 'pages', 'ayahs', 'sciences'))
for e in editions:
    note = 'aligned' if e['sciences_aligned'] else \
           'diverges in %d surahs' % len(e['diverging_surahs'])
    print('%-14s %6d %6d  %s' % (e['id'], e['pages'], e['ayahs'], note))
print('\nwrote', OUT)
