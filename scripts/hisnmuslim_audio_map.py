"""Pairs every dhikr in the app's azkar.db with its recording on hisnmuslim.com.

Owner, 2026-09-29: «حط زرار استماع في الاذكار كلها». The app's text is the
asellam/HisnElMuslim copy of Hisn al-Muslim; hisnmuslim.com (the book's own
site) publishes the same book with one mp3 per dhikr through a public JSON
API. Its ids are not ours, so each dhikr is paired by its TEXT: letters only,
no marks, no punctuation, and the best match must be clearly the best.

Writes
  scripts/azkar_hisn/hisnmuslim_api/        the API responses, as fetched
  rafeeq_app/assets/data/azkar_audio.json   {dhikr id: mp3 url}
  scripts/azkar_hisn/azkar_audio_report.txt every pairing with its score,
                                            and every dhikr left without one
Every url written was answered 206 audio/mpeg to a 1 KB range request.

    py -3 scripts/hisnmuslim_audio_map.py
"""
import difflib
import json
import re
import sqlite3
import time
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
API = ROOT / "scripts/azkar_hisn/hisnmuslim_api"
DB = ROOT / "rafeeq_app/assets/data/azkar.db"
OUT = ROOT / "rafeeq_app/assets/data/azkar_audio.json"
REPORT = ROOT / "scripts/azkar_hisn/azkar_audio_report.txt"
UA = {"User-Agent": "Mozilla/5.0 (Rafeeq Al-Darb; tito423 on GitHub)"}
ACCEPT = 0.80   # a candidate; it is accepted only if same_words() holds


def get(url, binary=False, rng=None):
    headers = dict(UA)
    if rng:
        headers["Range"] = rng
    for attempt in range(4):
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers=headers), timeout=30) as r:
                data = r.read()
                return (r.status, r.headers.get("Content-Type", ""), data) if binary else data.decode("utf-8-sig")
        except Exception:
            if attempt == 3:
                raise
            time.sleep(2 * (attempt + 1))


def letters(s):
    s = re.sub(r"[ؐ-ًؚ-ٰٟۖ-ۭـ]", "", s)
    s = re.sub("[آأإٱ]", "ا", s)
    s = s.replace("ى", "ي").replace("ة", "ه")
    s = re.sub(r"[^ء-ي ]", " ", s)
    return re.sub(r"\s+", " ", s).strip()


# Words that tell the reader how often to say a dhikr; the book prints
# them, a recording does not have to say them.
COUNT_WORDS = {"ثلاث", "مرات", "مره", "مرتين", "عشر", "سبع", "مائه", "ميه",
               "اربع", "ثلاثا", "سبعا", "عشرا", "مائه"}


def skeleton(word):
    """A word without alif and hamza forms: the mushaf writes «وملئكته»,
    «مولينا», «ءامن» where the book writes «وملائكته», «مولانا», «آمن»."""
    return re.sub("[اءئؤيو]", "", word) or word


def same_words(a, b):
    """True when [a] and [b] say the same words, ignoring spelling and the
    printed repetition counts. Word ORDER counts («بالماء والثلج» is not
    «بالثلج والماء»), and so does any word more or less."""
    x = [skeleton(w) for w in a.split()]
    y = [skeleton(w) for w in b.split()]
    extra = {skeleton(w) for w in COUNT_WORDS}
    for op in difflib.ndiff(x, y):
        if op[0] in "+-" and op[2:] not in extra:
            return False
    return True


def main():
    API.mkdir(parents=True, exist_ok=True)
    index_path = API / "husn_ar.json"
    if not index_path.exists():
        index_path.write_text(get("https://www.hisnmuslim.com/api/ar/husn_ar.json"), encoding="utf-8")
    chapters = json.loads(index_path.read_text(encoding="utf-8"))["العربية"]
    remote = []  # (id, audio url, letters, chapter title)
    for ch in chapters:
        p = API / f"{ch['ID']}.json"
        if not p.exists():
            p.write_text(get(ch["TEXT"].replace("http://", "https://")), encoding="utf-8")
            time.sleep(0.3)
        body = json.loads(p.read_text(encoding="utf-8"))
        for items in body.values():
            for it in items:
                remote.append((it["ID"], it["AUDIO"].replace("http://", "https://"),
                               letters(it["ARABIC_TEXT"]), ch["TITLE"]))
    print(f"remote: {len(chapters)} chapters, {len(remote)} adhkar")

    db = sqlite3.connect(DB)
    local = list(db.execute("select i.id, i.body, s.title from azkar_items i "
                            "join azkar_sections s on s.id = i.section_id order by i.id"))
    pairs, lines, missing = {}, [], []
    for lid, body, title in local:
        want = letters(body)
        scored = sorted(((difflib.SequenceMatcher(None, want, r[2], autojunk=False).ratio(), r)
                         for r in remote), key=lambda x: -x[0])
        best, second = scored[0], scored[1]
        # The recording must say exactly this text (see same_words).
        ok = best[0] >= ACCEPT and same_words(want, best[1][2])
        line = f"{lid:4} {best[0]:.3f} (next {second[0]:.3f}) -> {best[1][0]} [{title} | {best[1][3]}]"
        if ok:
            pairs[lid] = best[1][1]
            lines.append("OK   " + line)
        else:
            missing.append(lid)
            lines.append("NONE " + line)

    # Every url must answer as audio before it is written.
    checked = {}
    for lid, url in list(pairs.items()):
        if url not in checked:
            try:
                status, ctype, data = get(url, binary=True, rng="bytes=0-1023")
                checked[url] = status in (200, 206) and ctype.startswith("audio") and len(data) > 0
            except Exception as e:  # a 404 is a missing recording, not a crash
                checked[url] = False
                lines.append(f"ERR  {url} {e}")
        if not checked[url]:
            missing.append(lid)
            lines.append(f"DEAD {lid} {url}")
            del pairs[lid]

    OUT.write_text(json.dumps({"source": "https://www.hisnmuslim.com (api/ar)",
                               "audio": {str(k): v for k, v in sorted(pairs.items())}},
                              ensure_ascii=False, indent=1), encoding="utf-8")
    REPORT.write_text("\n".join(lines) + f"\n\npaired {len(pairs)} of {len(local)}; "
                      f"without a recording: {sorted(set(missing))}\n", encoding="utf-8")
    print(f"paired {len(pairs)} of {len(local)}, without: {len(set(missing))}, urls checked: {len(checked)}")


if __name__ == "__main__":
    main()
