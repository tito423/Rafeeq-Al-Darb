"""Lift the azkar tables out of `quran_sciences.db` into their own file.

The adhkar are 124 rows - under 100 KB - and they sat inside a 131.68 MB
database whose other four tables are tafsir, translations, i'rab and
word-by-word meanings. Stage one of «تصغير التطبيق»: `quran_sciences.db`
becomes a download, and a tab the owner opens every morning cannot wait on
131 MB, so the adhkar move to a bundled file of their own.

Schema and rows are copied verbatim - same table definitions, same ids, same
text - so `AzkarRepository`'s queries are the ones `SciencesRepository` ran,
and the copy is compared row for row against the source before it is kept.

    py -3 scripts/split_azkar_db.py
"""
import os
import sqlite3

SRC = os.path.join('rafeeq_app', 'assets', 'data', 'quran_sciences.db')
DST = os.path.join('rafeeq_app', 'assets', 'data', 'azkar.db')
TABLES = ('azkar_sections', 'azkar_items')


def main() -> int:
    if not os.path.exists(SRC):
        print('missing %s - rebuild it with scripts/build_sciences_db.py' % SRC)
        return 1
    if os.path.exists(DST):
        os.remove(DST)

    src = sqlite3.connect(SRC)
    dst = sqlite3.connect(DST)

    for table in TABLES:
        ddl = src.execute(
            "SELECT sql FROM sqlite_master WHERE type='table' AND name=?",
            (table,)).fetchone()
        if not ddl:
            print('no table %s in %s' % (table, SRC))
            return 1
        dst.execute(ddl[0])
        for idx, in src.execute(
                "SELECT sql FROM sqlite_master WHERE type='index' "
                "AND tbl_name=? AND sql IS NOT NULL", (table,)):
            dst.execute(idx)
        cols = [r[1] for r in src.execute('PRAGMA table_info("%s")' % table)]
        quoted = ','.join('"%s"' % c for c in cols)
        rows = src.execute('SELECT %s FROM "%s"' % (quoted, table)).fetchall()
        dst.executemany(
            'INSERT INTO "%s" (%s) VALUES (%s)'
            % (table, quoted, ','.join('?' * len(cols))), rows)
        print('%-18s %d rows, %d columns' % (table, len(rows), len(cols)))

    dst.commit()
    dst.execute('VACUUM')
    dst.close()

    # Prove the copy, row for row, against the source.
    chk = sqlite3.connect(DST)
    for table in TABLES:
        a = src.execute('SELECT * FROM "%s" ORDER BY id' % table).fetchall()
        b = chk.execute('SELECT * FROM "%s" ORDER BY id' % table).fetchall()
        if a != b:
            print('%s differs: %d source rows vs %d copied'
                  % (table, len(a), len(b)))
            return 1
        print('%-18s verified identical (%d rows)' % (table, len(a)))
    chk.close()
    src.close()
    print('%s  %d bytes' % (DST, os.path.getsize(DST)))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
