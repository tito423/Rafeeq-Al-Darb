import sqlite3
c = sqlite3.connect(r'E:\shamela\database\book\022\22.db').cursor()
tables = [t[0] for t in c.execute("SELECT name FROM sqlite_master WHERE type='table'").fetchall()]
for t in tables:
    schema = [r[1] for r in c.execute(f"PRAGMA table_info({t})").fetchall()]
    print(t, schema)
