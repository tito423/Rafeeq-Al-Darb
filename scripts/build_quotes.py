# -*- coding: utf-8 -*-
"""Extract standalone quotes from the library's own books, each carrying the
book it came from.

WHAT THE OWNER ASKED FOR
«المقولات: من كتب المكتبة نفسها» — «لا تحزن», «صيد الخاطر», «حلية الأولياء»
and «روضة العقلاء ونزهة الفضلاء». And: «كل مقولة لازم تحمل اسم كتابها» —
§1.1 and §1.2, nothing attributed to a scholar without a source.

WHAT IS DELIBERATELY THROWN AWAY, AND WHY
This picks the **author's own prose**, never a narration. A paragraph is
rejected outright if it carries:

  * a Qur'anic quotation (﴿…﴾, «قال تعالى») — an ayah shown as a floating
    "quote" with no surah:ayah reference is not something this app does;
  * a prophetic hadith («قال رسول الله», «صلى الله عليه وسلم», «ﷺ») —
    CLAUDE.md §1.2 forbids showing a hadith without its grading, and there is
    no grading to attach here. The Encyclopedia tab is where graded hadith
    lives;
  * an isnad («حدثنا», «أخبرنا», «أنبأنا», «ثنا») — half a chain of
    transmission is not a saying.

That last rule is what makes حلية الأولياء usable at all: it is mostly
narrations *about* the pious, and what survives the filter is the reported
saying itself rather than the chain that carries it.

The text is copied **verbatim**. Nothing is rewritten, normalised or
"tidied" — §1.2.

    py -3 scripts/build_quotes.py            # reads dist/quotes_src/*.json
"""

import io
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "dist", "quotes_src")
OUT = os.path.join(ROOT, "rafeeq_app", "assets", "data", "quotes.json")
REPORT = os.path.join(ROOT, "quotes_report.txt")

# A quote has to read as one finished thought on a card, not as a paragraph
# of a chapter. Measured against the four books rather than guessed: below 70
# characters they are fragments, above 300 they do not fit a notification
# card without scrolling.
MIN_LEN = 70
MAX_LEN = 300

# Rejected outright. Each of these means "this is somebody else's words, and
# quoting them here would strip the attribution they require".
REJECT = [
    "﴿", "﴾", "قال تعالى", "قال الله تعالى", "تبارك وتعالى", "عز وجل",
    "قال رسول الله", "رسول الله", "صلى الله عليه وسلم", "ﷺ",
    "عليه الصلاة والسلام", "عليه السلام", "النبي",
    "حدثنا", "حدثني", "أخبرنا", "أخبرني", "أنبأنا", "ثنا", "نا ",
    "رضي الله عنه", "رضي الله عنها", "رضي الله عنهم",
    "سورة", "الآية", "روى", "روي", "يروى", "يروي", "رواه",
    "أخرجه", "في الصحيح", "متفق عليه",
]

# A paragraph that opens on one of these is the tail of the sentence before
# it, whatever its length.
BAD_START = ["و", "ف", "ثم ", "أي ", "لأن", "بل ", "أو ", "لكن", "إذ ",
             "كما ", "وقد", "فقد", "هذا ", "ذلك ", "وهذا", "-", "،", ".",
             # The second half of an enumeration whose first half is on the
             # line above: «أحدهما: أن المواعظ كالسياط...» reads as a maxim
             # and is not one.
             "أحدهما", "والثاني", "الثاني", "الثالث", "ومنها",
             "منها ", "غير أن", "فإن ", "فلما", "قلت:", "قال:"]

END_OK = tuple(".؟!؟")


# CLAUDE.md trap #2, in a new place. «روضة العقلاء» sets its isnads fully
# diacritised — «حَدَّثَنَا», «أَنْبَأَنَا» — so a plain `"حدثنا" in t` matched
# none of them and three chains of transmission came through as "quotes".
# The comparison is done on a diacritic-stripped copy; the quote itself is
# always the untouched original (§1.2 — nothing is rewritten).
_TASHKEEL = re.compile("[ؐ-ًؚ-ٰٟۖ-ۭـ]")
_ALEF = re.compile("[آأإٱ]")


def bare(t):
    return _ALEF.sub("ا", _TASHKEEL.sub("", t)).replace("ى", "ي")


def clean(t):
    # Collapse the runs of whitespace a page break leaves behind. Nothing
    # else is touched: no diacritics removed, no letters unified, no
    # punctuation "fixed".
    return re.sub(r"\s+", " ", t or "").strip()


