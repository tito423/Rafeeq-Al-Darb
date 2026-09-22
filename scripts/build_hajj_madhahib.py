"""«في المذاهب الأربعة» for the Hajj guide, from al-Jaziri's كتاب الحج.

The owner, 2026-09-22: «بالنسبة للحج والعمرة شوف افضل كتب على الشاملة
وطورها من جديد بوسطية». The guide's step-by-step text stays al-Nawawi's
«الإيضاح» (ordered as the journey is travelled); under each step this adds
what the four schools say, from «الفقه على المذاهب الأربعة» by عبد الرحمن
الجزيري (ت ١٣٦٠هـ), Shamela 9849 — an Azhari work written to show the four
side by side, which is what «بوسطية» asks of a guide that must not pick one
school's rulings and present them as the only ones.

WHY THIS IS NOT build_book_text.py. In this book the schools' positions are
in the HAMESH, and the hamesh is al-Jaziri's own text: the body states the
ruling and «وخالف الحنفية…»; the footnote spells out «الحنفية قالوا: …
المالكية قالوا: …». The book builder drops the hamesh as editor's apparatus,
which here would drop the four schools. Read before writing (§1.4):
  * a note runs on across pages — p592's hamesh finishes p591's note on
    الطواف before anything about السعي;
  * a page whose body is all footnote prints a row of dots;
  * notes are numbered «(١)», afresh on every page, and the body carries the
    same numbers — so a note is tied to the section whose body holds its
    marker on the same page. Nothing is assigned by guesswork; a note whose
    marker cannot be found is reported and left out.

Raw pages are kept verbatim in scripts/jaziri_raw/<pageId>.json (ids 569-640,
كتاب الحج through زيارة القبر الشريف).

    py -3 scripts/build_hajj_madhahib.py [--report]
"""
import html
import io
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(ROOT, "scripts", "jaziri_raw")
OUT = os.path.join(ROOT, "rafeeq_app", "assets", "data", "hajj_madhahib.json")
REPORT = os.path.join(ROOT, "scripts", "build_hajj_madhahib_out.txt")
FIRST, LAST = 569, 640

SCHOOLS = ("الحنفية", "المالكية", "الشافعية", "الحنابلة")
DOTS = re.compile(r"^[\s.·،]+$")


def clean(fragment):
    t = re.sub(r"<br\s*/?>", "\n", fragment)
    t = re.sub(r"<[^>]+>", "", t)
    return html.unescape(t).replace(" ", " ")


def read_page(pid):
    d = json.load(io.open(os.path.join(RAW, f"{pid}.json"), encoding="utf-8"))
    nass = d.get("nass") or ""
    body_html, _, foot_html = nass.partition("<hr>")
    body = []
    for m in re.finditer(r"<p\b[^>]*>(.*?)</p>", body_html, re.S):
        inner = m.group(1)
        head = re.search(r'<span class="c4">(.*?)</span>', inner, re.S)
        text = re.sub(r"\s+", " ", clean(inner)).strip()
        if not text or DOTS.match(text):
            continue
        body.append({"t": text, "head": bool(head) and len(text) < 160})
    foot = []
    for m in re.finditer(r'<p class="hamesh">(.*?)</p>', foot_html, re.S):
        for line in clean(m.group(1)).split("\n"):
            line = re.sub(r"\s+", " ", line).strip()
            if line:
                foot.append(line)
    return {"id": pid, "printed": int(d.get("pageNum") or 0), "body": body, "foot": foot}


MARK = re.compile(r"\(([٠-٩0-9]+)\)")
NOTE_START = re.compile(r"^\s*\(([٠-٩0-9]+)\)\s*")


def notes_from(pages):
    """The hamesh stream split into notes. A note opens with its number,
    «(١) …», numbered afresh on every page exactly as the body's markers are;
    a line with no number continues the note before it — including a page's
    first line, which is the previous page's note running on."""
    notes = []
    for pg in pages:
        for line in pg["foot"]:
            m = NOTE_START.match(line)
            if m:
                notes.append({"page": pg["id"], "num": m.group(1), "t": line[m.end():]})
            elif notes:
                notes[-1]["t"] += "\n" + line
            else:
                notes.append({"page": pg["id"], "num": None, "t": line, "orphan": True})
    return notes


def split_schools(text):
    """A note as the schools' own statements, «الحنفية قالوا: …» each."""
    parts = re.split(r"(?=(?<![^\s.،؛:])(?:" + "|".join(SCHOOLS) + r")\s*(?:قالوا|قال)\s*[:؛])",
                     text)
    return [re.sub(r"\s+", " ", x).strip() for x in parts if x.strip()]


def sections_from(pages):
    """Body headings in order; each keeps its body paragraphs and the note
    numbers its body carries, as (pageId, number)."""
    secs = []
    for pg in pages:
        for para in pg["body"]:
            if para["head"]:
                secs.append({"title": para["t"].strip("[] "), "from": pg["id"],
                             "body": [], "pages": {pg["id"]}, "marks": set()})
            elif secs:
                secs[-1]["body"].append(para["t"])
                secs[-1]["pages"].add(pg["id"])
                for n in MARK.findall(para["t"]):
                    secs[-1]["marks"].add((pg["id"], n))
    return secs


