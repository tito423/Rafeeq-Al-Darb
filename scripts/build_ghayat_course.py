"""Turn «غاية المريد في علم التجويد» into the third level's lessons.

WHY A SCRIPT AND NOT A HAND-WRITTEN LIST. The first two levels were small
enough to read end to end: تحفة الأطفال is eight pages, تيسير أحكام التجويد
twenty-four lessons. This book is **374 pages with a 177-entry table of
contents**, and its own author has already done the teaching order — every
topic block ends with a «أسئلة» section of exercises. Grouping by hand would
be 177 chances to mistype a number.

WHAT IT DOES NOT DO. It does not invent a single boundary. Each lesson is a
run of the book's OWN table-of-contents entries, and the run's edges are the
paragraph where the first heading really sits and the paragraph before the
next lesson's first heading. Where a heading cannot be located in its page's
paragraphs the script stops rather than guessing — `ghayat_course_test.dart`
then re-checks every range against the real text.

ADDRESSED BY ARRAY INDEX, NOT BY PRINTED PAGE. Unlike the other two books,
this one has several entries per printed page: the table of contents lists
«تاريخ التأليف في هذا العلم» and «منشأ اختلاف القراءات» both on page 23, and
they are two different entries of the `pages` array. Printed pages are shown
to the reader; the ranges are stored as indices.

    py -3 scripts/build_ghayat_course.py            # writes the Dart + a report
    py -3 scripts/build_ghayat_course.py --report   # report only
"""

import gzip
import io
import json
import os
import re
import sys
import urllib.request

BOOK = "ghayat_al_murid"
URL = (
    "https://pub-39dbef68a1a845d5ba669b43a59516b9.r2.dev/books/text/%s.json" % BOOK
)
UA = {"User-Agent": "RafeeqAlDarb/3.26 (https://github.com/tito423/Rafeeq-Al-Darb)"}

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DART = os.path.join(
    ROOT, "rafeeq_app", "lib", "features", "tajweed", "data", "ghayat_course.dart"
)
REPORT = os.path.join(ROOT, "scripts", "ghayat_course_out.txt")

# Each lesson is a span of TOC entry indices, inclusive. The spans follow the
# book's own «أسئلة» sections: a topic, then the exercises that close it.
# Front matter (the three مقدمة) and back matter (المراجع, the index) are left
# out — they are not lessons.
LESSONS = [
    (3, 12, "مدخل إلى علم التجويد"),
    (13, 20, "تاريخ التجويد والقراءات"),
    (21, 26, "الإمام عاصم وراويه حفص"),
    (27, 33, "أقسام التجويد ومعنى اللحن"),
    (34, 36, "الاستعاذة"),
    (37, 41, "البسملة وأوجه الابتداء"),
    (42, 44, "أحكام النون الساكنة والتنوين"),
    (45, 47, "الإظهار الحلقي"),
    (48, 50, "الإدغام"),
    (51, 53, "الإقلاب"),
    (54, 56, "الإخفاء الحقيقي"),
    (57, 59, "النون والميم المشددتان والغنة"),
    (60, 64, "أحكام الميم الساكنة"),
    (65, 71, "أحكام اللامات السواكن"),
    (72, 79, "المد والقصر: الأصلي والفرعي"),
    (80, 86, "المد اللازم وأقسامه ومراتب المدود"),
    (87, 94, "تنبيهات المدود وألقابها"),
    (95, 108, "مخارج الحروف"),
    (109, 116, "صفات الحروف"),
    (117, 122, "التفخيم والترقيق"),
    (123, 128, "المتماثلان والمتقاربان والمتجانسان والمتباعدان"),
    (129, 131, "الوقف على أواخر الكلم"),
    (132, 133, "حكم التقاء الساكنين"),
    (134, 139, "الحذف والإثبات"),
    (140, 142, "هاء الكناية"),
    (143, 153, "الوقف والابتداء"),
    (154, 159, "المقطوع والموصول"),
    (160, 164, "هاء التأنيث الموقوف عليها بالتاء"),
    (165, 172, "همزتا الوصل والقطع"),
    (173, 174, "ما يراعى لحفص وخاتمة الكتاب"),
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
                end = (spots[last][0], len(kept(pages[spots[last][0]]["paras"])) - 1)
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
    lines.append("// GENERATED by scripts/build_ghayat_course.py — do not hand-edit.")
    lines.append("//")
    lines.append("// The third level: «غاية المريد في علم التجويد» لعطية قابل نصر,")
    lines.append("// 374 pages, read from the copy this app hosts as `%s`." % BOOK)
    lines.append("//")
    lines.append("// Each lesson is a run of the BOOK'S OWN table-of-contents sections,")
    lines.append("// ending where the author ends it — every block closes with his own")
    lines.append("// «أسئلة». Nothing here is written by the app; the ranges only say")
    lines.append("// which of his paragraphs belong together.")
    lines.append("library;")
    lines.append("")
    lines.append("/// One lesson: a span of the book, inclusive at both ends.")
    lines.append("///")
    lines.append("/// Addressed by the index of the page in the book's `pages` array, not")
    lines.append("/// by its printed number: this book puts several sections on one printed")
    lines.append("/// page (two of them are on page 23), so the printed number does not")
    lines.append("/// identify a place. [printedFrom] and [printedTo] are what the reader")
    lines.append("/// is shown.")
    lines.append("class GhayatLesson {")
    lines.append("  final String title;")
    lines.append("  final int fromIndex;")
    lines.append("  final int fromPara;")
    lines.append("  final int toIndex;")
    lines.append("  final int toPara;")
    lines.append("  final int printedFrom;")
    lines.append("  final int printedTo;")
    lines.append("")
    lines.append("  const GhayatLesson({")
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
    lines.append("const ghayatBook = %s%s%s;" % (q, BOOK, q))
    lines.append("")
    lines.append("const ghayatLessons = <GhayatLesson>[")
    for title, start, end, p_from, p_to in lessons:
        lines.append("  GhayatLesson(")
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
