"""Take a modern editor's own work out of a hosted book, and MEASURE what is left.

`audit_editor_apparatus.py` answers «is the editor's apparatus in this file?».
This answers the next question: «if we take it out, is there still a book?»

It never uploads. It writes a cleaned copy and a report, so a human reads the
result and decides. A filter that over-reaches deletes the author instead of
the editor, and on scripture-adjacent text that is the worse failure of the
two — CLAUDE.md §1.2.

WHAT IT REMOVES, and why each rule exists
-----------------------------------------
1. Any paragraph containing «(*)». That is Shamela's footnote-area terminator.
   The mark has to be looked for ANYWHERE, not at the end: some paragraphs run
   an-Nawawi's sentence and the editor's note together and close «(*) =».
2. Any paragraph opening with «=». That is the footnote area continuing from
   the previous page — the same leading-equals the Musnad Ahmad crawl had to
   learn about, and requiring the «(١)» opening instead let 750 words of isnad
   criticism through in the azkar build.
3. Paragraphs in the editor's own voice — «قال أبو عبيدة», «قال المحقق»,
   «يعني النووي», «تحفة الأبرار» — because he signs his longer notes.
4. Whole TOC sections that are HIS, not the author's: «مقدمة المحقق»,
   «عملي في التحقيق», «توصيف النسخة الخطية», «صحة نسبة الكتاب». In
   «الإيجاز في شرح سنن أبي داود» the first EIGHT of fifty-nine sections are
   his introduction, which no paragraph-level rule would ever catch.

WHAT IT REPORTS, so the decision is made on evidence
----------------------------------------------------
How much text survives, how many pages come out empty, and the longest run of
consecutive empty pages. A book whose remainder is a scatter of fragments is
not a book any more, and should be removed rather than shipped hollow — the
printed page 51 of al-Ijaz is «. . . . . . .» because that whole leaf is
footnote.

    py -3 strip_editor_apparatus.py --book al_ijaz_fi_sharh_sunan_abi_dawud
    py -3 strip_editor_apparatus.py --all        # every book the audit flagged
"""

import argparse
import gzip
import io
import json
import os
import re
import sys
import urllib.request

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")

BASE = "https://pub-39dbef68a1a845d5ba669b43a59516b9.r2.dev"
UA = "RafeeqAlDarb/3.30 (https://github.com/tito423/Rafeeq-Al-Darb) curl/8"
OUT_DIR = "_stripped"

AR = "٠١٢٣٤٥٦٧٨٩"
FOOT_OPEN = re.compile(r"^\(\s*[" + AR + r"]+\s*\)")
FOOT_TAIL = re.compile(r"رواه .{0,40}رقم \(|في المسند \d|/ \d+ من حديث")
EDITOR_VOICE = re.compile(
    r"قال أبو عبيدة|قال المحقق|قال المحققون|قال معد الكتاب|"
    r"يعني النووي|يعني المصنف|المصنف رحمه الله|تحفة الأبرار"
)
# A chapter that belongs to the editor rather than the author.
EDITOR_SECTION = re.compile(
    r"مقدمة المحقق|عملي في التحقيق|توصيف النسخة|النسخة الخطية|"
    r"صحة نسبة الكتاب|منهج التحقيق|شكر وتقدير|فهرس المصادر|"
    r"المصادر والمراجع|ترجمة المحقق"
)
# A matn line that the printing itself left as dots because the leaf is all
# footnote — carrying it over would be shipping a row of full stops.
DOTS = re.compile(r"^[\s.·،]+$")
MARKER = re.compile(r"\s*\(\s*[" + AR + r"]+\s*\)\s*")


def load(bid):
    req = urllib.request.Request("%s/books/text/%s.json" % (BASE, bid),
                                 headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=300) as r:
        raw = r.read()
    if raw[:2] == b"\x1f\x8b":
        raw = gzip.decompress(raw)
    return json.loads(raw.decode("utf-8"))


def is_editor_para(t):
    if "(*)" in t:
        return "(*)"
    if t.startswith("=") or t.startswith("؟ ="):
        return "="
    if FOOT_OPEN.match(t) and FOOT_TAIL.search(t):
        return "(N)+takhrij"
    if EDITOR_VOICE.search(t):
        return "editor voice"
    return None


def editor_section_pages(doc):
    """Page numbers covered by the editor's own chapters, from the TOC."""
    toc = doc.get("toc") or []
    pages = set()
    for i, t in enumerate(toc):
        if not EDITOR_SECTION.search(t.get("title", "")):
            continue
        start = t.get("page")
        end = toc[i + 1].get("page") if i + 1 < len(toc) else None
        if start is None:
            continue
        for p in (pg["p"] for pg in doc["pages"]):
            if p >= start and (end is None or p < end):
                pages.add(p)
    return pages


