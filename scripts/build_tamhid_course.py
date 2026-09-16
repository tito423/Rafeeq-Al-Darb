"""Cut «التمهيد في علم التجويد» into the third level's lessons.

ابن الجزري (ت ٨٣٣ هـ) wrote the matn the second level teaches and then this,
the prose that explains it — which is why the ladder ends here: تحفة الأطفال,
then his الجزرية, then his own commentary on the same science.

WHAT THE TABLE OF CONTENTS SAYS ABOUT THE EDITOR. Unlike the Jazariyyah's
printing, this one's forty-three entries are ALL the author's: they open at
«مقدمة ابن الجزري» on printed page 39 and close at «باب في معرفة الظاء» on
209. د. علي حسين البواب's own introduction occupies the pages before 39, and
the build never fetched them — the first page of the `pages` array is the
author's first page. Checked, not assumed.

The lessons follow his own أبواب. Where a باب has فصول they stay inside it
rather than becoming lessons of their own: «الباب السابع في ذكر ألقاب الحروف»
is one lesson with its four فصول, because that is one sitting.

    py -3 scripts/build_tamhid_course.py [--report]
"""

import gzip
import io
import json
import os
import re
import sys
import urllib.request

BOOK = "at_tamhid_fi_ilm_at_tajwid"
URL = (
    "https://pub-39dbef68a1a845d5ba669b43a59516b9.r2.dev/books/text/%s.json" % BOOK
)
UA = {"User-Agent": "RafeeqAlDarb/3.26 (https://github.com/tito423/Rafeeq-Al-Darb)"}

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DART = os.path.join(
    ROOT, "rafeeq_app", "lib", "features", "tajweed", "data", "tamhid_course.dart"
)
REPORT = os.path.join(ROOT, "scripts", "tamhid_course_out.txt")

# Each lesson is a span of TOC entry indices, inclusive, and the spans are his
# own أبواب: a باب keeps its فصول rather than letting each one become a
# lesson, because that is one sitting. All 43 entries are used — this printing
# has no front or back matter inside the fetched pages, and the build never
# fetched د. علي حسين البواب's introduction, which sits before page 39.
LESSONS = [
    (0, 0, "مقدمة ابن الجزري"),
    (1, 2, "الباب الأول: قراءة القراء في هذا الزمان"),
    (3, 7, "الباب الثاني: معنى التجويد والتحقيق والترتيل"),
    (8, 8, "الباب الثالث: أصول القراءة"),
    (9, 10, "الباب الرابع: اللحن وأقسامه"),
    (11, 13, "الباب الخامس: ألفات الوصل والقطع"),
    (14, 16, "الباب السادس: الحركات والحروف"),
    (17, 21, "الباب السابع: ألقاب الحروف وصفاتها"),
    (22, 23, "الباب الثامن: مخارج الحروف وتجويد كل حرف"),
    (24, 25, "الباب التاسع: النون الساكنة والتنوين والمد"),
    (26, 30, "الباب العاشر: الوقف والابتداء"),
    (31, 41, "القول في الكلمات الموقوف عليها والمشددات"),
    (42, 42, "معرفة الظاء وتمييزها من الضاد"),
]

TASHKEEL = re.compile("[ؐ-ًؚ-ٰٟۖ-ۭـ]")


# A paragraph is {"t": text, "k": kind}; headings carry their own number in
# the text («٣- أهميةُ تعلُّمِ القرآنِ…»), which the table of contents does not.
NUMBERED = re.compile(r"^\s*[\d٠-٩]+\s*[-–—.)]\s*")


def text_of(para):
    return para["t"] if isinstance(para, dict) else para


# EXACTLY `BookText._isNoise`. The app drops these paragraphs while parsing,
# so a paragraph index counted over the raw JSON would not be the index the
# app sees — every range would be off by however many stray dot-lines Shamela
# put on the pages before it. `ghayat_course_test.dart` re-derives the ranges
# through the app's own parser, which is what would catch this drifting again.
NOISE = re.compile(r"^[.…·\-_*\s]{1,4}$")


