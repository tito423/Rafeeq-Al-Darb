"""Read-only host SQLite census, query plans and bounded-query timings.

These are Windows Python/SQLite timings, not Android platform-channel,
Flutter frame, model-loading, or physical-phone performance measurements.
"""
from pathlib import Path
import hashlib, json, sqlite3, statistics, time

root = Path('E:/My Projects/Rafiq-Al-Darb')
out = root / 'docs/audits/evidence/2026-10-09'
queries = {
    'quran_local.db': [('page564', 'SELECT * FROM ayahs WHERE page_number=? ORDER BY id', [564]),
        ('surah2', 'SELECT * FROM ayahs WHERE surah_id=? ORDER BY ayah_number',[2]),
        ('ayah4_115','SELECT * FROM ayahs WHERE surah_id=? AND ayah_number=? LIMIT 1',[4,115]),
        ('audio_global4_115','SELECT COUNT(*) AS c FROM ayahs WHERE surah_id < ? OR (surah_id=? AND ayah_number<=?)',[4,4,115])],
    'hadith.db': [('first_search_batch','SELECT * FROM hadiths ORDER BY book_id,number_in_book LIMIT 2000 OFFSET 0',[]),
        ('last_search_batch','SELECT * FROM hadiths ORDER BY book_id,number_in_book LIMIT 2000 OFFSET 66000',[]),
        ('daily_random','SELECT * FROM hadiths WHERE book_id IN (1,2,3,4,5,6,9) ORDER BY RANDOM() LIMIT 1',[]),
        ('hadith_lookup','SELECT * FROM hadiths WHERE book_id=? AND number_in_book=? LIMIT 1',[4,1])],
    'azkar.db': [], 'quran_sciences.db': [],
}
result = []
for name, cases in queries.items():
    path = root / 'rafeeq_app/assets/data' / name
    db = sqlite3.connect(f'file:{path.as_posix()}?mode=ro',uri=True)
    item = dict(name=name,bytes=path.stat().st_size,sha256=hashlib.sha256(path.read_bytes()).hexdigest(),
        quick_check=db.execute('PRAGMA quick_check').fetchall(),
        indexes=db.execute("SELECT name,tbl_name,sql FROM sqlite_master WHERE type='index'").fetchall(),
        tables=db.execute("SELECT name FROM sqlite_master WHERE type='table'").fetchall(),
        sqlite_version=sqlite3.sqlite_version,queries=[])
    for label, sql, params in cases:
        first_start = time.perf_counter_ns()
        rows = db.execute(sql,params).fetchall()
        first_ms = (time.perf_counter_ns()-first_start)/1e6
        timings = []
        for repeat in range(30):
            started = time.perf_counter_ns()
            db.execute(sql,params).fetchall()
            timings.append((time.perf_counter_ns()-started)/1e6)
        item['queries'].append(dict(label=label,sql=sql,params=params,rows=len(rows),
            query_plan=db.execute('EXPLAIN QUERY PLAN '+sql,params).fetchall(),
            first_query_ms=first_ms,warm_runs=30,median_ms=statistics.median(timings),
            p95_ms=sorted(timings)[28],max_ms=max(timings)))
    if name == 'hadith.db':
        item['hadith_count'] = db.execute('SELECT count(*) FROM hadiths').fetchone()[0]
        item['by_grader'] = db.execute('SELECT grader,count(*) FROM hadiths GROUP BY grader').fetchall()
        item['graded_without_grader'] = db.execute("SELECT count(*) FROM hadiths WHERE grade IS NOT NULL AND trim(grade)<>'' AND (grader IS NULL OR trim(grader)='')").fetchone()[0]
        item['books'] = db.execute('SELECT b.book_key,count(h.id),sum(h.grade IS NOT NULL),b.hadith_count FROM books b JOIN hadiths h ON b.id=h.book_id GROUP BY b.id').fetchall()
        item['darussalam_collections'] = db.execute("SELECT b.book_key,count(*) FROM hadiths h JOIN books b ON b.id=h.book_id WHERE grader='Darussalam' GROUP BY b.id").fetchall()
    db.close()
    result.append(item)
(out/'db-census-query-timings.json').write_text(json.dumps(dict(databases=result,
    scope='Actual read-only bundled databases. First/warm SQL timings on host SQLite only; excludes Arabic normalization, Dart parsing, Android IPC and UI.'),
    ensure_ascii=False,indent=2),encoding='utf-8')
for item in result:
    print(item['name'],'quick_check',item['quick_check'],flush=True)
    for query in item['queries']:
        print(query['label'],'rows',query['rows'],'median_ms',round(query['median_ms'],3),
              'p95_ms',round(query['p95_ms'],3),'plan',query['query_plan'],flush=True)
