"""The Hajj guide's source text: «الحج والعمرة» from الفقه المنهجي.

    py -3 scripts/fetch_shamela_pages.py 6369 1678 scripts/shamela_raw/al_fiqh_al_manhaji.jsonl
    py -3 scripts/build_hajj_guide_book.py

«ابني من الحديث وسيب النووي في المكتبة» (the owner, 2026-09-23): the guide
moves off al-Nawawi's «الإيضاح» onto a modern manual. الفقه المنهجي على مذهب
الإمام الشافعي (الخن، البغا، الشربجي؛ دار القلم ١٤١٣هـ) was chosen because
it is written for the ordinary reader, speaks of today («وهو ما يسمى الآن
بأبيار علي», the ihram of an air traveller), stays in al-Nawawi's school so
the guide's fiqh does not change under the reader, and names none of the
authors the owner keeps out. Read before it was chosen: Shamela page ids
369-445 (vol. 2, printed pp. 111-188) are the whole chapter, with no editor's
hamesh.

This writes ONLY that chapter, verbatim, as a bundled book the guide slices
by printed page and paragraph index (hajj_guide.dart). Paragraphs are split
exactly as build_book_text.py splits every other book, so the indices the
guide uses are the indices a reader of the file sees.
"""
import gzip
import io
import json
import os
import sys
from datetime import datetime, timezone

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import build_book_text as b  # noqa: E402

ROOT = os.path.dirname(HERE)
RAW = os.path.join(HERE, "shamela_raw", "al_fiqh_al_manhaji.jsonl")
OUT = os.path.join(ROOT, "rafeeq_app", "assets", "data", "builtin_books",
                   "al_fiqh_al_manhaji_hajj.json")
SHAMELA_ID = 6369
FIRST, LAST = 369, 445  # page ids: «الحج والعمرة» .. the end of «كيف تحج؟»


def main():
    raw = {}
    for line in io.open(RAW, encoding="utf-8"):
        d = json.loads(line)
        raw[int(d["pageId"])] = d
    missing = [i for i in range(FIRST, LAST + 1) if i not in raw]
    if missing:
        sys.exit(f"pages not crawled: {missing}")
    if "حج" not in (raw[FIRST].get("title") or ""):
        sys.exit("page 369 is not the Hajj chapter's opening - the ids moved")

    card = b.fetch_meta_card(SHAMELA_ID)
    pages, toc, last = [], [], None
    for pid in range(FIRST, LAST + 1):
        d = raw[pid]
        title = (d.get("title") or "").strip()
        printed = int(d.get("pageNum") or 0)
        if title and title != last:
            toc.append({"title": title, "page": printed,
                        "pageIndex": len(pages), "level": 1})
        last = title or last
        pages.append({"p": printed, "paras": b.parse_nass(d.get("nass") or "")})

    printed = [p["p"] for p in pages]
    if printed != sorted(printed) or len(set(printed)) != len(printed):
        sys.exit("printed pages are not one increasing run - the guide "
                 "addresses paragraphs by printed page")

    doc = {
        "id": "al_fiqh_al_manhaji_hajj",
        "schema": 1,
        "meta": {
            "titleAr": "الحج والعمرة — من الفقه المنهجي على مذهب الإمام الشافعي",
            "authorAr": card["author"] or "مصطفى الخن، مصطفى البغا، علي الشربجي",
            "sourceLabel": "المكتبة الشاملة — الفقه المنهجي على مذهب الإمام "
                           "الشافعي، دار القلم، دمشق، الطبعة الرابعة ١٤١٣هـ، "
                           "الجزء الثاني ص١١١-١٨٨",
            "shamelaId": SHAMELA_ID,
            "shamelaUrl": f"https://shamela.ws/book/{SHAMELA_ID}",
            "printMatches": card["print_matches"],
            "printReliable": True,
            "editionCard": card["card"],
            "excerpt": f"page ids {FIRST}-{LAST}: the chapter «الحج والعمرة»",
            "pageCount": len(pages),
            "sectionCount": len(toc),
            "builtAt": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "builtFrom": "scripts/build_hajj_guide_book.py",
        },
        "toc": toc,
        "pages": pages,
    }
    body = json.dumps(doc, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    data = gzip.compress(body, mtime=0)
    open(OUT, "wb").write(data)
    paras = sum(len(p["paras"]) for p in pages)
    print(f"wrote {OUT}: {len(pages)} pages (p{printed[0]}-{printed[-1]}), "
          f"{paras} paragraphs, {len(data)} B gzip")


if __name__ == "__main__":
    main()
