"""Cut «المقدمة الجزرية» into the second level's lessons.

The Jazariyyah is a matn of about a hundred lines by ابن الجزري (ت ٨٣٣ هـ) —
the step every student takes after تحفة الأطفال, and the reason this level
could be moved off a book that is still in copyright.

WHAT IS TAKEN AND WHAT IS LEFT. The printing on Shamela is د. عبد المحسن
القاسم's 2020 critical edition, and **his work is his**: the table of contents
lists eighteen sections of editorial apparatus before the poem starts —
مقدمة التحقيق, وصف النسخ الخطية, ترجمة الناظم, نماذج من المخطوطات — and closes
with his bibliography. None of that is in the app.

The نَّاظِم's own text is TOC entries **18 to 35**, «مقدمة الناظم» (printed
page 53) through «[خاتمة]» (page 97). One lesson per entry, eighteen of them,
in his own order and under his own headings.

    py -3 scripts/build_jazariyyah_course.py [--report]
"""

import gzip
import io
import json
import os
import re
import sys
import urllib.request

BOOK = "al_muqaddimah_al_jazariyyah_matn"
URL = ("https://pub-39dbef68a1a845d5ba669b43a59516b9.r2.dev/books/text/%s.json"
       % BOOK)
UA = {"User-Agent": "RafeeqAlDarb/3.26 (https://github.com/tito423/Rafeeq-Al-Darb)"}

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DART = os.path.join(ROOT, "rafeeq_app", "lib", "features", "tajweed", "data",
                    "jazariyyah_course.dart")
REPORT = os.path.join(ROOT, "scripts", "jazariyyah_course_out.txt")

# The nazim's own sections, by index into the book's table of contents. The
# first editorial entry after them (36, فهرس أهم مراجع التحقيق) is the wall the
# last lesson stops at.
FIRST, LAST, AFTER = 18, 35, 36

# THE EDITOR'S FOOTNOTES ARE HIS. Every page of this printing carries
# د. القاسم's apparatus under the verses, marked «(١) في ج زيادة: …». They are
# not the nazim's words and they are not ours to ship, so the screen drops any
# paragraph that opens with a bracketed number — `jazariyyah_lesson_text.dart`
# applies the same rule the Dart side of تحفة الأطفال applies to its markers.
EDITOR_NOTE = re.compile(r"^\s*\(\s*[\d٠-٩]+\s*\)")

TASHKEEL = re.compile("[ؐ-ًؚ-ٰٟۖ-ۭـ]")
NUMBERED = re.compile(r"^\s*[\d٠-٩]+\s*[-–—.)]\s*")
NOISE = re.compile(r"^[.…·\-_*\s]{1,4}$")


def text_of(p):
    return p["t"] if isinstance(p, dict) else p


def kept(paras):
    """Exactly what `BookText` keeps — see `build_ghayat_course.py`."""
    out = []
    for p in paras:
        t = (text_of(p) or "").strip()
        if not t or NOISE.match(t):
            continue
        out.append(p)
    return out


def bare(s):
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
    idx = entry["pageIndex"]
    if idx >= len(book["pages"]):
        return None
    want = bare(entry["title"].strip("[]"))
    paras = kept(book["pages"][idx]["paras"])
    for i, p in enumerate(paras):
        if bare(text_of(p)) == want:
            return (idx, i)
    for i, p in enumerate(paras):
        b = bare(text_of(p))
        if b.startswith(want) and len(b) < len(want) + 40:
            return (idx, i)
    return None