def kept(paras):
    """The paragraphs the app keeps, in the app's own order."""
    out = []
    for para in paras:
        t = text_of(para) or ""
        if not t.strip() or NOISE.match(t.strip()):
            continue
        out.append(para)
    return out


def bare(s):
    """The comparison form: no vowel marks, no tatweel, unified alifs/ya."""
    s = NUMBERED.sub("", s or "")
    s = TASHKEEL.sub("", s)
    s = s.replace("آ", "ا").replace("أ", "ا")
    s = s.replace("إ", "ا").replace("ٱ", "ا")
    s = s.replace("ى", "ي").replace("ة", "ه")
    s = re.sub(r"[^\w\s]", " ", s, flags=re.UNICODE)
    return re.sub(r"\s+", " ", s).strip()


def load():
    req = urllib.request.Request(URL, headers=UA)
    with urllib.request.urlopen(req, timeout=120) as r:
        raw = r.read()
    if raw[:2] == b"\x1f\x8b":
        raw = gzip.decompress(raw)
    return json.loads(raw.decode("utf-8"))


def locate(book, entry):
    """(pageIndex, paraIndex) of a TOC entry's heading, or None."""
    idx = entry["pageIndex"]
    if idx >= len(book["pages"]):
        return None
    want = bare(entry["title"])
    paras = kept(book["pages"][idx]["paras"])
    for i, para in enumerate(paras):
        if bare(text_of(para)) == want:
            return (idx, i)
    # A heading the page opens with, carrying something else on the same line.
    for i, para in enumerate(paras):
        b = bare(text_of(para))
        if b.startswith(want) and len(b) < len(want) + 40:
            return (idx, i)
    return None