def strip(doc):
    drop_pages = editor_section_pages(doc)
    stats = {"(*)": 0, "=": 0, "(N)+takhrij": 0, "editor voice": 0,
             "editor section": 0, "dots": 0, "markers": 0}
    chars_before = chars_after = 0
    pages_out, empties = [], []
    for pg in doc["pages"]:
        kept = []
        for para in pg["paras"]:
            t = (para.get("t") or "").strip()
            if not t:
                continue
            chars_before += len(t)
            if pg["p"] in drop_pages:
                stats["editor section"] += 1
                continue
            hit = is_editor_para(t)
            if hit:
                stats[hit] += 1
                continue
            if DOTS.match(t):
                stats["dots"] += 1
                continue
            cleaned, n = MARKER.subn(" ", t)
            stats["markers"] += n
            cleaned = re.sub(r"\s+", " ", cleaned).strip()
            if not cleaned:
                continue
            chars_after += len(cleaned)
            kept.append({"t": cleaned, "k": para.get("k", "body")})
        if kept:
            pages_out.append({"p": pg["p"], "paras": kept})
        else:
            empties.append(pg["p"])
    # WHERE an empty run sits is the whole question, and the first version of
    # this report missed it. A run at the FRONT means the editor's own
    # introduction was removed and the author's book now starts where he starts
    # — which is exactly right. A run in the MIDDLE means the book has been
    # gutted and a reader will page into nothing. `juz_bay_ummahat_al_awlad`
    # loses 24 consecutive pages and keeps 82.7% of its text; those two numbers
    # only make sense together once you know the 24 are at the front.
    first_p = doc_pages[0] if (doc_pages := [pg["p"] for pg in doc["pages"]]) else 0
    last_p = doc_pages[-1] if doc_pages else 0
    kept_set = {pg["p"] for pg in pages_out}
    lead = 0
    for p in doc_pages:
        if p in kept_set:
            break
        lead += 1
    trail = 0
    for p in reversed(doc_pages):
        if p in kept_set:
            break
        trail += 1
    interior = [p for p in empties
                if doc_pages.index(p) >= lead
                and doc_pages.index(p) < len(doc_pages) - trail]
    longest_interior = run = 0
    prev = None
    for p in interior:
        run = run + 1 if prev is not None and p == prev + 1 else 1
        longest_interior = max(longest_interior, run)
        prev = p
    longest = run = 0
    prev = None
    for p in empties:
        run = run + 1 if prev is not None and p == prev + 1 else 1
        longest = max(longest, run)
        prev = p
    stats["_lead"] = lead
    stats["_trail"] = trail
    stats["_interior"] = len(interior)
    stats["_longest_interior"] = longest_interior
    return pages_out, empties, longest, stats, chars_before, chars_after


def process(bid, report):
    doc = load(bid)
    pages, empties, longest, stats, cb, ca = strip(doc)
    kept_pct = 100.0 * ca / cb if cb else 0
    meta = doc.get("meta", {})
    report.write("\n%s\n" % ("=" * 78))
    report.write("%s\n" % bid)
    report.write("  «%s»\n" % meta.get("titleAr", ""))
    report.write("  %s\n" % meta.get("editionCard", "").replace("\n", " | "))
    report.write("  pages %d -> %d   (%d come out EMPTY, longest empty run %d)\n"
                 % (len(doc["pages"]), len(pages), len(empties), longest))
    report.write("  text kept: %.1f%%  (%d -> %d characters)\n"
                 % (kept_pct, cb, ca))
    report.write("  empty at the FRONT: %d (the editor's own introduction) · "
                 "at the BACK: %d · INSIDE the book: %d, longest run %d\n"
                 % (stats["_lead"], stats["_trail"], stats["_interior"],
                    stats["_longest_interior"]))
    report.write("  removed: %s\n" % ", ".join(
        "%s=%d" % (k, v) for k, v in stats.items() if v and not k.startswith("_")))
    # The author's text has to survive, and a reader must not page into
    # nothing in the middle of it. Front matter that was the editor's is
    # SUPPOSED to disappear, so it is not counted against the book.
    if kept_pct >= 85 and stats["_longest_interior"] <= 2:
        verdict = "FILTER — the author's book survives intact"
    elif kept_pct >= 70 and stats["_longest_interior"] <= 4:
        verdict = "FILTER, then read the gaps"
    else:
        verdict = "READ IT — the remainder may not be a book any more"
    report.write("  -> %s\n" % verdict)
    for pg in pages[:2]:
        report.write("  first page kept (p%s): %s\n"
                     % (pg["p"], " | ".join(x["t"] for x in pg["paras"])[:300]))
    os.makedirs(OUT_DIR, exist_ok=True)
    doc["pages"] = pages
    doc.setdefault("meta", {})["strippedBy"] = "scripts/strip_editor_apparatus.py"
    json.dump(doc, io.open(os.path.join(OUT_DIR, bid + ".json"), "w",
                           encoding="utf-8"), ensure_ascii=False)
    return kept_pct, longest, verdict


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--book")
    ap.add_argument("--all", action="store_true")
    ap.add_argument("--audit", default="_editor_apparatus.json")
    ap.add_argument("--report", default="_stripped_report.txt")
    args = ap.parse_args()

    if args.all:
        rows = json.load(open(args.audit, encoding="utf-8"))
        ids = [r["id"] for r in rows
               if r.get("verdict") == "MODERN_EDITOR_APPARATUS_PRESENT"]
    else:
        ids = [args.book]

    with io.open(args.report, "w", encoding="utf-8") as r:
        r.write("Nothing here is uploaded. Read the report, then decide.\n")
        for bid in ids:
            try:
                process(bid, r)
            except Exception as exc:                # noqa: BLE001 - reported
                r.write("\n%s\n  FAILED: %s\n" % (bid, str(exc)[:120]))
    print("->", args.report)


if __name__ == "__main__":
    main()
