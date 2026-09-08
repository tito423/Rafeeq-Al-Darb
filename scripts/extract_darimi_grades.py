"""Pull Husayn Salim Asad's rulings on Sunan al-Darimi out of his edition.

Sunan al-Darimi is one of the two books the app still shows with no grading at
all (the other is Muwatta Malik — see the note at the end). `مسند الدارمي
المعروف بسنن الدارمي - ت حسين سليم أسد الداراني` (Shamela 21795) rules on the
hadiths one by one, and prints each ruling on its own line, labelled:

    ٣٥٩ - وأخْبرنا مرْوانُ، عنْ ضمْرةَ، قَالَ: «طالبُ عِلمٍ»
    [تعليق المحقق] إسناده حسن

so it needs none of the footnote-marker reconstruction the Arna'ut Musnad did.

The output is keyed by the hadith's normalized Arabic rather than by number,
because the app's Darimi text comes from a different source whose numbering
need not agree with this edition's — the same text-matching approach
`build_hadith_db.py` already uses to attach the four Sunan's gradings. A
hadith that does not match keeps `grade` NULL.

    py -3 scripts/extract_darimi_grades.py
"""
import io
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
PAGES = os.path.join(HERE, "sunan_darimi_asad_pages.jsonl")
OUT = os.path.join(HERE, "sunan_darimi_asad_grades.json")

NUM_LINE = re.compile(r"^([٠-٩]+)\s*-\s*(.*)$")
RULING = re.compile(r"^\[تعليق المحقق\]\s*(.+)$")
GRADER = "حسين سليم أسد الداراني"

GRADE_OPENERS = (
    "إسناده", "إسناد", "حديث", "صحيح", "حسن", "ضعيف", "منكر", "موضوع",
    "شاذ", "مرسل", "متروك", "رجاله", "قوي", "موقوف", "مرفوع", "متواتر",
)


def strip_html(h):
    h = re.sub(r'<a [^>]*class="btn_tag[^>]*>.*?</a>', "", h, flags=re.S)
    h = re.sub(r'<span[^>]*class="anchor"[^>]*></span>', "", h)
    h = re.sub(r"<br\s*/?>", "\n", h)
    h = re.sub(r"</p\s*>", "\n", h)
    h = re.sub(r"<[^>]+>", "", h)
    h = h.replace("&nbsp;", " ").replace("&amp;", "&").replace("&quot;", '"')
    # Shamela marks where the printed page turns, mid-sentence, as
    # ⦗٤١⦘ — that is a page number, not part of the hadith.
    h = re.sub(r"⦗[^⦘]*⦘", " ", h)
    return re.sub(r"\n{3,}", "\n\n", h).strip()


def verdict(s):
    """The ruling itself, or None when the line is not one."""
    s = re.sub(r"\s+", " ", s).strip(" .،")
    if not s or len(s) > 200 or not s.startswith(GRADE_OPENERS):
        return None
    head = s.split("،")[0].strip(" .،")
    return head if len(head) >= 5 and head.startswith(GRADE_OPENERS) else s


def main():
    if not os.path.exists(PAGES):
        print(f"missing {PAGES} — run fetch_shamela_pages.py 21795 4840 first")
        return 1
    pages = {}
    with io.open(PAGES, encoding="utf-8") as f:
        for line in f:
            try:
                d = json.loads(line)
                pages[d["pageId"]] = d
            except Exception:
                pass
    print(f"{len(pages)} pages")

    out, cur = [], None
    for pid in sorted(pages):
        text = strip_html(pages[pid].get("nass") or "")
        for ln in (l.strip() for l in text.split("\n")):
            if not ln:
                continue
            m = NUM_LINE.match(ln)
            if m:
                if cur:
                    out.append(cur)
                cur = {"number": int(m.group(1).translate(
                    str.maketrans("٠١٢٣٤٥٦٧٨٩", "0123456789"))),
                    "arabic": m.group(2), "grade": None}
                continue
            r = RULING.match(ln)
            if r:
                if cur and not cur["grade"]:
                    cur["grade"] = verdict(r.group(1))
            elif cur and not cur["grade"]:
                cur["arabic"] += " " + ln
    if cur:
        out.append(cur)

    graded = [h for h in out if h["grade"]]
    print(f"hadiths seen: {len(out)}  with a ruling: {len(graded)}")
    io.open(OUT, "w", encoding="utf-8", newline="\n").write(json.dumps(
        {"grader": GRADER, "hadiths": graded}, ensure_ascii=False))
    print("wrote", OUT)
    return 0


if __name__ == "__main__":
    sys.exit(main())
