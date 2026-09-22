"""Give each of the eighteen Jazariyyah lessons its own part of the شرح.

«الجزرية دي محتاجة شرح» — the second tajweed level showed the bare verse,
and a matn alone is not something an ordinary reader can follow. The شرح is
«فتح رب البرية شرح المقدمة الجزرية» (Shamela 21580), taken on the owner's
ruling of 2026-09-22 (see `CONTENT-LICENSES.md`).

HOW A LESSON FINDS ITS PART. The شرح quotes each group of verses before it
explains them, so the first verse of every lesson is located in the شرح's
text (on a diacritic-free, punctuation-free stream, because the شرح breaks
some verses up with its own labels — «لِلْجَوْفِ: أَلِفٌ وَأُخْتَاهَا»). Then:

  * a lesson STARTS at the top of the شرح section that holds its first verse
    — sections open with definitions before the verse («تعريف المخرج») and
    those belong to the lesson — unless an earlier lesson's verse is already
    in that section, in which case it starts at its own verse;
  * a lesson ENDS where the next one starts;
  * the author's «فوائد متفرقة» (twenty pages of extras between the last
    chapter and the closing) and his front matter are nobody's lesson.

Every located verse is printed next to the text it was found in, so the
match can be read by eye (§1.4).

    py -3 scripts/build_jazariyyah_sharh.py [--report]
"""

import gzip
import io
import json
import os
import re
import sys
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SHARH_ID = "fath_rabb_al_bariyyah_sharh_al_jazariyyah"
SHARH = os.path.join(ROOT, "scripts", "book_text_build", SHARH_ID + ".json")
MATN_URL = ("https://pub-39dbef68a1a845d5ba669b43a59516b9.r2.dev/books/text/"
            "al_muqaddimah_al_jazariyyah_matn.json")
UA = {"User-Agent": "RafeeqAlDarb/3.56 (https://github.com/tito423/Rafeeq-Al-Darb) curl/8"}
COURSE = os.path.join(ROOT, "rafeeq_app", "lib", "features", "tajweed", "data",
                      "jazariyyah_course.dart")
DART = os.path.join(ROOT, "rafeeq_app", "lib", "features", "tajweed", "data",
                    "jazariyyah_sharh.dart")
REPORT = os.path.join(ROOT, "scripts", "jazariyyah_sharh_out.txt")

NOT_A_LESSON = ("فوائد متفرقة",)
TASHKEEL = re.compile("[ؐ-ًؚ-ٰٟۖ-ۭـ]")
NOISE = re.compile(r"^[.…·\-_*\s]{1,4}$")
EDITOR_NOTE = re.compile(r"^\s*\(\s*[\d٠-٩]+\s*\)")


def bare(s):
    s = TASHKEEL.sub("", s or "")
    for a, b in (("آ", "ا"), ("أ", "ا"), ("إ", "ا"), ("ٱ", "ا"), ("ى", "ي"), ("ة", "ه")):
        s = s.replace(a, b)
    s = re.sub(r"[^ء-ي\s]", " ", s)
    s = re.sub(r"\s+", " ", s).strip()
    # A conjunction written apart in one printing and joined in the other:
    # the matn sets «وَ «رَحْمَتُ»», the شرح «وَرَحْمَتُ».
    return re.sub(r"(^| )و ", r"\1و", s)


def text_of(p):
    return p["t"] if isinstance(p, dict) else p


def kept(paras):
    """Exactly what `BookText` keeps (see build_jazariyyah_course.py)."""
    return [p for p in paras
            if (text_of(p) or "").strip() and not NOISE.match(text_of(p).strip())]


def load_matn():
    req = urllib.request.Request(MATN_URL, headers=UA)
    raw = urllib.request.urlopen(req, timeout=120).read()
    if raw[:2] == b"\x1f\x8b":
        raw = gzip.decompress(raw)
    return json.loads(raw.decode("utf-8"))


def course_lessons():
    src = io.open(COURSE, encoding="utf-8").read()
    out = []
    for m in re.finditer(
            r"title: '([^']+)',\s*fromIndex: (\d+),\s*fromPara: (\d+),"
            r"\s*toIndex: (\d+),\s*toPara: (\d+),", src):
        out.append((m.group(1),) + tuple(int(x) for x in m.groups()[1:]))
    return out


