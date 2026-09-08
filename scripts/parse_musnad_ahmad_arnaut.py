"""Turn the fetched Arna'ut pages into hadiths, musnads, and real gradings.

Reads scripts/musnad_ahmad_arnaut_pages.jsonl (see fetch_musnad_ahmad_arnaut.py)
and writes scripts/musnad_ahmad_arnaut.json:

    {"chapters": [{"no": 1, "name_ar": "مسند أبي بكر الصديق ..."}, ...],
     "hadiths":  [{"number": 1, "chapter_no": 1, "arabic": "...",
                   "grade": "إسناده صحيح على شرط الشيخين", ...}, ...]}

How the edition is laid out, and what that forces:

* A hadith opens with its number, "٦١٩ - حَدَّثَنَا ...", and runs until the
  next numbered line or the page's footnote block.
* Footnote numbers restart on every page, so a marker only means anything
  within its own page. A hadith's own footnote is the marker sitting at the
  END of its text; markers in the middle belong to words, not to the hadith.
* Not every footnote is a ruling. "(٢) في (س) و (ق): حدثنا" is a manuscript
  variant. A footnote counts as a grading only when its first sentence opens
  with an actual judgement ("إسناده صحيح على شرط الشيخين", "حسن لغيره، وهذا
  إسناد ضعيف", "إسناده ضعيف" ...); anything else leaves `grade` NULL. Nothing
  is inferred — a hadith with no ruling stays ungraded, which is the whole
  point of asking for a real takhrij.
* Hadiths and their footnotes run across page breaks, so pages are walked in
  order with the open hadith carried forward.
* The page `title` is the musnad the page sits in — that is the real chapter
  structure, taken from the edition rather than invented.
"""
import io
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
PAGES = os.path.join(HERE, "musnad_ahmad_arnaut_pages.jsonl")
OUT = os.path.join(HERE, "musnad_ahmad_arnaut.json")

_AR_DIGITS = str.maketrans("٠١٢٣٤٥٦٧٨٩", "0123456789")
NUM_LINE = re.compile(r"^([٠-٩]+)\s*-\s*(.*)$")
FOOT_LINE = re.compile(r"^\(([٠-٩]+)\)\s*(.*)$")
TRAIL_MARK = re.compile(r"\(([٠-٩]+)\)\s*$")

# A footnote is a grading only if its first sentence opens with one of these.
GRADE_OPENERS = (
    "إسناده", "إسناد", "أسناده", "حديث صحيح", "حديث حسن", "حديث ضعيف",
    "صحيح", "حسن", "ضعيف", "منكر", "موضوع", "شاذ", "مرسل", "متروك",
    "رجاله", "قوي", "مرفوع", "موقوف", "متواتر",
)


STOPS = (
    ". ", " وأخرجه", " وأخرجهُ", " وانظر", " وسيأتي", " وقد أخرجه",
    " ورواه", " وهو مكرر", " وهومكرر", " وفي الباب", " وسلف",
    " وقد سلف", " تنبيه", " وذكره", " قلنا",
)

def ar_int(s):
    return int(s.translate(_AR_DIGITS))


def strip_html(h):
    h = re.sub(r'<a [^>]*class="btn_tag[^>]*>.*?</a>', "", h, flags=re.S)
    h = re.sub(r'<span[^>]*class="anchor"[^>]*></span>', "", h)
    h = re.sub(r"<br\s*/?>", "\n", h)
    h = re.sub(r"</p\s*>", "\n", h)
    h = re.sub(r"<[^>]+>", "", h)
    h = h.replace("&nbsp;", " ").replace("&amp;", "&").replace("&quot;", '"')
    return re.sub(r"\n{3,}", "\n\n", h).strip()


def split_page(text):
    """-> (body_lines, {footnote_no: text}) for one page.

    A page is laid out as the hadith text, then the footnote area. That area
    opens either with a numbered note, "(١) ...", or with a line beginning
    "=", which is a note carried over from the previous page. The "=" case
    matters: those lines are commentary, and treating them as body text
    silently appended a paragraph of takhrij prose to the hadith above them.
    """
    lines = [ln.strip() for ln in text.split("\n")]
    lines = [ln for ln in lines if ln]
    body, notes, cur, in_notes = [], {}, None, False
    for ln in lines:
        m = FOOT_LINE.match(ln)
        if m:
            cur, in_notes = ar_int(m.group(1)), True
            notes[cur] = m.group(2).strip()
        elif ln.startswith("="):
            in_notes = True          # carried over from the previous page
        elif in_notes:
            if cur is not None:
                notes[cur] = (notes[cur] + " " + ln).strip()
        else:
            body.append(ln)
    return body, notes



def first_sentence(s):
    """Arna'ut's judgement, in his own words, and nothing after it.

    The judgement opens the footnote; everything after it is the takhrij
    proper ("وأخرجه النسائي ... وأبو يعلى ...") and the discussion of the
    narrators. Cutting at the first full stop is usually right, but a
    judgement such as "حسن لغيره دون ذكر الجنب، وهذا إسناد ضعيف، نجي - وهو
    الحضرمي الكوفي - لم يرو عنه غير ابنه" runs past it, so the phrases that
    always begin the next thought are cut on as well.
    """
    s = s.strip().lstrip("=").strip()
    cuts = [len(s)]
    for stop in STOPS:
        i = s.find(stop)
        if i > 0:
            cuts.append(i)
    s = s[:min(cuts)].strip(" .،=")
    if len(s) <= 200:
        return s
    # Still long: keep whole clauses only, never half a sentence.
    parts = s.split("،")
    out = parts[0]
    for p in parts[1:]:
        if len(out) + len(p) + 1 > 200:
            break
        out += "،" + p
    return out.strip(" .،=")