def main():
    book = load()
    toc = book["toc"]
    pages = book["pages"]

    spots = {}
    missing = []
    for i, entry in enumerate(toc):
        where = locate(book, entry)
        if where is None:
            missing.append((i, entry["title"], entry["pageIndex"]))
        else:
            spots[i] = where

    out = io.open(REPORT, "w", encoding="utf-8")
    out.write("headings located: %d of %d\n" % (len(spots), len(toc)))
    if missing:
        out.write("\nNOT FOUND (these stop the build):\n")
        for i, t, p in missing:
            out.write("  %3d  idx%-4s  %s\n" % (i, p, t))

    lessons = []
    for n, (first, last, title) in enumerate(LESSONS):
        if first not in spots:
            out.write("\nlesson %d starts at an unlocated heading (%d)\n" % (n, first))
            continue
        start = spots[first]
        # The lesson ends where the next lesson's first heading begins.
        nxt = LESSONS[n + 1][0] if n + 1 < len(LESSONS) else None
        if nxt is not None and nxt in spots:
            end_idx, end_para = spots[nxt]
            if end_para > 0:
                end = (end_idx, end_para - 1)
            else:
                end = (end_idx - 1, len(kept(pages[end_idx - 1]["paras"])) - 1)
        else:
            # The last lesson runs to the end of its final TOC section.
            after = last + 1
            if after in spots:
                e_idx, e_para = spots[after]
                end = (e_idx, e_para - 1) if e_para > 0 else (
                    e_idx - 1, len(kept(pages[e_idx - 1]["paras"])) - 1)
            else:
                # THE LAST LESSON RUNS TO THE END OF THE BOOK. Stopping at the
                # end of its own first page cut «معرفة الظاء» down to three
                # paragraphs and dropped the fourteen pages of the ضاد/ظاء
                # word list that are the whole point of that باب.
                end = (len(pages) - 1, len(kept(pages[-1]["paras"])) - 1)
        lessons.append((title, start, end, toc[first]["page"], toc[last]["page"]))

    out.write("\n%d lessons\n\n" % len(lessons))
    total = 0
    for title, start, end, p_from, p_to in lessons:
        count = 0
        for i in range(start[0], end[0] + 1):
            lo = start[1] if i == start[0] else 0
            hi = end[1] if i == end[0] else len(kept(pages[i]["paras"])) - 1
            count += max(0, hi - lo + 1)
        total += count
        first_line = text_of(kept(pages[start[0]]["paras"])[start[1]])[:70]
        out.write(
            "%-46s  ص%-4s-%-4s  idx %3d.%-2d → %3d.%-2d  %4d paras\n"
            % (title, p_from, p_to, start[0], start[1], end[0], end[1], count)
        )
        out.write("        opens: %s\n" % first_line)
    out.write("\ntotal paragraphs in the course: %d\n" % total)
    out.close()

    if "--report" in sys.argv:
        print("report only ->", REPORT)
        return
    # A heading that is not a lesson boundary may go unlocated and nothing is
    # lost: Shamela's table of contents carries page anchors called «مدخل»,
    # «تمهيد» and «أسئلة» that are not headings in the text at all. What may
    # NOT go unlocated is the first entry of a lesson — that is the paragraph
    # the lesson starts at, and a guess there would move the whole lesson.
    starts = {first for first, _last, _title in LESSONS}
    fatal = [m for m in missing if m[0] in starts]
    if fatal:
        sys.exit(
            "%d LESSON-START headings could not be located; see %s"
            % (len(fatal), REPORT)
        )

    q = chr(39)
    lines = []
    lines.append("// GENERATED by scripts/build_tamhid_course.py — do not hand-edit.")
    lines.append("//")
    lines.append("// The third level: «التمهيد في علم التجويد» لابن الجزري (ت ٨٣٣ هـ),")
    lines.append("// read from the copy this app hosts as `%s`." % BOOK)
    lines.append("// Its author died in 1429; nothing in it belongs to anyone living.")
    lines.append("//")
    lines.append("// Each lesson is a run of the BOOK'S OWN table-of-contents sections:")
    lines.append("// one باب with its فصول, ending where he ends it. Nothing here is")
    lines.append("// written by the app; the ranges only say which of his paragraphs")
    lines.append("// belong together. The editor's apparatus is not in this text at all")
    lines.append("// — 986 body paragraphs, 42 headings, 26 ayahs, and no footnote.")
    lines.append("library;")
    lines.append("")
    lines.append("/// One lesson: a span of the book, inclusive at both ends.")
    lines.append("///")
    lines.append("/// Addressed by the index of the page in the book's `pages` array and")
    lines.append("/// the index of the paragraph inside it, not by the printed number: a")
    lines.append("/// section can open halfway down a page — «القول في كلا» starts at the")
    lines.append("/// fourth paragraph of the page the باب before it ends on — so a printed")
    lines.append("/// number does not identify a place. [printedFrom] and [printedTo] are")
    lines.append("/// what the reader is shown.")
    lines.append("class TamhidLesson {")
    lines.append("  final String title;")
    lines.append("  final int fromIndex;")
    lines.append("  final int fromPara;")
    lines.append("  final int toIndex;")
    lines.append("  final int toPara;")
    lines.append("  final int printedFrom;")
    lines.append("  final int printedTo;")
    lines.append("")
    lines.append("  const TamhidLesson({")
    lines.append("    required this.title,")
    lines.append("    required this.fromIndex,")
    lines.append("    required this.fromPara,")
    lines.append("    required this.toIndex,")
    lines.append("    required this.toPara,")
    lines.append("    required this.printedFrom,")
    lines.append("    required this.printedTo,")
    lines.append("  });")
    lines.append("}")
    lines.append("")
    lines.append("/// The book these lessons are read from — hosted, downloaded on first use.")
    lines.append("const tamhidBook = %s%s%s;" % (q, BOOK, q))
    lines.append("")
    lines.append("const tamhidLessons = <TamhidLesson>[")
    for title, start, end, p_from, p_to in lessons:
        lines.append("  TamhidLesson(")
        lines.append("    title: %s%s%s," % (q, title, q))
        lines.append("    fromIndex: %d," % start[0])
        lines.append("    fromPara: %d," % start[1])
        lines.append("    toIndex: %d," % end[0])
        lines.append("    toPara: %d," % end[1])
        lines.append("    printedFrom: %d," % p_from)
        lines.append("    printedTo: %d," % p_to)
        lines.append("  ),")
    lines.append("];")
    lines.append("")
    io.open(DART, "w", encoding="utf-8", newline="\n").write("\n".join(lines))
    print("wrote", DART)
    print("report ->", REPORT)


if __name__ == "__main__":
    main()