def first_verse(matn, lesson):
    title, fi, fp, ti, tp = lesson
    for i in range(fi, ti + 1):
        paras = kept(matn["pages"][i]["paras"])
        lo = fp if i == fi else 0
        hi = tp if i == ti else len(paras) - 1
        for j in range(lo, hi + 1):
            t = text_of(paras[j])
            # A verse has its two hemistichs split by «…»; «بسم الله الرحمن
            # الرحيم» at the head of the opening lesson is not the first verse.
            if EDITOR_NOTE.match(t) or ("…" not in t and "..." not in t):
                continue
            b = bare(re.sub(r"\(\s*[\d٠-٩]+\s*\)", "", t))
            if len(b.split()) >= 4 and bare(title) not in b[:len(bare(title)) + 2]:
                return t, b
    return None, None


def main():
    matn = load_matn()
    raw = open(SHARH, "rb").read()
    if raw[:2] == b"\x1f\x8b":  # built books are gzip, like the hosted ones (trap #6)
        raw = gzip.decompress(raw)
    sharh = json.loads(raw.decode("utf-8"))
    pages = sharh["pages"]

    # One stream of the شرح's bare text, with where every character came from.
    stream, where = [], []
    for pi, pg in enumerate(pages):
        for qi, p in enumerate(kept(pg["paras"])):
            b = bare(text_of(p)) + " "
            stream.append(b)
            where.extend([(pi, qi)] * len(b))
    text = "".join(stream)

    # Section starts, from the شرح's own table of contents.
    sections = sorted(
        ((e["pageIndex"], 0, e["title"]) for e in sharh["toc"]),
        key=lambda s: s[:2])

    def section_of(pos):
        best = None
        for s in sections:
            if s[:2] <= pos:
                best = s
        return best

    lessons = course_lessons()
    out = io.open(REPORT, "w", encoding="utf-8")
    out.write(f"{len(lessons)} lessons in the course\n\n")
    verse_pos, cursor = [], 0
    for lesson in lessons:
        raw, b = first_verse(matn, lesson)
        hit = None
        if b:
            words = b.split()
            for n in (5, 4, 3):
                key = " ".join(words[:n])
                i = text.find(key, cursor)
                if i >= 0:
                    hit = where[i]
                    cursor = i + 1
                    break
        verse_pos.append(hit)
        out.write(f"{lesson[0]}\n  verse: {raw}\n  found: {hit} "
                  f"{text_of(kept(pages[hit[0]]['paras'])[hit[1]])[:90] if hit else '— NOT FOUND'}\n")

    missing = [lessons[i][0] for i, h in enumerate(verse_pos) if h is None]
    if missing:
        out.close()
        print(io.open(REPORT, encoding="utf-8").read())
        sys.exit("verses not located: %s" % ", ".join(missing))

    def para(pos):
        return text_of(kept(pages[pos[0]]["paras"])[pos[1]])

    def is_verse(pos):
        t = para(pos)
        return "…" in t or "..." in t

    def step_back(pos):
        pi, qi = pos
        if qi > 0:
            return (pi, qi - 1)
        if pi == 0:
            return None
        return (pi - 1, len(kept(pages[pi - 1]["paras"])) - 1)

    starts = []
    for i, pos in enumerate(verse_pos):
        sec = section_of(pos)
        prev = verse_pos[i - 1] if i else (-1, -1)
        start = sec[:2] if sec and sec[:2] > prev else pos
        # Shamela's table of contents can put a heading one page late
        # («بابُ المدِّ» sits two lines above its verse on the page before the
        # one the TOC names), so also walk back over «قال الناظم» and a «باب»
        # heading printed right above the verse.
        b = step_back(pos)
        while b is not None and b > prev and b < start:
            t = bare(para(b))
            if t.startswith("قال الناظم") or t.startswith("باب"):
                start = b
                b = step_back(b)
            else:
                break
        starts.append(start)

    # Two lessons whose verses stand in ONE unbroken verse block are explained
    # together after it (اللامات + التحذيرات, الوقف + الخاتمة): cutting at the
    # second verse would hand the whole explanation to the second lesson and
    # leave the first with its verse alone. Such a pair shares one range.
    def one_block(a, z):
        p = a
        while p < z:
            if not is_verse(p):
                return False
            p = step_back_inv(p)
        return True

    def step_back_inv(pos):
        pi, qi = pos
        if qi + 1 < len(kept(pages[pi]["paras"])):
            return (pi, qi + 1)
        return (pi + 1, 0)

    joined = [i for i in range(len(verse_pos) - 1)
              if one_block(verse_pos[i], verse_pos[i + 1])]

    # Where nobody's material begins: «فوائد متفرقة», and the end of the book.
    walls = [s[:2] for s in sections if s[2].strip() in NOT_A_LESSON]
    last_page = len(pages) - 1
    book_end = (last_page, len(kept(pages[last_page]["paras"])) - 1)

    def before(pos):
        pi, qi = pos
        if qi > 0:
            return (pi, qi - 1)
        return (pi - 1, len(kept(pages[pi - 1]["paras"])) - 1)

    ranges = []
    for i, s in enumerate(starts):
        if i - 1 in joined:  # the second of a pair: same range as the first
            ranges.append(None)
            continue
        j = i
        while j in joined:
            j += 1
        nxt = starts[j + 1] if j + 1 < len(starts) else None
        wall = min([w for w in walls if w > s] or [None], key=lambda w: w or (1e9, 0)) \
            if any(w > s for w in walls) else None
        stop = min([p for p in (nxt, wall) if p is not None] or [None])
        end = before(stop) if stop is not None else book_end
        ranges.append((s, end))
    for i in range(len(ranges)):
        if ranges[i] is None:
            ranges[i] = ranges[i - 1]

    out.write("\nshared (verses in one block): %s\n"
              % ", ".join(f"{lessons[i][0]} + {lessons[i + 1][0]}" for i in joined))
    out.write("\nranges\n")
    for (title, *_), (s, e) in zip(lessons, ranges):
        n = sum(len(kept(pages[p]["paras"])) for p in range(s[0], e[0] + 1)) - s[1] \
            - (len(kept(pages[e[0]]["paras"])) - 1 - e[1])
        out.write(f"  {title:32s} {s} -> {e}  {n} paras  p.{pages[s[0]]['p']}-{pages[e[0]]['p']}\n")
        out.write(f"      opens: {text_of(kept(pages[s[0]]['paras'])[s[1]])[:70]}\n")
    out.close()
    print(io.open(REPORT, encoding="utf-8").read())
    if "--report" in sys.argv:
        return

    q = chr(39)
    L = ["// GENERATED by scripts/build_jazariyyah_sharh.py — do not hand-edit.",
         "//",
         "// Each Jazariyyah lesson's part of «فتح رب البرية شرح المقدمة الجزرية»",
         "// (صفوت محمود سالم، Shamela 21580), located by the lesson's first verse.",
         "// Indices address `BookText.pages` and the paragraphs `BookText` keeps.",
         "library;",
         "",
         "class JazariyyahSharhRange {",
         "  final int fromIndex;",
         "  final int fromPara;",
         "  final int toIndex;",
         "  final int toPara;",
         "",
         "  /// This lesson's verses and a neighbour's stand in one block in the",
         "  /// شرح and are explained together, so both lessons carry this range.",
         "  final bool shared;",
         "",
         "  const JazariyyahSharhRange(",
         "    this.fromIndex,",
         "    this.fromPara,",
         "    this.toIndex,",
         "    this.toPara, {",
         "    this.shared = false,",
         "  });",
         "}",
         "",
         f"const jazariyyahSharhBook = {q}{SHARH_ID}{q};",
         "",
         "/// One entry per lesson, in `jazariyyahLessons` order.",
         "const jazariyyahSharhRanges = <JazariyyahSharhRange>["]
    shared = set(joined) | {i + 1 for i in joined}
    for i, (s, e) in enumerate(ranges):
        flag = ", shared: true" if i in shared else ""
        L.append(f"  JazariyyahSharhRange({s[0]}, {s[1]}, {e[0]}, {e[1]}{flag}),")
    L += ["];", ""]
    io.open(DART, "w", encoding="utf-8", newline="\n").write("\n".join(L))
    print("wrote", DART)


if __name__ == "__main__":
    main()
