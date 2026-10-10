"""Read-only structural census of already fetched books and bundled courses.

Exact Quran comparisons use the existing bundled SQLite, without normalizing
or changing any source text. This is not certification against a printed page.
"""
from pathlib import Path
import collections, gzip, hashlib, json, sqlite3, tempfile

root = Path('E:/My Projects/Rafiq-Al-Darb')
out = root / 'docs/audits/evidence/2026-10-09'
cache = Path(tempfile.gettempdir()) / 'rafeeq_audit_content_20261009'
inventory = json.loads((out / 'endpoint-inventory.json').read_text(encoding='utf-8'))

def decode(data):
    return json.loads(gzip.decompress(data) if data[:2] == b'\x1f\x8b' else data)

books = []
for item in inventory:
    if item['kind'] != 'book':
        continue
    data = (cache / (hashlib.sha256(item['url'].encode()).hexdigest() + '.bin')).read_bytes()
    doc = decode(data)
    pages, toc, meta = doc.get('pages', []), doc.get('toc', []), doc.get('meta', {})
    bad_types = []
    empty_pages = []
    kinds = collections.Counter()
    for pi, page in enumerate(pages):
        if not isinstance(page.get('p', 0), int):
            bad_types.append(['page_number', pi])
        if not page.get('paras'):
            empty_pages.append(pi)
        for para in page.get('paras', []):
            if not isinstance(para.get('t', ''), str):
                bad_types.append(['paragraph_text', pi])
            kinds[para.get('k', 'body')] += 1
    out_of_range = [ti for ti, t in enumerate(toc)
                    if not isinstance(t.get('pageIndex', 0), int)
                    or not 0 <= t.get('pageIndex', 0) < len(pages)]
    inversions = [ti for ti in range(1, len(toc))
                  if isinstance(toc[ti].get('pageIndex', 0), int)
                  and isinstance(toc[ti - 1].get('pageIndex', 0), int)
                  and toc[ti].get('pageIndex', 0) < toc[ti - 1].get('pageIndex', 0)]
    books.append(dict(id=doc.get('id'), url=item['url'], sha256_wire=hashlib.sha256(data).hexdigest(),
                      pages=len(pages), paragraphs=sum(kinds.values()), toc=len(toc), kinds=dict(kinds),
                      empty_page_indices=empty_pages, invalid_types=bad_types,
                      toc_out_of_range=out_of_range, toc_index_inversions=inversions,
                      missing_provenance=[key for key in ['titleAr', 'authorAr', 'sourceLabel', 'shamelaUrl']
                                          if not meta.get(key)],
                      declared_page_count=meta.get('pageCount'),
                      declared_section_count=meta.get('sectionCount')))

db_path = root / 'rafeeq_app/assets/data/quran_local.db'
db = sqlite3.connect(f'file:{db_path.as_posix()}?mode=ro', uri=True)
canonical = {f'{s}:{a}': text for s, a, text in db.execute(
    'SELECT surah_id,ayah_number,text_uthmani FROM ayahs')}
surah_counts = dict(db.execute('SELECT id,ayahs_count FROM surahs'))
actual_counts = dict(db.execute('SELECT surah_id,count(*) FROM ayahs GROUP BY surah_id'))
course_results = []
for path in sorted((root / 'rafeeq_app/assets/data/tajweed').glob('*.json.gz')):
    doc = decode(path.read_bytes())
    mismatches, duplicates = [], collections.Counter()
    examined = 0
    for li, lesson in enumerate(doc['lessons']):
        duplicates[lesson['title']] += 1
        for bi, block in enumerate(lesson['blocks']):
            for si, span in enumerate(block['s']):
                if span[0] not in ['q', 'r']:
                    continue
                examined += 1
                ref = span[2] if len(span) > 2 else None
                text = canonical.get(ref)
                if text is None or span[1] not in text:
                    mismatches.append(dict(lesson=li, block=bi, span=si, ref=ref,
                                           quote=span[1], canonical=text))
    course_results.append(dict(path=path.relative_to(root).as_posix(),
                               sha256=hashlib.sha256(path.read_bytes()).hexdigest(),
                               lessons=len(doc['lessons']), quran_spans=examined,
                               exact_substring_mismatches=mismatches,
                               duplicate_lesson_titles={k: n for k, n in duplicates.items() if n > 1}))
result = dict(books=books, summary=dict(books=len(books), pages=sum(b['pages'] for b in books),
                paragraphs=sum(b['paragraphs'] for b in books),
                invalid_type_books=[b['id'] for b in books if b['invalid_types']],
                empty_books=[b['id'] for b in books if not b['pages']],
                missing_provenance_books=[b['id'] for b in books if b['missing_provenance']],
                toc_range_candidate_books=[b['id'] for b in books if b['toc_out_of_range']],
                toc_order_candidate_books=[b['id'] for b in books if b['toc_index_inversions']]),
              quran=dict(sha256=hashlib.sha256(db_path.read_bytes()).hexdigest(),
                         verses=len(canonical), surahs=len(surah_counts),
                         count_mismatches={str(s): [n, actual_counts.get(s)] for s, n in surah_counts.items()
                                           if n != actual_counts.get(s)},
                         quick_check=db.execute('PRAGMA quick_check').fetchall()),
              courses=course_results,
              limits='Structural census and exact reference/substrings only; TOC candidates require production parser verification. Religious text unchanged; no printed-page certification.')
db.close()
(out / 'content-structure.json').write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding='utf-8')
print(json.dumps(result['summary'], ensure_ascii=False))
print(json.dumps(result['quran'], ensure_ascii=False))
for course in course_results:
    print(course['path'], 'Quran spans', course['quran_spans'], 'mismatches', len(course['exact_substring_mismatches']),
          'duplicate titles', course['duplicate_lesson_titles'])
