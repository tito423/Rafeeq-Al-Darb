# -*- coding: utf-8 -*-
"""Find every column the app casts as a non-nullable `int` that the database
does not actually store as one.

WHY THIS EXISTS. Sunan an-Nasa'i's «كتاب المزارعة» is chapter **35.2** — a real
sub-book carrying 83 hadiths, stored by SQLite as a REAL. `HadithChapter`
read it with `r['chapter_no'] as int`, which throws
`type 'double' is not a subtype of type 'int'`; and because the cast runs while
mapping the result set, the throw took **all 52 of that collection's books**
down with it. From the outside it looked like one screen loading for ever.

One row in 1,482 did that. So rather than trust that the other twenty-odd
`as int` casts are safe, this asks the databases:

    py -3 scripts/db_type_audit.py

For every `X as int` in the repository code it finds the column and reports any
value in it that is not an integer, and any NULL where the cast is
non-nullable. A clean run is evidence; reading the code is not.
"""

import io
import os
import re
import sqlite3
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DB_DIR = os.path.join(ROOT, 'rafeeq_app', 'assets', 'data')
CODE_DIRS = [os.path.join(ROOT, 'rafeeq_app', 'lib', 'core', 'db')]
REPORT = os.path.join(ROOT, 'db_type_audit.txt')

# `r['col'] as int` and `row['col'] as int` — the non-nullable form. The
# nullable `as int?` form is fine: it is what a NULL is supposed to meet.
CAST = re.compile(r"\['([a-z_0-9]+)'\]\s+as\s+int\b(?!\?)")


def columns_cast_as_int():
    wanted = set()
    for d in CODE_DIRS:
        for name in os.listdir(d):
            if not name.endswith('.dart'):
                continue
            src = io.open(os.path.join(d, name), encoding='utf-8').read()
            wanted.update(CAST.findall(src))
    return wanted


def main():
    wanted = columns_cast_as_int()
    out = []
    out.append('columns the code casts as a non-nullable int: %d'
               % len(wanted))
    out.append('  ' + ', '.join(sorted(wanted)))
    out.append('')

    dbs = sorted(f for f in os.listdir(DB_DIR) if f.endswith('.db'))
    if not dbs:
        sys.exit('no bundled databases in %s (they are gitignored and '
                 'regenerable — build them first)' % DB_DIR)

    problems = []
    for db in dbs:
        path = os.path.join(DB_DIR, db)
        con = sqlite3.connect('file:%s?mode=ro' % path.replace('\\', '/'),
                              uri=True)
        c = con.cursor()
        tables = [r[0] for r in c.execute(
            "SELECT name FROM sqlite_master WHERE type='table'")]
        out.append('=== %s (%d tables) ===' % (db, len(tables)))
        for t in tables:
            try:
                cols = [r[1] for r in c.execute('PRAGMA table_info("%s")' % t)]
            except sqlite3.DatabaseError:
                continue
            for col in cols:
                if col not in wanted:
                    continue
                try:
                    bad = c.execute(
                        'SELECT COUNT(*) FROM "%s" WHERE typeof("%s") '
                        "NOT IN ('integer')" % (t, col)).fetchone()[0]
                    nulls = c.execute(
                        'SELECT COUNT(*) FROM "%s" WHERE "%s" IS NULL'
                        % (t, col)).fetchone()[0]
                    total = c.execute(
                        'SELECT COUNT(*) FROM "%s"' % t).fetchone()[0]
                except sqlite3.DatabaseError as e:
                    out.append('  %-28s %-18s ! %s' % (t, col, e))
                    continue
                flag = ''
                if bad:
                    flag = '  <-- %d of %d NOT integer' % (bad, total)
                    sample = c.execute(
                        'SELECT "%s", typeof("%s") FROM "%s" WHERE '
                        "typeof(\"%s\") NOT IN ('integer') LIMIT 3"
                        % (col, col, t, col)).fetchall()
                    problems.append('%s.%s.%s: %d of %d not integer, e.g. %s'
                                    % (db, t, col, bad, total, sample))
                elif nulls:
                    flag = '  <-- %d NULL' % nulls
                    problems.append('%s.%s.%s: %d NULL under a non-nullable '
                                    'cast' % (db, t, col, nulls))
                out.append('  %-28s %-18s %6d rows%s' % (t, col, total, flag))
        con.close()
        out.append('')

    out.append('=== VERDICT ===')
    if problems:
        out.append('%d column(s) can crash a cast:' % len(problems))
        out.extend('  ' + p for p in problems)
    else:
        out.append('every column the code casts as int really is an integer, '
                   'everywhere, with no NULLs.')

    io.open(REPORT, 'w', encoding='utf-8', newline='\n').write('\n'.join(out))
    sys.stdout.write(io.open(REPORT, encoding='utf-8').read())
    return 1 if problems else 0


if __name__ == '__main__':
    sys.exit(main())