def verdict_only(sent):
    """Arna'ut's verdict, without the justification that follows it.

    He writes the verdict first and then why: "إسناده صحيح، عثمان بن المغيرة
    الثقفي من رجال البخاري، وباقي رجاله ثقات ...". The card shows the verdict
    beside the grader's name, so it keeps the leading clause -- "إسناده صحيح",
    "حسن لغيره", "إسناده صحيح على شرط الشيخين" -- and drops the reasoning,
    which is a shortening of his words, never a change to them.
    """
    head = sent.split("،")[0].strip(" .،")
    if len(head) >= 6 and head.startswith(GRADE_OPENERS):
        return head
    return sent


def as_grade(note):
    """The ruling in [note], or None when it is not a ruling at all."""
    if not note:
        return None
    sent = first_sentence(note)
    if not sent or len(sent) > 200:
        return None
    return verdict_only(sent) if sent.startswith(GRADE_OPENERS) else None


TASHKEEL = re.compile("[ً-ْٰـ]")


def starts_musnad(text):
    """True when a numbered line opens a hadith rather than a list item.

    The edition's introduction contains its own numbered lists -- "١ - توثيقُ
    النص بمقابلة المطبوع بالأصول الخطية" and so on -- which look exactly like
    hadith lines and restart at 1 several times over. Every hadith in the
    Musnad opens with Abdullah narrating from his father, "حَدَّثَنَا", so the
    book proper is taken to begin at the first numbered line that does.
    """
    return TASHKEEL.sub("", text).lstrip().startswith("حدثنا")


def main():
    pages = {}
    with io.open(PAGES, encoding="utf-8") as f:
        for line in f:
            try:
                d = json.loads(line)
                pages[d["pageId"]] = d
            except Exception:
                pass
    if not pages:
        print("no pages fetched yet")
        return 1
    print(f"{len(pages)} pages, ids {min(pages)}..{max(pages)}")

    chapters, chapter_no_of = [], {}
    hadiths = []
    open_h = None          # hadith still collecting text across a page break
    started = False        # False while still in the editor's front matter
    last_num = 0
    page_notes = {}        # pageId -> {note_no: text}

    for pid in sorted(pages):
        page = pages[pid]
        title = (page.get("title") or "").strip()
        body, notes = split_page(strip_html(page.get("nass") or ""))
        page_notes[pid] = notes

        # Everything the page contributes, in order: (number|None, text)
        chunks, cur_num, buf = [], None, []
        for ln in body:
            m = NUM_LINE.match(ln)
            if m:
                if buf:
                    chunks.append((cur_num, " ".join(buf)))
                cur_num, buf = ar_int(m.group(1)), [m.group(2)]
            else:
                buf.append(ln)
        if buf:
            chunks.append((cur_num, " ".join(buf)))

        for num, text in chunks:
            if not started:
                if num is None or not starts_musnad(text):
                    continue
                started = True
            elif num is not None and num < last_num:
                # A numbered line running backwards is not a hadith.
                continue
            if num is None:
                if open_h is not None:
                    open_h["arabic"] += " " + text
                    open_h["end_page"] = pid
                continue
            if open_h is not None:
                hadiths.append(open_h)
            if title and title not in chapter_no_of:
                chapter_no_of[title] = len(chapters) + 1
                chapters.append({"no": len(chapters) + 1, "name_ar": title})
            last_num = num
            open_h = {
                "number": num,
                "chapter_no": chapter_no_of.get(title, 0),
                "arabic": text,
                "end_page": pid,
                "grade": None,
            }

    if open_h is not None:
        hadiths.append(open_h)

    # ── Rulings ─────────────────────────────────────────────────────────
    # The edition prints one ruling footnote per hadith, in order, in the
    # footnote block of the page the hadith ends on. The marker itself is a
    # superscript that does not survive as text on most pages, so pairing by
    # marker alone found barely half of them. Pairing by order does: take the
    # hadiths that end on a page and the footnotes on it that are actually
    # rulings, and when the two line up one-for-one, they are that hadith's.
    # When they do not line up, fall back to an explicit trailing marker, and
    # otherwise leave the hadith ungraded rather than guess which note is its.
    by_end = {}
    for h in hadiths:
        by_end.setdefault(h["end_page"], []).append(h)

    for pid, group in by_end.items():
        notes = page_notes.get(pid, {})
        rulings = [(n, as_grade(notes[n])) for n in sorted(notes)]
        rulings = [(n, g) for n, g in rulings if g]
        if len(rulings) == len(group):
            for h, (_, g) in zip(group, rulings):
                h["grade"] = g
            continue
        for h in group:
            m = TRAIL_MARK.search(h["arabic"])
            if m:
                g = as_grade(notes.get(ar_int(m.group(1))))
                if g:
                    h["grade"] = g

    # Clean the stored text: drop footnote markers, collapse whitespace.
    for h in hadiths:
        t = re.sub(r"\([٠-٩]+\)", " ", h["arabic"])
        h["arabic"] = re.sub(r"\s+", " ", t).strip()
        h.pop("end_page", None)

    graded = sum(1 for h in hadiths if h["grade"])
    print(f"hadiths: {len(hadiths)}  graded: {graded} "
          f"({graded * 100 // max(1, len(hadiths))}%)  chapters: {len(chapters)}")
    io.open(OUT, "w", encoding="utf-8", newline="\n").write(
        json.dumps({"chapters": chapters, "hadiths": hadiths},
                   ensure_ascii=False))
    print("wrote", OUT)
    return 0



if __name__ == "__main__":
    sys.exit(main())
