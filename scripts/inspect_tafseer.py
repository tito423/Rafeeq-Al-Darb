import json, os, io, sys

BASE = r"e:\My Projects\Rafiq-Al-Darb\scripts\temp_phase1"
OUT = r"e:\My Projects\Rafiq-Al-Darb\scripts\tafseer_report.txt"
FILES = [
    "tafseer_ar_muyassar.json",
    "tafseer_ar_jalalayn.json",
    "tafseer_ar_qurtubi.json",
    "tafseer_en_kathir.json",
    "word_meanings.json",
    "asbab_al_nuzul.json",
    "irab_data.json",
]

buf = io.StringIO()

def out(s=""):
    buf.write(s + "\n")

for f in FILES:
    p = os.path.join(BASE, f)
    if not os.path.exists(p):
        out(f"=== {f}: MISSING ===")
        continue
    size = os.path.getsize(p)
    out(f"=== {f} ({size} bytes) ===")
    if size < 100:
        out("  content: " + open(p, encoding='utf-8').read()[:100])
        continue
    try:
        d = json.load(open(p, encoding='utf-8'))
    except Exception as e:
        out(f"  JSON ERROR: {e}")
        continue
    if isinstance(d, dict):
        out(f"  dict keys: {list(d.keys())[:8]}")
        if 'verses' in d:
            v = d['verses']
            out(f"  verses type: {type(v).__name__}, count: {len(v)}")
            sample = v[0] if isinstance(v, list) else v[list(v.keys())[0]]
            out(f"  sample verse: {json.dumps(sample, ensure_ascii=False)[:300]}")
        else:
            k0 = list(d.keys())[0]
            out(f"  sample['{k0}'] = {json.dumps(d[k0], ensure_ascii=False)[:400]}")
    elif isinstance(d, list):
        out(f"  list len: {len(d)}")
        out(f"  sample[0] = {json.dumps(d[0], ensure_ascii=False)[:400]}")
    out("")

open(OUT, 'w', encoding='utf-8').write(buf.getvalue())
print("REPORT WRITTEN")
