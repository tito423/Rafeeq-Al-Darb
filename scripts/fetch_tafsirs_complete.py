"""
P3-9 fix: the bundled quran_sciences.db's tafseer_texts table only ever had
real per-ayah data for roughly the first ~10 ayahs of every surah (~1000
rows total for a source that needs 6236) -- root-caused to api.quran.com's
`by_chapter` endpoint paginating at 10 results/page by default, and the
original fetch never handled pagination. A separate row-grouping bug in
build_sciences_db.py's load_grouped() then made things worse: whenever a
surah's source data ran out early, the *last present* verse's range got
silently extended all the way to that surah's final ayah, so ~83% of the
Quran was actually showing an earlier, unrelated ayah's tafsir.

Separately, the source labelled "jalalayn" (id 14 on api.quran.com) was
never actually Tafsir al-Jalalayn at all -- id 14 is, and per the API's own
`/resources/tafsirs` listing has always been, Tafsir Ibn Kathir. Real
Jalalayn isn't offered by this provider at all currently. Rather than ship
fabricated/mislabeled content, this re-fetches id 14 under its real,
correct identity (Ibn Kathir) instead of inventing a fake Jalalayn.

Fix for both bugs at once: `?per_page=300` comfortably covers every surah
(Al-Baqarah, the longest, has 286 ayahs) in a single request per chapter,
and this fetches real per-ayah text directly -- no range-grouping/fallback
logic needed at all, so that whole class of bug is structurally impossible
this time.
"""
import json
import os
import time

import requests

BASE = os.path.join(os.path.dirname(__file__), "temp_phase1", "tafsir_complete")
os.makedirs(BASE, exist_ok=True)

# api.quran.com tafsir resource ids (verified live against /resources/tafsirs):
#   16 = Tafsir Muyassar (correct, matches what's already shipped)
#   90 = Al-Qurtubi (correct, matches what's already shipped)
#   14 = Tafsir Ibn Kathir (the *real* identity of what was mislabeled "jalalayn")
SOURCES = {
    16: "muyassar",
    90: "qurtubi",
    14: "ibn_kathir",
}

session = requests.Session()

for tafsir_id, key in SOURCES.items():
    out_dir = os.path.join(BASE, key)
    os.makedirs(out_dir, exist_ok=True)
    for ch in range(1, 115):
        path = os.path.join(out_dir, f"ch{ch}.json")
        if os.path.exists(path):
            continue
        url = f"https://api.quran.com/api/v4/tafsirs/{tafsir_id}/by_chapter/{ch}"
        try:
            r = session.get(url, params={"per_page": 300}, timeout=30)
            r.raise_for_status()
            data = r.json()
            items = data.get("tafsirs", [])
            pagination = data.get("pagination", {})
            with open(path, "w", encoding="utf-8") as f:
                json.dump(items, f, ensure_ascii=False)
            got = len(items)
            total = pagination.get("total_records")
            status = "OK" if total is None or got >= total else f"SHORT (got {got}/{total})"
            print(f"{key} ch{ch}: {got} ayahs {status}")
        except Exception as e:
            print(f"{key} ch{ch}: ERROR {e}")
        time.sleep(0.12)

with open(os.path.join(BASE, "_complete.txt"), "w") as f:
    f.write("done\n")
print("DONE")