# Which Jaziri sections each guide step draws on, by the heading's own words.
# Steps with no counterpart in a book arranged by topic (قبل السفر، يوم
# التروية، النصيحة) carry nothing rather than something near.
STEP_SECTIONS = {
    "obligation": ["حكمه، ودليله", "متى يجب الحج", "شروط وجوبه", "شروط وجوب الحج",
                   "الاستطاعة", "شروط صحة الحج"],
    "child": ["شروط صحة الحج"],
    "mawaqit": ["مواقيت الإحرام"],
    "ihram": ["أركان الحج", "الركن الأول من أركان الحج>تعريفه", "ما يطلب من مريد الإحرام"],
    "nusuk": ["مبحث القرآن، والتمتع"],
    "prohibitions": ["ما لا يجوز للمحرم", "ستر وجه المرأة", "لبس الثوب المصبوغ", "شم الطيب",
                     "إزالة شعر الرأس", "الخضاب بالحناء", "هل يجوز للمحرم", "الاكتحال",
                     "حكم قطع حشيش الحرم", "ما يباح للمحرم", "غسل الرأس", "ما يمنع الحاج",
                     "ما يوجب الفدية"],
    "tawaf": ["الركن الثاني من أركان الحج", "تعريف طواف الإفاضة", "وقت طواف الإفاضة",
              "شروط الطواف", "سنن الطواف"],
    "sai": ["الركن الثالث من أركان الحج", "شروط السعي"],
    # «سنن الحج» opens, in all four schools, with the night at Mina before
    # Arafah — the day of التروية.
    "tarwiyah": ["سنن الحج"],
    "arafah": ["الركن الرابع"],
    # «واجبات الحج» is a bare heading; the body and every note sit under the
    # one that follows, which is where al-Jaziri treats Muzdalifah, the
    # pebbles, the nights at Mina and the farewell tawaf together.
    "muzdalifah": ["رمي الجمار"],
    "nahr": ["رمي الجمار"],
    "tashreeq": ["رمي الجمار"],
    "farewell": ["رمي الجمار"],
    "hady": ["مبحث الهدي>تعريفه", "أقسام الهدي", "وقت ذبح الهدي", "مبحث الأكل من الهدي",
             "ما يشترط في الهدي"],
    "visitation": ["زيارة قبر النبي"],
    "umrah_obligation": ["مبحث العمرة", "حكمها ودليله", "شروطها", "أركان العمرة"],
    "umrah_miqaat": ["ميقاتها"],
    "umrah_ihram": ["ما يطلب من مريد الإحرام"],
    "umrah_prohibitions": ["ما لا يجوز للمحرم", "ما يباح للمحرم"],
    "umrah_rites": ["واجباتها، وسننها"],
    "umrah_invalidating": ["واجباتها، وسننها", "مفسدات الحج"],
}

def main():
    pages = [read_page(i) for i in range(FIRST, LAST + 1)]
    secs = sections_from(pages)
    notes = notes_from(pages)
    rep = io.open(REPORT, "w", encoding="utf-8")
    orphans = [n for n in notes if "orphan" in n]
    rep.write(f"pages {len(pages)}  sections {len(secs)}  notes {len(notes) - len(orphans)}"
              f"  orphan hamesh lines {len(orphans)}\n")
    for n in orphans:
        rep.write(f"  ORPHAN p{n['page']}: {n['t'][:160]}\n")

    unlinked = 0
    for n in notes:
        if n.get("orphan"):
            continue
        hit = [i for i, sec in enumerate(secs) if (n["page"], n["num"]) in sec["marks"]]
        if len(hit) != 1:
            unlinked += 1
            rep.write(f"\nUNLINKED note ({n['num']}) p{n['page']}: {n['t'][:160]}\n")
            continue
        n["section"] = hit[0]
    rep.write(f"\nunlinked notes: {unlinked}\n")
    for s_i, sec in enumerate(secs):
        sec["notes"] = [n for n in notes if n.get("section") == s_i]
        rep.write(f"\n[{s_i}] «{sec['title']}» p{min(sec['pages'])}-{max(sec['pages'])}: "
                  f"{len(sec['body'])} body paras, {len(sec['notes'])} notes\n")

    steps, missing = {}, []
    for step, wanted in STEP_SECTIONS.items():
        parts = []
        for w in wanted:
            if ">" in w:  # «parent>child»: the child heading right after parent
                parent, child = w.split(">")
                hit = [secs[i + 1] for i, x in enumerate(secs[:-1])
                       if x["title"].startswith(parent) and secs[i + 1]["title"] == child]
            else:
                hit = [x for x in secs if x["title"].startswith(w)]
            if len(hit) != 1:
                missing.append(f"{step}: «{w}» matched {len(hit)}")
                continue
            s = hit[0]
            parts.append({
                "title": s["title"],
                "printed": [pg["printed"] for pg in pages if pg["id"] in s["pages"]][0],
                "body": s["body"],
                "notes": [split_schools(n["t"]) for n in s["notes"]],
            })
        steps[step] = parts
    for m in missing:
        rep.write(f"MISSING {m}\n")
    rep.close()
    sys.stdout.buffer.write(open(REPORT, "rb").read())
    if missing:
        sys.exit("unmatched headings — fix STEP_SECTIONS")
    if "--report" in sys.argv:
        return
    doc = {
        "source": {
            "titleAr": "الفقه على المذاهب الأربعة",
            "authorAr": "عبد الرحمن بن محمد عوض الجزيري (ت ١٣٦٠هـ)",
            "edition": "دار الكتب العلمية، بيروت، الطبعة الثانية ١٤٢٤هـ - ٢٠٠٣م",
            "shamelaUrl": "https://shamela.ws/book/9849",
        },
        "steps": steps,
    }
    io.open(OUT, "w", encoding="utf-8", newline="\n").write(
        json.dumps(doc, ensure_ascii=False, separators=(",", ":")))
    print(f"\nwrote {OUT} ({os.path.getsize(OUT)} B)")


if __name__ == "__main__":
    main()
