"""Library «المرحلة ٢» (2026-09-23): the encyclopaedias into the app.

The owner's rulings for this batch (see the memory note and
CONTENT-LICENSES.md): no bare mutun — the explained book instead; Shamela text
may be taken as served; every existing imam's book stays; and the seven names
he took out on 2026-09-17 stay out (ابن باز، ابن عثيمين، ابن تيمية، ابن جبرين،
ابن عبد الوهاب، الألباني، القرني).

For every book, in this order, stopping on the first failure:
  1. its printed card (kept by build_book_text.py) is read, and the book is
     REFUSED if one of the seven names appears on it — an editor, a حاشية, a
     تعليق printed with the book is exactly how a name comes back in;
  2. the built file is uploaded (gzip, no Content-Encoding — trap #6);
  3. the public URL is read back with a User-Agent (trap #19) and must answer
     with gzip's magic bytes at the uploaded size (§1.1);
  4. its entry is written into book_catalog.dart.

Titles, English names, death years and shelves are this table's; the edition
wording in each sourceLabel is the card's own.

    py -3 scripts/library_phase2.py [--report]
"""
import gzip
import io
import json
import os
import re
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from r2_common import BUCKET, r2_client  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BUILD = os.path.join(ROOT, "scripts", "book_text_build")
CATALOG = os.path.join(ROOT, "rafeeq_app", "lib", "features", "library", "data",
                       "book_catalog.dart")
PUBLIC = "https://pub-39dbef68a1a845d5ba669b43a59516b9.r2.dev"
UA = "RafeeqAlDarb/3.56 (https://github.com/tito423/Rafeeq-Al-Darb) curl/8"
REPORT = os.path.join(ROOT, "scripts", "library_phase2_out.txt")

SEVEN = ["ابن باز", "بن باز", "عثيمين", "ابن تيمية", "بن تيمية", "جبرين",
         "عبد الوهاب", "عبدالوهاب", "الألباني", "الالباني", "القرني"]
# On a card a bare «عبد الوهاب» is a namesake far more often than not — fath
# al-qarib's editor is «بسام عبد الوهاب الجابي» — so the card test names the
# man; the body count above still reports every bare hit for a human to read.
CARD_NAMES = [n for n in SEVEN if n not in ("عبد الوهاب", "عبدالوهاب")] + [
    "ابن عبد الوهاب", "محمد بن عبد الوهاب", "ابن عبدالوهاب", "محمد بن عبدالوهاب"]

# id -> (titleAr, titleEn, authorAr, authorEn, deathAH, category, shelfOrder)
#
# The nine encyclopaedias, cleared for size by measuring البداية والنهاية
# (4.9 MB, 4,918 pages) on the owner's phone: 7.5 s to download and index,
# 4.3 s to open, ~5 s to the last page, Java heap flat at 10 MB (trap #4).
PLAN = {
    "tafsir_al_tabari": ("جامع البيان عن تأويل آي القرآن", "Tafsir al-Tabari",
        "الإمام ابن جرير الطبري", "Ibn Jarir al-Tabari", 310, "tafsir", 0),
    "tafsir_al_qurtubi": ("الجامع لأحكام القرآن", "Tafsir al-Qurtubi",
        "الإمام القرطبي", "Al-Qurtubi", 671, "tafsir", 0),
    "fath_al_bari": ("فتح الباري بشرح صحيح البخاري", "Fath al-Bari",
        "الحافظ ابن حجر العسقلاني", "Ibn Hajar al-Asqalani", 852, "hadith", 0),
    "al_mughni_ibn_qudamah": ("المغني", "Al-Mughni",
        "الإمام موفق الدين ابن قدامة المقدسي", "Ibn Qudamah al-Maqdisi", 620, "fiqh", 0),
    "al_majmu_sharh_al_muhadhdhab": ("المجموع شرح المهذب", "Al-Majmu Sharh al-Muhadhdhab",
        "الإمام محيي الدين النووي", "Imam al-Nawawi", 676, "fiqh", 0),
    "ilam_al_muwaqqiin": ("إعلام الموقعين عن رب العالمين", "Ilam al-Muwaqqiin",
        "الإمام ابن قيّم الجوزية", "Ibn Qayyim al-Jawziyyah", 751, "fiqh", 0),
    "siyar_alam_al_nubala": ("سير أعلام النبلاء", "Siyar Alam al-Nubala",
        "الإمام شمس الدين الذهبي", "Al-Dhahabi", 748, "seerah", 0),
    "tahdhib_al_kamal": ("تهذيب الكمال في أسماء الرجال", "Tahdhib al-Kamal",
        "الحافظ جمال الدين المزي", "Al-Mizzi", 742, "hadith", 0),
    "lisan_al_arab": ("لسان العرب", "Lisan al-Arab",
        "ابن منظور الإفريقي", "Ibn Manzur", 711, "talibIlm", 0),
}