# Read off the real books rather than assumed (§1.4). Both Shamela
# editions mark quotations typographically, and the FIRST pass of this
# script shipped them because it only looked for ﴾﴿:
#
#   {وَمِن شَرِّ حَاسِدٍ}   an ayah, in plain braces
#   (( ... ))          a hadith, in doubled parentheses
#
# «لا تحزن» p.69, p.212, p.290 and p.311 came out of that pass as
# floating ayahs with no surah:ayah beside them, and p.193 as «عجبًا لأمر
# المؤمن» — a hadith of Muslim's with no grading and no takhrij. Neither
# is something this app shows (§1.2), so a paragraph carrying either mark
# is dropped whole.
QUOTE_MARKS = ["{", "}", "((", "))", "﴾", "﴿"]


def usable(t, need_terminator=True):
    if not (MIN_LEN <= len(t) <= MAX_LEN):
        return False
    if any(m in t for m in QUOTE_MARKS):
        return False
    # «صيد الخاطر»'s edition puts the EDITOR's footnotes into the same
    # body stream as Ibn al-Jawzi's text, and marks the references with
    # superscripts that come through as Arabic-Indic digits stuck to the
    # preceding word. The first pass shipped «١ التحقيق: أي تفصيل
    # المسائل...» and «١ في الأصل: كانوا...» as sayings of his.
    #
    #   a paragraph OPENING on a digit is a footnote block;
    #   a digit welded to a letter mid-sentence is a footnote marker.
    # No digits at all, in either script. The footnote markers this edition
    # welds to words come through as Arabic-Indic digits — «ثلاثة١:»,
    # «"ويفقدون"٢» — and there is no reliable way to tell a marker from
    # a number by what sits next to it (the second one is behind a quote
    # mark, not a letter). A maxim that needs a numeral is rare enough to
    # give up; a maxim carrying a stray footnote index is not shippable.
    if re.search(r"[\d٠-٩]", t):
        return False
    if need_terminator and not t.endswith(END_OK):
        return False
    b = bare(t)
    if any(bare(bad) in b for bad in REJECT):
        return False
    if any(b.startswith(bare(x)) for x in BAD_START):
        return False
    # Brackets a page break split in half read as a broken sentence.
    for a, b in [("(", ")"), ("[", "]"), ("«", "»"), ("“", "”")]:
        if t.count(a) != t.count(b):
            return False
    # A straight quote is its own closer, so an odd count is an unclosed one:
    # «"سيدي كيف أقدر على شكرك?» opened a quotation the page break took
    # the end of.
    if t.count('"') % 2:
        return False
    # A line of poetry is set as two hemistiches; without its partner it is
    # half a verse.
    if t.count("...") or t.count("…"):
        return False
    return True


def from_book(path):
    doc = json.load(io.open(path, encoding="utf-8"))
    meta = doc.get("meta", {})
    book = {
        "id": doc["id"],
        "titleAr": meta.get("titleAr", ""),
        "authorAr": meta.get("authorAr", ""),
        "sourceLabel": meta.get("sourceLabel", ""),
    }
    # Where the book itself starts. Everything before it is the publisher's:
    # «صيد الخاطر» opens with 22 pages of the editor's introduction, and
    # the first pass quoted «كان العراق تحت سلطان السلاجقة...» as if Ibn
    # al-Jawzi had written it. The TOC says where the content begins, so it
    # is read rather than a page number being guessed at.
    FRONT = ["مقدمة", "المقدمة", "تقديم", "التقديم", "ترجمة",
             "بين يدي", "الفهرس", "فهرس"]
    first_page = 1
    for entry in doc.get("toc", []):
        name = (entry.get("title") or "").strip()
        if not name or name == book["titleAr"]:
            continue
        if any(name.startswith(f) for f in FRONT):
            continue
        first_page = entry.get("page", 1)
        break

    # Some Shamela editions are set WITHOUT sentence punctuation. «روضة
    # العقلاء» is one: not a single one of its 2,333 body paragraphs ends
    # in a full stop, so requiring a terminator returned ZERO quotes from a
    # 276-page book of maxims. Where the punctuation simply is not there the
    # PARAGRAPH is the unit — Shamela sets one utterance per paragraph — and
    # a whole paragraph is a whole thought whether or not a dot follows it.
    # Measured per book rather than assumed, and reported.
    # Measured over the paragraphs that pass every OTHER filter, not over all
    # of them: «روضة العقلاء» looks 22% punctuated only because its
    # poetry hemistiches end in an ellipsis, while 878 of its prose
    # paragraphs — the ones a quote would come from — carry no terminator at
    # all. Asking the candidates themselves is the question that matters.
    candidates = [clean(q.get("t"))
                  for pg in doc.get("pages", [])
                  for q in pg.get("paras", []) if q.get("k") == "body"]
    candidates = [t for t in candidates if usable(t, need_terminator=False)]
    punctuated = sum(1 for t in candidates if t.endswith(END_OK))
    ratio = punctuated / max(1, len(candidates))
    need_terminator = ratio >= 0.20
    book["punctuationRatio"] = round(ratio, 3)

    seen = set()
    quotes = []
    title = book["titleAr"]
    for page in doc.get("pages", []):
        if page.get("p", 0) < first_page:
            continue
        bodies = [p for p in page.get("paras", []) if p.get("k") == "body"]
        # The FIRST body paragraph of a page is where a paragraph split by
        # the page break lands, and it therefore opens mid-sentence: «قومٍ،
        # وقال: حملني شهوة الحديث...», «أن تعقد على ما يقوله...». There is
        # no way to tell those from a real opening by looking at the words,
        # so the position is used instead. Cheap: there are thousands of
        # candidates and this costs one paragraph per page.
        for para in bodies[1:]:
            t = clean(para.get("t"))
            if title and t.startswith(title):
                continue      # the title page, not a saying
            if not usable(t, need_terminator):
                continue
            if t in seen:
                continue
            seen.add(t)
            quotes.append({"t": t, "p": page.get("p", 0)})
    return book, quotes


