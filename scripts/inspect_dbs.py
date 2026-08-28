import sqlite3, os, json

DBS = [
    r"e:\My Projects\Rafiq-Al-Darb\Rafeeq-Al-Darb_Backend\quran_local.db",
    r"e:\My Projects\Rafiq-Al-Darb\rafeeq_app\assets\data\hadith.db",
    r"e:\My Projects\Rafiq-Al-Darb\rafeeq_app\assets\data\quran_sciences.db",
    r"e:\My Projects\Rafiq-Al-Darb\scripts\pipeline_temp\quran_sciences.db",
]

for db in DBS:
    if not os.path.exists(db):
        print(f"=== {db}: MISSING ===")
        continue
    print(f"=== {db} ({os.path.getsize(db)//1024} KB) ===")
    con = sqlite3.connect(db)
    cur = con.cursor()
    for (t,) in cur.execute("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name").fetchall():
        cols = cur.execute(f"PRAGMA table_info({t})").fetchall()
        cnt = cur.execute(f"SELECT COUNT(*) FROM [{t}]").fetchone()[0]
        colstr = ", ".join(f"{c[1]}:{c[2]}" for c in cols)
        print(f"  {t} [{cnt} rows] -> {colstr}")
        # sample first row truncated
        try:
            row = cur.execute(f"SELECT * FROM [{t}] LIMIT 1").fetchone()
            s = str(row)
            print(f"    sample: {s[:300]}")
        except Exception as e:
            print(f"    (sample error: {e})")
    con.close()
    print()