def main():
    book = load()
    toc, pages = book["toc"], book["pages"]
    spots, missing = {}, []
    for i in range(FIRST, AFTER + 1):
        # «مقدمة الناظم» is the EDITOR'S label for the opening, not a line in
        # the poem: page 53 starts «بسم الله الرحمن الرحيم» and goes straight
        # into «يَقُولُ رَاجِي عَفْوِ رَبٍّ سَامِعِ». There is no heading to
        # find, so that one lesson starts at the top of its page.
        where = ((toc[i]["pageIndex"], 0) if i == FIRST
                 else locate(book, toc[i]))
        (spots.__setitem__(i, where) if where else
         missing.append((i, toc[i]["title"])))

    out = io.open(REPORT, "w", encoding="utf-8")
    out.write("the nazim's sections: %d..%d, wall at %d\n" % (FIRST, LAST, AFTER))
    if missing:
        out.write("\nnot located:\n")
        for i, t in missing:
            out.write("  %d  %s\n" % (i, t))

    lessons = []
    for i in range(FIRST, LAST + 1):
        if i not in spots:
            continue
        start = spots[i]
        nxt = i + 1
        while nxt <= AFTER and nxt not in spots:
            nxt += 1
        if nxt in spots:
            e_idx, e_para = spots[nxt]
            end = ((e_idx, e_para - 1) if e_para > 0
                   else (e_idx - 1, len(kept(pages[e_idx - 1]["paras"])) - 1))
        else:
            end = (start[0], len(kept(pages[start[0]]["paras"])) - 1)
        lessons.append((toc[i]["title"].strip("[]").strip(), start, end,
                        toc[i]["page"],
                        toc[nxt]["page"] if nxt in spots else toc[LAST]["page"]))

    out.write("\n%d lessons\n\n" % len(lessons))
    total = 0
    for title, start, end, p_from, _p_to in lessons:
        n = 0
        for i in range(start[0], end[0] + 1):
            lo = start[1] if i == start[0] else 0
            hi = end[1] if i == end[0] else len(kept(pages[i]["paras"])) - 1
            n += max(0, hi - lo + 1)
        total += n
        out.write("%-34s  ص%-4s  idx %3d.%-2d → %3d.%-2d  %3d paras\n"
                  % (title, p_from, start[0], start[1], end[0], end[1], n))
        out.write("        opens: %s\n"
                  % text_of(kept(pages[start[0]]["paras"])[start[1]])[:70])
    out.write("\ntotal paragraphs: %d\n" % total)
    out.close()
    print(io.open(REPORT, encoding="utf-8").read())

    if "--report" in sys.argv:
        return
    if len(lessons) != 18:
        sys.exit("expected 18 lessons, got %d — see %s" % (len(lessons), REPORT))

    q = chr(39)
    L = []
    L.append("// GENERATED by scripts/build_jazariyyah_course.py — do not hand-edit.")
    L.append("//")
    L.append("// The second level: «المقدمة الجزرية» لابن الجزري (ت ٨٣٣ هـ).")
    L.append("//")
    L.append("// EIGHTEEN LESSONS, AND NOT ONE LINE OF THE EDITOR'S. The printing is")
    L.append("// د. عبد المحسن القاسم's 2020 edition, whose apparatus — مقدمة التحقيق,")
    L.append("// وصف النسخ, ترجمة الناظم, نماذج من المخطوطات, فهرس المراجع — is his own")
    L.append("// work and stays out. These ranges cover entries 18 to 35 of the book's")
    L.append("// table of contents: the nazim's poem, from «مقدمة الناظم» to his")
    L.append("// «[خاتمة]».")
    L.append("library;")
    L.append("")
    L.append("/// One lesson: a span of the matn, inclusive at both ends, addressed by")
    L.append("/// index into `BookText.pages` for the reason `GhayatLesson` explains.")
    L.append("class JazariyyahLesson {")
    for f in ("String title", "int fromIndex", "int fromPara", "int toIndex",
              "int toPara", "int printedFrom", "int printedTo"):
        L.append("  final %s;" % f)
    L.append("")
    L.append("  const JazariyyahLesson({")
    for f in ("title", "fromIndex", "fromPara", "toIndex", "toPara",
              "printedFrom", "printedTo"):
        L.append("    required this.%s," % f)
    L.append("  });")
    L.append("}")
    L.append("")
    L.append("const jazariyyahBook = %s%s%s;" % (q, BOOK, q))
    L.append("")
    L.append("const jazariyyahLessons = <JazariyyahLesson>[")
    for title, start, end, p_from, p_to in lessons:
        L.append("  JazariyyahLesson(")
        L.append("    title: %s%s%s," % (q, title, q))
        L.append("    fromIndex: %d," % start[0])
        L.append("    fromPara: %d," % start[1])
        L.append("    toIndex: %d," % end[0])
        L.append("    toPara: %d," % end[1])
        L.append("    printedFrom: %d," % p_from)
        L.append("    printedTo: %d," % p_to)
        L.append("  ),")
    L.append("];")
    L.append("")
    io.open(DART, "w", encoding="utf-8", newline="\n").write("\n".join(L))
    print("wrote", DART)


if __name__ == "__main__":
    main()