# The bare mutun leaving the shelf, replaced by the two shuruh above.
RETIRED = []  # nothing leaves the shelf for these


def card_field(card, name):
    m = re.search(rf"^{name}:\s*(.+)$", card, re.M)
    return m.group(1).strip() if m else ""


def load(book_id):
    raw = open(os.path.join(BUILD, book_id + ".json"), "rb").read()
    return raw, json.loads(gzip.decompress(raw) if raw[:2] == b"\x1f\x8b" else raw)


# Shamela prints a matn-over-sharh edition (al-Ikhtiyar, al-Fawakih, al-Uddah,
# Ihkam al-Ahkam, …) as: the matn, a «ــ» rule, then the book's name as a
# running head, then the sharh. A page with no matn keeps a row of full stops
# where the matn would be. Measured 2026-09-22: 659 running heads «إحكام
# الأحكام» and 248 rows of dots in Ihkam alone. None of it is text; a reader
# paging through would see «. . . . . ــ إحكام الأحكام» on every page.
DOTS = re.compile(r"^[\s.·،]+$")
RULE = re.compile(r"^[\sـ_\-–—]+$")
# A footnote's number left standing on its own line once build_book_text.py
# has dropped the hamesh it pointed to: «١ -», 246 of them in al-Fawakih.
ORPHAN = re.compile(r"^\s*\(?[0-9٠-٩]+\)?\s*[-–]\s*$")


def tidy(book):
    """Drop dot rows, a running head repeated after the rule on most pages,
    and a rule with no matn above it. Returns what was dropped."""
    text = lambda p: p["t"] if isinstance(p, dict) else p
    after = {}
    for pg in book["pages"]:
        ps = [text(p) for p in pg["paras"]]
        for j, t in enumerate(ps[:-1]):
            if RULE.match(t):
                after[ps[j + 1]] = after.get(ps[j + 1], 0) + 1
    head = max(after, key=after.get) if after else None
    if head is None or after[head] < 0.5 * len(book["pages"]) or len(head) > 60:
        head = None
    n = {"dots": 0, "head": 0, "rule": 0, "orphan": 0}
    for pg in book["pages"]:
        kept = []
        for p in pg["paras"]:
            t = text(p)
            if DOTS.match(t):
                n["dots"] += 1
                continue
            if ORPHAN.match(t):
                n["orphan"] += 1
                continue
            if head and t == head and kept and RULE.match(text(kept[-1])):
                n["head"] += 1
                continue
            kept.append(p)
        out = []
        for j, p in enumerate(kept):
            if RULE.match(text(p)) and not out:
                n["rule"] += 1  # nothing above it on this page
                continue
            out.append(p)
        pg["paras"] = out
    # A page whose only line was an orphan «١ -» is empty now, and the reader
    # would page into a blank leaf (7 in al-Rawd, Rakaiz). Drop it, and move
    # each TOC entry to where its page went — the app trusts `pageIndex`
    # first — or to the next page that survived.
    keep = [i for i, pg in enumerate(book["pages"]) if pg["paras"]]
    if len(keep) < len(book["pages"]):
        new_at, j = {}, 0
        for i in range(len(book["pages"])):
            while j < len(keep) - 1 and keep[j] < i:
                j += 1
            new_at[i] = j
        for e in book.get("toc") or []:
            e["pageIndex"] = new_at.get(e.get("pageIndex", 0), 0)
        n["empty pages"] = len(book["pages"]) - len(keep)
        book["pages"] = [book["pages"][i] for i in keep]
        book["meta"]["pageCount"] = len(book["pages"])
    return n


def public_ok(book_id, size):
    url = f"{PUBLIC}/books/text/{book_id}.json"
    head = subprocess.run(["curl", "-sSI", "-A", UA, url], capture_output=True, text=True).stdout
    first = subprocess.run(["curl", "-sS", "-A", UA, "-r", "0-1", url], capture_output=True).stdout
    length = re.search(r"Content-Length:\s*(\d+)", head, re.I)
    enc = re.search(r"Content-Encoding", head, re.I)
    return (first[:2] == b"\x1f\x8b" and length and int(length.group(1)) == size and not enc)


