import sqlite3, json, sys, os
surah = int(sys.argv[1])
start_ayah = int(sys.argv[2]) if len(sys.argv) > 2 else 1
end_ayah = int(sys.argv[3]) if len(sys.argv) > 3 else 286

quran_db = sqlite3.connect('rafeeq_app/assets/data/quran_local.db')

words = []
for ayah in range(start_ayah, end_ayah + 1):
    cur = quran_db.execute("SELECT text_uthmani FROM ayahs WHERE surah_id=? AND ayah_number=?", (surah, ayah))
    row = cur.fetchone()
    if not row: continue
    text = row[0]
    # words are space separated, excluding non-arabic parts but retaining uthmani marks
    toks = [t for t in text.split() if any('\u0621' <= c <= '\u064A' for c in t)]
    for w in toks:
        words.append({"a": ayah, "w": w, "irab": "", "check": "agree"})

data = {"surah": surah, "words": words}
with open(f"scripts/own_irab/{surah:03d}.json", "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, indent=1)
