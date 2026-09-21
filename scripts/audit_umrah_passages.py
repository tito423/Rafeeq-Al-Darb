# -*- coding: utf-8 -*-
"""List real al-Idah paragraphs that can support an Umrah-only guide.

The report is evidence for hand-selecting paragraph ranges. It reads the exact
book bundled in the app, preserves every source character, and prints page and
paragraph indexes so the Flutter guide can point back to the same text.
"""

import argparse
import gzip
import io
import json
import os
import re
import sys


if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")


ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BOOK = os.path.join(
    ROOT,
    "rafeeq_app",
    "assets",
    "data",
    "builtin_books",
    "al_idah_fi_manasik_al_hajj_wal_umrah.json",
)
DEFAULT_REPORT = os.path.join(
    ROOT, "scripts", "pipeline_temp", "umrah_passage_audit.txt"
)
MARKS = re.compile(r"[ؐ-ًؚ-ٰٟۖ-ۭـ]")
NOTE = re.compile(r"^\s*(\(\s*[\d٠-٩]+\s*\)|=)")
GLOSS = re.compile(
    r"^\s*أي\s|قال في الحاشية|قال المحشي|أقول\s*:|"
    r"(^|\s)اه\s*\.|اه (حاشية|تعليق|تقريرات)|الحكومة السعودية"
)
TERMS = re.compile(
    r"عمرة|العمره|معتمر|اعتمر|متمتع|التمتع|قران|قارن|نسكين|نسكَيْن"
)


def load_book(path):
    raw = open(path, "rb").read()
    if raw[:2] == b"\x1f\x8b":
        raw = gzip.decompress(raw)
    return json.loads(raw.decode("utf-8"))


def is_note(text):
    if NOTE.search(text):
        return True
    return bool(GLOSS.search(MARKS.sub("", text)))


def bare(text):
    text = MARKS.sub("", text)
    text = text.replace("أ", "ا").replace("إ", "ا").replace("آ", "ا")
    return text.replace("ة", "ه").replace("ى", "ي")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--book", default=BOOK)
    parser.add_argument("--report", default=DEFAULT_REPORT)
    parser.add_argument(
        "--outline",
        help="Print every paragraph index in an inclusive page range, e.g. 124-145",
    )
    parser.add_argument(
        "--headings",
        help="Print likely headings in an inclusive page range, e.g. 192-250",
    )
    args = parser.parse_args()
    doc = load_book(args.book)
    os.makedirs(os.path.dirname(args.report), exist_ok=True)
    pages = {
        int(page["p"]): page.get("paras", [])
        for page in doc["pages"]
        if isinstance(page.get("p"), int)
    }

    if args.outline or args.headings:
        selected = args.outline or args.headings
        start, end = (int(value) for value in selected.split("-", 1))
        for page_no in range(start, end + 1):
            for index, para in enumerate(pages.get(page_no, [])):
                value = (para.get("t") or "").strip().replace("\n", " ")
                if args.headings and not (
                    len(value) <= 90
                    or re.match(
                        r"^(فصل|باب|فرع|النوع|القسم|الواجب|الركن|السنة|"
                        r"المسألة|الأول|الثاني|الثالث|الرابع|الخامس|السادس|"
                        r"السابع|الثامنة|التاسعة|العاشر)",
                        MARKS.sub("", value),
                    )
                ):
                    continue
                status = "DROP" if is_note(value) else "KEEP"
                print("%d:%d [%s] %s" % (page_no, index, status, value[:1200]))
        return

    candidates = []
    for page_no in range(45, 388):
        paras = pages.get(page_no, [])
        for index, para in enumerate(paras):
            text = (para.get("t") or "").strip()
            if text and not is_note(text) and TERMS.search(bare(text)):
                candidates.append((page_no, index))

    with io.open(args.report, "w", encoding="utf-8", newline="\n") as out:
        out.write("UMRAH PASSAGE AUDIT — bundled al-Idah text\n")
        out.write("Source bytes are printed unchanged. [DROP] marks paragraphs "
                  "the app's existing note filter removes.\n\n")
        out.write("CANDIDATES WITH ONE PARAGRAPH OF CONTEXT\n")
        out.write("=" * 78 + "\n")
        for page_no, index in candidates:
            paras = pages[page_no]
            out.write("\nPAGE %d MATCH %d\n" % (page_no, index))
            for current in range(max(0, index - 1), min(len(paras), index + 2)):
                text = (paras[current].get("t") or "").strip()
                status = "DROP" if is_note(text) else "KEEP"
                out.write("  [%d|%s|%s] %s\n" % (
                    current, paras[current].get("k", "body"), status, text))

        out.write("\n\nTHE COMPLETE UMRAH CHAPTER, PAGES 378–387\n")
        out.write("=" * 78 + "\n")
        for page_no in range(378, 388):
            paras = pages.get(page_no, [])
            out.write("\nPAGE %d\n" % page_no)
            for index, para in enumerate(paras):
                text = (para.get("t") or "").strip()
                status = "DROP" if is_note(text) else "KEEP"
                out.write("  [%d|%s|%s] %s\n" % (
                    index, para.get("k", "body"), status, text))

    print("candidates=%d report=%s" % (len(candidates), args.report))


if __name__ == "__main__":
    main()
