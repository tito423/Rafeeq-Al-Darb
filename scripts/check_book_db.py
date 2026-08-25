import sqlite3
c = sqlite3.connect(r'E:\shamela\database\book\022\22.db').cursor()
tables = [t[0] for t in c.execute("SELECT name FROM sqlite_master WHERE type='table'").fetchall()]
print("Tables:", tables)

for t in tables:
    schema = [row[1] for row in c.execute(f"PRAGMA table_info({t})").fetchall()]
    print(f"Schema {t}:", schema)

c.execute("SELECT * FROM b22 LIMIT 1")
print("b22 sample:", c.fetchone())