def dart_str(s):
    return "'" + s.replace("\\", "\\\\").replace("'", "\\'").replace("$", "\\$") + "'"


# Built but NOT to be catalogued until the reason is dealt with. Read from the
# report's name hits in context, 2026-09-23.
HOLD = {}

# Text in the body stream that is not the author's and falls under the owner's
# rule «لا شيء لابن باز … إلا التخريج». Each passage is found by its OWN
# words - the line it opens with and the signature it closes with - never by
# a page index, so a rebuilt crawl cannot shift the cut onto the author.
# `expect` is the number of (passages, pages) the book must yield, or the run
# stops: a cut that finds more or less than was read by hand is not trusted.
NOT_THE_AUTHOR = {
    # The Salafiyya edition: Ibn Baz's preface (vol. 1 pp. 3-4, «حرر في ٢١
    # من شعبان سنة ١٣٧٩ هـ») and his «تنبيه واعتذار» closing vol. 3 (p. 625).
    # The publisher's closing word on the book's last page MENTIONS him and
    # is not his; it stays (the similar-names rule).
    "fath_al_bari": {
        "passages": [
            ("أما بعد فإنه لما قلت النسخ المطبوعة من فتح الباري",
             "عبد العزيز بن عبد الله بن باز"),
            ("تنبيه واعتذار", "عبد العزيز بن عبد الله بن باز"),
        ],
        "expect": (2, 3),
        "why": "Ibn Baz's preface to the Salafiyya edition and his note "
               "closing vol. 3 - the owner's rule admits nothing of his "
               "but takhrij",
    },
}


def cut_not_the_author(book_id, book):
    """Empty the pages of each NOT_THE_AUTHOR passage (tidy() then drops them
    and re-points the TOC). Returns the pages cut, or exits on a mismatch."""
    spec = NOT_THE_AUTHOR.get(book_id)
    if not spec:
        return 0
    text = lambda p: p["t"] if isinstance(p, dict) else p
    pages = book["pages"]
    # tidy() writes the build file back, so a --report run has already made
    # the cut: then every opener must be GONE, and there is nothing to do.
    if book["meta"].get("notTheAuthorRemoved"):
        for opener, _ in spec["passages"]:
            if any(text(p).startswith(opener) for pg in pages for p in pg["paras"]):
                sys.exit(f"{book_id}: marked as cut but «{opener}» is still there")
        return 0
    found, cut = 0, 0
    for opener, signature in spec["passages"]:
        for i, pg in enumerate(pages):
            if not any(text(p).startswith(opener) for p in pg["paras"]):
                continue
            end = next((k for k in range(i, min(i + 3, len(pages)))
                        if any(signature in text(p) for p in pages[k]["paras"])),
                       None)
            if end is None:
                sys.exit(f"{book_id}: «{opener}» has no «{signature}» within "
                         "three pages - not cutting blind")
            for k in range(i, end + 1):
                pages[k]["paras"] = []
                cut += 1
            found += 1
    if (found, cut) != spec["expect"]:
        sys.exit(f"{book_id}: cut {found} passages / {cut} pages, expected "
                 f"{spec['expect']} - read the book again before trusting it")
    book["meta"]["notTheAuthorRemoved"] = spec["why"]
    return cut