# Which of the four books this can actually mine, and why the fourth is not
# on the list.
#
# حلية الأولياء IS in the library — it was crawled, built and uploaded this
# session — but it is a book of NARRATIONS and biographies, not of maxims,
# and the filter above cannot separate them safely. A run of it produced
# 1,032 "quotes" whose hand-read sample contained:
#
#   «يا جبريل إني قد بلوته فوجدته صابرا…»        a hadith, ungraded
#   ««كل صلاة تحط ما بين يديها من الخطيئة»…»        a hadith, ungraded
#   «الأحوص عن مسلم الملائي عن مجاهد…»          half an isnad
#   «قال الشيخ ً: لم نكتبه من حديث…»            an editorial note on a chain
#
# CLAUDE.md §1.2 forbids showing a hadith without its grading, and §1.1
# forbids shipping a catalogue whose contents were not verified. Tuning the
# filter until the sample looks clean would be guessing at the rest, so the
# book is excluded from the quotes and kept as a book. Said plainly rather
# than quietly shipped.
EXCLUDED = {
    "hilyat_al_awliya":
        "a book of narrations and biographies: the filter cannot separate "
        "Abu Nu'aym's maxims from ungraded hadith and isnad fragments",
}


def main():
    if not os.path.isdir(SRC):
        sys.exit("no %s — put the four book JSONs there first" % SRC)

    books = []
    report = io.open(REPORT, "w", encoding="utf-8")
    total = 0
    for name in sorted(os.listdir(SRC)):
        if not name.endswith(".json"):
            continue
        book_id = name[:-5]
        if book_id in EXCLUDED:
            print("%-28s SKIPPED — %s" % (book_id, EXCLUDED[book_id]))
            continue
        book, quotes = from_book(os.path.join(SRC, name))
        book["quotes"] = quotes
        books.append(book)
        total += len(quotes)
        report.write("\n%s\n%s  —  %d quotes\n%s\n"
                     % ("=" * 70, book["titleAr"], len(quotes), "=" * 70))
        # Twenty spread across the book, not the first twenty, so the sample
        # is of the whole book and not of its introduction. These are read by
        # hand before the file is trusted (CLAUDE.md §1.4).
        step = max(1, len(quotes) // 20)
        for q in quotes[::step][:20]:
            report.write("\n[ص %s] %s\n" % (q["p"], q["t"]))
    report.close()

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with io.open(OUT, "w", encoding="utf-8", newline="\n") as f:
        json.dump({"schema": 1, "books": books}, f, ensure_ascii=False,
                  indent=1)
        f.write("\n")

    for b in books:
        print("%-28s %5d quotes  (punctuated paragraphs %.0f%%)"
              % (b["id"], len(b["quotes"]), b["punctuationRatio"] * 100))
    print("total %d quotes, %d bytes -> %s"
          % (total, os.path.getsize(OUT), OUT))
    print("sample written to %s - READ IT before trusting this" % REPORT)


if __name__ == "__main__":
    main()
