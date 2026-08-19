import sqlite3
import os
import json

def check_db(db_path):
    if not os.path.exists(db_path):
        print(f'{db_path} does not exist')
        return
    print(f'=== Checking {db_path} ===')
    conn = sqlite3.connect(db_path)
    cur = conn.cursor()
    cur.execute("SELECT name FROM sqlite_master WHERE type='table';")
    tables = [row[0] for row in cur.fetchall()]
    print('Tables:', tables)
    for table in tables:
        if table.startswith('sqlite_'):
            continue
        cur.execute(f'SELECT count(*) FROM {table}')
        total = cur.fetchone()[0]
        cur.execute(f'PRAGMA table_info({table})')
        cols = [c[1] for c in cur.fetchall()]
        print(f'  Table {table}: {total} rows. Columns: {cols}')
        
        non_id_cols = [c for c in cols if c.lower() != 'id']
        if non_id_cols:
            cols_str = ', '.join([f'"{c}"' for c in non_id_cols])
            cur.execute(f'SELECT {cols_str}, count(*) c FROM {table} GROUP BY {cols_str} HAVING c > 1')
            dups = cur.fetchall()
            print(f'    Duplicates in {table} (by {non_id_cols}): {len(dups)}')
            if dups:
                print('    Sample duplicate:', dups[:3])
    conn.close()

def check_hadith():
    hadith_dir = 'assets/data/hadith'
    if not os.path.exists(hadith_dir):
        print('No hadith dir')
        return
    print('=== Checking Hadith JSON files ===')
    for f in os.listdir(hadith_dir):
        if f.endswith('.json'):
            path = os.path.join(hadith_dir, f)
            with open(path, 'r', encoding='utf-8') as fp:
                data = json.load(fp)
                if isinstance(data, list):
                    print(f'{f}: {len(data)} items')
                    # check hadith duplicates by text or number
                    seen = set()
                    dups = 0
                    for item in data:
                        h_num = item.get('hadithNumber') or item.get('number') or item.get('id')
                        if h_num in seen:
                            dups += 1
                        else:
                            seen.add(h_num)
                    print(f'  Duplicates in {f}: {dups}')

if __name__ == '__main__':
    check_db('assets/quran_local.db')
    check_db('assets/data/quran.db')
    check_hadith()