def main():
    report = "--report" in sys.argv
    out = io.open(REPORT, "w", encoding="utf-8")
    entries, refused = [], []
    # Phase 2 lands in batches as the crawls finish, so the same run may be
    # made twice: a book already in the catalogue is left alone rather than
    # written in twice.
    catalogue = io.open(CATALOG, encoding="utf-8").read()
    for book_id, (t_ar, t_en, a_ar, a_en, death, cat, shelf) in PLAN.items():
        if f"id: '{book_id}'" in catalogue:
            refused.append((book_id, "already catalogued"))
            continue
        if book_id in HOLD:
            refused.append((book_id, "held: " + HOLD[book_id]))
            continue
        path = os.path.join(BUILD, book_id + ".json")
        if not os.path.exists(path):
            refused.append((book_id, "not built"))
            continue
        raw, book = load(book_id)
        cut = cut_not_the_author(book_id, book)
        dropped = tidy(book)
        if cut:
            dropped["not the author"] = cut
        if any(dropped.values()):
            book["meta"]["tidiedBy"] = "scripts/library_phase2.py"
            raw = gzip.compress(json.dumps(book, ensure_ascii=False, separators=(",", ":"))
                                .encode("utf-8"), mtime=0)
            open(path, "wb").write(raw)
            out.write(f"\n   tidied {book_id}: {dropped}")
        meta = book["meta"]
        card = meta.get("editionCard", "")
        hit = [n for n in CARD_NAMES if n in card]
        body = " ".join(p["t"] if isinstance(p, dict) else p
                        for pg in book["pages"] for p in pg["paras"])
        mentions = {n: body.count(n) for n in SEVEN if body.count(n)}
        out.write(f"\n== {book_id}  ({len(raw)} B, {meta['pageCount']} pages)\n{card}\n"
                  f"  seven-names on card: {hit or 'none'}\n"
                  f"  seven-names in text: {mentions or 'none'}\n")
        if hit:
            refused.append((book_id, "card names " + ", ".join(hit)))
            continue
        label = "المكتبة الشاملة — " + "، ".join(x for x in (
            card_field(card, "الكتاب"), card_field(card, "المؤلف"),
            card_field(card, "الناشر"), card_field(card, "الطبعة")) if x)
        entries.append((book_id, t_ar, t_en, a_ar, a_en, death, cat, shelf, len(raw), label))
    out.write("\nREFUSED: " + (", ".join(f"{b} ({why})" for b, why in refused) or "none") + "\n")
    out.close()
    print(io.open(REPORT, encoding="utf-8").read())
    if report:
        return

    s3 = r2_client()
    for e in entries:
        body = open(os.path.join(BUILD, e[0] + ".json"), "rb").read()
        s3.put_object(Bucket=BUCKET, Key=f"books/text/{e[0]}.json", Body=body,
                      ContentType="application/json")
        if not public_ok(e[0], len(body)):
            sys.exit(f"{e[0]}: public endpoint did not return the uploaded bytes")
        print("uploaded + verified", e[0], len(body))

    src = io.open(CATALOG, encoding="utf-8").read()
    for rid in RETIRED:
        src, n = re.subn(
            r"\n  // [^\n]*\n  LibraryBook\(\n    id: '" + rid + r"',.*?\n  \),"
            r"|\n  LibraryBook\(\n    id: '" + rid + r"',.*?\n  \),",
            "", src, count=1, flags=re.S)
        print("retired", rid, n)
    header = "  // ── 2026-09-23 — library «المرحلة ٢»: the encyclopaedias, per the owner's"
    # Written once: every later batch appends under the header already there.
    lines = [""] if header in src else ["", header,
                                      "  // rulings. scripts/library_phase2.py."]
    for (bid, t_ar, t_en, a_ar, a_en, death, cat, shelf, size, label) in entries:
        lines += [
            "  LibraryBook(",
            f"    id: {dart_str(bid)},",
            f"    titleAr: {dart_str(t_ar)},",
            f"    titleEn: {dart_str(t_en)},",
            f"    authorAr: {dart_str(a_ar)},",
            f"    authorEn: {dart_str(a_en)},",
        ]
        if death:
            lines.append(f"    deathYearAh: {death},")
        # The reader's own page count: the generated blurb needs one (a book
        # with neither blurb nor count renders a blank line).
        lines.append(f"    pages: {len(load(bid)[1]['pages'])},")
        lines.append(f"    category: BookCategory.{cat},")
        if shelf:
            lines.append(f"    shelfOrder: {shelf},")
        lines += [
            "    textEdition: TextEdition(",
            "      url:",
            f"          '${{AppConfig.contentBaseUrl}}/books/text/{bid}.json',",
            f"      sizeBytes: {size},",
            "      editorNotesRemoved: true,",
            f"      sourceLabel: {dart_str(label)},",
            "    ),",
            "  ),",
        ]
    # The END of libraryBookCatalog, not of the file: the file ends in
    # `_byId[id];`, which a bare rindex("];") took for it on 2026-09-22.
    end = src.index("\n];\n", src.index("libraryBookCatalog"))
    src = src[:end].rstrip() + "\n" + "\n".join(lines) + "\n" + src[end:]
    io.open(CATALOG, "w", encoding="utf-8", newline="\n").write(src)
    print(f"catalogue: +{len(entries)} books, -{len(RETIRED)} mutun")


if __name__ == "__main__":
    main()
