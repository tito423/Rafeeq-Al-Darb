"""Build a local index of every book in al-Maktaba al-Shamela, by category.

Shamela's own search (`POST /ajax/search`) searches *inside* books, not their
titles — asking it for «الرحيق المختوم» returns a commentary *on* al-Raheeq
before al-Raheeq itself, which is exactly how a session ends up cataloguing the
wrong book id. The category listings, on the other hand, are one page each and
carry every book's id and title.

So: fetch the 40 category pages once, keep them, and search the result locally
as often as needed. One pass over someone else's server instead of a query per
title.

    py -3 scripts/shamela_index.py build      # fetch/refresh the index
    py -3 scripts/shamela_index.py find "الرحيق المختوم" ["..." ...]

Results are written to a UTF-8 file as well as stdout, because the Windows
console is cp1256 and raises UnicodeEncodeError on Arabic.
"""

import io
import json
import os
import re
import sys
import time
import urllib.request

ROOT = os.path.dirname(os.path.abspath(__file__))
INDEX = os.path.join(ROOT, "shamela_index.json")
OUT = os.path.join(ROOT, "shamela_find_out.txt")

UA = {"User-Agent": "Mozilla/5.0 (rafeeq-al-darb content pipeline)"}

# id -> name, read off shamela.ws's own home page.
CATEGORIES = {
    1: "العقيدة", 2: "الفرق والردود", 3: "التفسير",
    4: "علوم القرآن وأصول التفسير", 5: "التجويد والقراءات", 6: "كتب السنة",
    7: "شروح الحديث", 8: "التخريج والأطراف", 9: "العلل والسؤلات الحديثية",
    10: "علوم الحديث", 11: "أصول الفقه", 12: "علوم الفقه والقواعد الفقهية",
    13: "المنطق", 14: "الفقه الحنفي", 15: "الفقه المالكي", 16: "الفقه الشافعي",
    17: "الفقه الحنبلي", 18: "الفقه العام", 19: "مسائل فقهية",
    20: "السياسة الشرعية والقضاء", 21: "الفرائض والوصايا", 22: "الفتاوى",
    23: "الرقائق والآداب والأذكار", 24: "السيرة النبوية", 25: "التاريخ",
    26: "التراجم والطبقات", 27: "الأنساب", 28: "البلدان والرحلات",
    29: "كتب اللغة", 30: "الغريب والمعاجم", 31: "النحو والصرف", 32: "الأدب",
    33: "العروض والقوافي", 34: "الشعر ودواوينه", 35: "البلاغة", 36: "الجوامع",
    37: "فهارس الكتب والأدلة", 38: "الطب", 39: "كتب عامة", 40: "علوم أخرى",
}


def fetch(url, tries=4):
    req = urllib.request.Request(url, headers=UA)
    for i in range(tries):
        try:
            with urllib.request.urlopen(req, timeout=90) as r:
                return r.read().decode("utf-8", "replace")
        except Exception:
            if i == tries - 1:
                raise
            time.sleep(2 * (i + 1))


def build():
    index = {}
    if os.path.exists(INDEX):
        index = json.loads(io.open(INDEX, encoding="utf-8").read())
    for cid, cname in CATEGORIES.items():
        key = str(cid)
        if key in index and index[key]["books"]:
            print(f"{cid:>3} {cname}: cached ({len(index[key]['books'])})")
            continue
        html = fetch(f"https://shamela.ws/category/{cid}")
        pairs = re.findall(
            r'href="https://shamela\.ws/book/(\d+)"[^>]*>(.{0,200}?)</a>', html, re.S
        )
        books, seen = [], set()
        for bid, label in pairs:
            label = re.sub(r"<[^>]+>", " ", label)
            label = re.sub(r"\s+", " ", label).strip()
            if bid in seen or not label:
                continue
            seen.add(bid)
            books.append({"id": bid, "title": label})
        index[key] = {"name": cname, "books": books}
        print(f"{cid:>3} {cname}: {len(books)}")
        with io.open(INDEX, "w", encoding="utf-8") as f:
            json.dump(index, f, ensure_ascii=False, indent=1)
        time.sleep(0.6)  # polite to a public library's server
    total = sum(len(v["books"]) for v in index.values())
    print(f"\n{total} books indexed -> {INDEX}")


_DIACRITICS = re.compile(r"[ً-ْٰـ]")


def norm(s):
    """The project's usual Arabic fold: strip tashkeel, unify alef/ya/ta."""
    s = _DIACRITICS.sub("", s)
    return (
        s.replace("أ", "ا").replace("إ", "ا").replace("آ", "ا")
        .replace("ى", "ي").replace("ة", "ه")
    )


def find(terms):
    if not os.path.exists(INDEX):
        raise SystemExit("build the index first: py -3 scripts/shamela_index.py build")
    index = json.loads(io.open(INDEX, encoding="utf-8").read())
    lines = []
    for term in terms:
        lines.append(f"===== {term} =====")
        n = norm(term)
        hits = []
        for cat in index.values():
            for b in cat["books"]:
                if n in norm(b["title"]):
                    hits.append((b["id"], b["title"], cat["name"]))
        if not hits:
            lines.append("  (not found in the Shamela index)")
        for bid, title, cat in hits[:25]:
            lines.append(f"  {bid:>7}  {title}   [{cat}]")
        lines.append("")
    text = "\n".join(lines)
    with io.open(OUT, "w", encoding="utf-8") as f:
        f.write(text)
    print(f"wrote {OUT}")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        raise SystemExit(__doc__)
    if sys.argv[1] == "build":
        build()
    elif sys.argv[1] == "find":
        find(sys.argv[2:])
    else:
        raise SystemExit(__doc__)
