import sqlite3
import sys

sys.stdout.reconfigure(encoding='utf-8')

def check_db(db_path):
    print(f"=== Checking {db_path} ===")
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    cursor.execute("SELECT name FROM sqlite_master WHERE type='table';")
    tables = [t[0] for t in cursor.fetchall() if t[0] != 'sqlite_sequence']
    for table in tables:
        print(f"\nTable: {table}")
        cursor.execute(f"PRAGMA table_info({table});")
        cols = [c[1] for c in cursor.fetchall()]
        print(f"Columns: {cols}")
        for col in cols:
            # Check for ((, )), '', quotes, comma lines
            query = f"""
            SELECT id, {col} FROM {table} 
            WHERE {col} LIKE '%((%' 
               OR {col} LIKE '%))%' 
               OR {col} LIKE '%\',\'%' 
               OR {col} LIKE '%\'%' 
               OR {col} LIKE '%\"%' 
               OR {col} LIKE '%,,%'
            LIMIT 10;
            """
            try:
                rows = cursor.execute(query).fetchall()
                if rows:
                    print(f"  Col '{col}' has {len(rows)} matching artifact samples:")
                    for r in rows[:5]:
                        val = str(r[1])
                        print(f"    [id={r[0]}] {repr(val[:100])}")
            except Exception as e:
                pass
    conn.close()

if __name__ == "__main__":
    check_db("assets/quran_local.db")
    check_db("assets/data/hadith.db")
