"""Cut an-Nawawi's «الأذكار» into the azkar sections and items the app shows.

WHY THIS EXISTS
---------------
The azkar feature was built on «حصن المسلم» by سعيد بن وهف القحطاني (d. 1439
AH / 2018) — his name is inside the bundled database itself, in `azkar_items`
row 2's footnote. The duas are prophetic and free; the SELECTION, the
arrangement, the 134 chapter titles and the takhrij are his, which is the same
thing 23 books were removed from the library for in v3.29.0.

WHAT THE SOURCE ACTUALLY LOOKS LIKE — measured, not assumed (§1.4)
------------------------------------------------------------------
Counted over all 411 pages of the hosted `al_adhkar_nawawi.json`:

  * 4,414 body paragraphs and only 19 marked `head` — so the structure is NOT
    in the `k` field. Every chapter opening is typographic: «(باب ما يقولُ إذا
    استيقظَ مِن مَنامه)» in plain parentheses, on its own line. 328 of those,
    plus 11 where the heading opens a paragraph that continues.
  * 1,250 numbered narrations, «٣٦ - وروينا في …», Arabic-Indic digits.
  * 309 paragraphs are عبد القادر الأرنؤوط's footnotes, carried in the ordinary
    body stream exactly as trap #34 describes — «(١) أي: أكثرها رفعا
    لدرجاتكم. (*)». 295 of them close with «(*)».
  * 60 more paragraphs are the editor's inserted quotations of as-Suyuti and
    Ibn Hajar; one of them criticises an-Nawawi by name («فما أدري لِمَ أغفل
    المصنف - يعني النووي»), which is how you can tell it is not his.

al-Arna'ut died in 1425 AH / 2004, so his apparatus is in copyright under the
rule this project works to. None of it may reach the app.

WHY AN ITEM IS A WHOLE NARRATION AND NOT A BARE DUA
---------------------------------------------------
Ḥiṣn al-Muslim prints the dua alone with a takhrij line under it. an-Nawawi
prints it inside the narration that carries it, and the two shapes cannot be
converted into one another by a program. The quotation marks are not a reliable
boundary: «٣٧ - وروينا في " صحيح البخاري " عن حذيفةَ … قالَ: الحَمْدُ لِلَّهِ
الَّذي أحْيانا …» has the BOOK's name in quotes and part of the dua outside
them, while in «٣٨ - … قال: " إذَا اسْتَيْقَظَ أََحَدُكُمْ فَلْيَقُلْ: … "» the
whole hadith is quoted and the dua begins after «فَلْيَقُلْ». An extractor that
guessed would produce a clipped supplication somewhere in 1,250 entries and
nobody would notice — which is precisely what §1.2 forbids.

So an item is an-Nawawi's numbered narration, kept verbatim, with his own
attribution inside it where he wrote it. Nothing is reworded, joined or
trimmed.
"""

import argparse
import gzip
import io
import json
import re
import sys
import urllib.request

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")

BOOK_URL = ("https://pub-39dbef68a1a845d5ba669b43a59516b9.r2.dev"
            "/books/text/al_adhkar_nawawi.json")
# R2's public endpoint answers a bare urllib request with 403 — it wants a
# User-Agent (trap #19).
UA = "RafeeqAlDarb/3.30 (https://github.com/tito423/Rafeeq-Al-Darb) curl/8"

AR = "٠١٢٣٤٥٦٧٨٩"
# A chapter opening, alone on its line: «(باب …)» / «(بابٌ …)» / «(فصل …)».
# Longest alternative first, and NO «\b»: «باب» would otherwise win against
# «بابُ» and the damma would be left behind as the first character of the
# title — five chapters came out as «ُ تكبيرةِ الإِحْرام», «ُ الدُّعَاء بعدَ
# التشهّدِ الأخير». Arabic word boundaries are not what «\b» means anyway; it
# is the same family of mistake as trap #47.
_BAB = r"(?:بابٌ|بابُ|باب|فصلٌ|فصل)"
BAB_ALONE = re.compile(r"^\(\s*" + _BAB + r"[^)]*\)$")
# The same heading followed by an-Nawawi's own opening sentence. The title is
# the WHOLE parenthesised text, exactly as in BAB_ALONE, so the two paths
# cannot disagree about what a chapter is called.
BAB_LEADS = re.compile(r"^\((\s*" + _BAB + r"[^)]*)\)\s*(.+)$")
ENTRY = re.compile(r"^[" + AR + r"]+\s*-\s*\S")
# al-Arna'ut's footnote: opens with a bracketed number, and 295 of the 309
# close with «(*)». Both signatures are required to open one so that an
# an-Nawawi paragraph that merely starts «(١)» is not swallowed.
FOOT_OPEN = re.compile(r"^\(\s*[" + AR + r"]+\s*\)")
# The takhrij vocabulary a footnote uses and an-Nawawi's running text does not
# — volume/page references and hadith numbers in the editor's own style.
FOOT_TAIL = re.compile(r"رواه .{0,40}رقم \(|في المسند \d|/ \d+ من حديث")
# A bare superscript marker left behind once its footnote is dropped, e.g.
# «وأرْفَعِها (١) في دَرَجَاتِكُمُ». The marker is al-Arna'ut's numbering, not
# an-Nawawi's word, and it points at a note the reader will never see.
MARKER = re.compile(r"\s*\(\s*[" + AR + r"]+\s*\)\s*")
# His inserted quotations of later scholars, and anything that speaks ABOUT
# an-Nawawi in the third person — the editor's voice, never the author's.
EDITOR_VOICE = re.compile(
    r"يعني النووي|يعني المصنف|قال المحقق|تحفة الأبرار|"
    r"قال السيوطي|قال الحافظ ابن حجر|المصنف رحمه الله"
)


def load(path_or_url):
    if path_or_url.startswith("http"):
        req = urllib.request.Request(path_or_url, headers={"User-Agent": UA})
        with urllib.request.urlopen(req, timeout=120) as r:
            raw = r.read()
    else:
        raw = open(path_or_url, "rb").read()
    # Hosted books are gzip with no Content-Encoding header (trap #6) — sniff.
    if raw[:2] == b"\x1f\x8b":
        raw = gzip.decompress(raw)
    return json.loads(raw.decode("utf-8"))


def is_editor(text):
    """True when this paragraph is the muhaqqiq's, not an-Nawawi's.

    The decisive mark is the closing «(*)». It was tempting to require the
    paragraph to OPEN with «(١)» as well, and that is what the first version
    did — which let through a footnote on page 18 that opens «= باب في دعاء
    النبي صلى الله عليه وسلم وتعوذه في دُبُرِ كُلّ صلاة …»: the continuation of
    the previous page's footnote area, exactly the leading «=» the Musnad
    Ahmad crawl had to learn about. 750 words of al-Arna'ut naming rijal and
    grading isnads would have shipped inside «فضل الذكر» as an-Nawawi's.

    So: anything closing with «(*)» is his, however it opens.
    """
    t = text.strip()
    # «(*)» ANYWHERE, not only at the end. Shamela sometimes runs an-Nawawi's
    # sentence and al-Arna'ut's note together in one paragraph that closes
    # «… وانظر "جامع العلوم والحكم" للحافظ ابن رجب (*) =», the «=» handing the
    # note on to the next page. Five paragraphs looked like that, and each was
    # hundreds of words of the editor grading isnads. There is no honest way to
    # split one of those by machine, so the whole paragraph goes: a few of
    # an-Nawawi's sentences are lost, which is a smaller wrong than publishing
    # a living editor's apparatus under his name.
    if "(*)" in t:
        return True
    if t.startswith("=") or t.startswith("؟ ="):
        return True
    if FOOT_OPEN.match(t) and FOOT_TAIL.search(t):
        return True
    if EDITOR_VOICE.search(t):
        return True
    return False


def strip_markers(text):
    """Drop the dead superscript markers, count how many went."""
    out, n = MARKER.subn(" ", text)
    return re.sub(r"\s+", " ", out).strip(), n


def cut(doc):
    """-> [{'title', 'page', 'items': [{'text', 'page', 'no'}]}]

    An ITEM is one of an-Nawawi's numbered narrations, not one paragraph. A
    narration that crosses a page break arrives as two paragraphs — «٣٢ - وروينا
    فيه وفي كتاب ابن ماجه عن أبي الدرداء رضي الله عنه قال: قال» then, overleaf,
    «رسول الله صلى الله عليه وسلم: "ألا أُنْبِئُكُمْ بِخَيْرِ أعمالِكُمْ …"» —
    and emitting those as two items leaves the second one orphaned on the
    screen, a hadith with no beginning. So paragraphs are joined to the
    narration they continue, and an-Nawawi's own words before the first number
    in a bab (his «يُستحبُّ أن يقول: بسْمِ الله» and the like) open the section
    as an unnumbered item.
    """
    sections = []
    cur = None
    dropped = {"footnote": 0, "editor": 0}
    markers = 0

    def add(text, page):
        nonlocal markers
        text, n = strip_markers(text)
        markers += n
        if not text:
            return
        m = ENTRY.match(text)
        if m or not cur["items"]:
            no = re.match(r"^([" + AR + r"]+)", text)
            cur["items"].append({"text": text, "page": page,
                                 "no": no.group(1) if m else None})
        else:
            cur["items"][-1]["text"] += " " + text

    for page in doc["pages"]:
        for para in page["paras"]:
            t = para["t"].strip()
            if not t:
                continue
            if is_editor(t):
                key = "footnote" if (t.endswith("(*)") or FOOT_OPEN.match(t)) \
                    else "editor"
                dropped[key] += 1
                continue
            m_alone = BAB_ALONE.match(t)
            m_leads = None if m_alone else BAB_LEADS.match(t)
            if m_alone or m_leads:
                title = (t[1:-1] if m_alone else m_leads.group(1)).strip()
                title, _ = strip_markers(title)
                cur = {"title": title, "page": page["p"], "items": []}
                sections.append(cur)
                if m_leads and m_leads.group(2).strip():
                    add(m_leads.group(2), page["p"])
                continue
            if cur is None:
                continue  # front matter, before the first bab
            add(t, page["p"])
    dropped["markers"] = markers
    return sections, dropped


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--source", default=BOOK_URL)
    ap.add_argument("--out", default="_azkar_adhkar.json")
    ap.add_argument("--report", default="_azkar_adhkar_report.txt")
    ap.add_argument("--show", type=int, default=0,
                    help="print this many sections in full, for reading")
    args = ap.parse_args()

    doc = load(args.source)
    sections, dropped = cut(doc)
    numbered = sum(1 for s in sections for i in s["items"] if ENTRY.match(i["text"]))
    total = sum(len(s["items"]) for s in sections)

    with io.open(args.report, "w", encoding="utf-8") as r:
        r.write("source: %s\n" % args.source)
        r.write("edition: %s\n" % doc["meta"]["sourceLabel"])
        r.write("pages: %d\n" % len(doc["pages"]))
        r.write("sections cut: %d\n" % len(sections))
        r.write("paragraphs kept: %d  (numbered narrations: %d)\n"
                % (total, numbered))
        r.write("dropped as the muhaqqiq's footnotes: %d\n" % dropped["footnote"])
        r.write("dropped as the muhaqqiq's inserted quotations: %d\n"
                % dropped["editor"])
        r.write("dead footnote markers stripped from an-Nawawi's text: %d\n"
                % dropped["markers"])
        r.write("\n--- every section, with its page and its item count ---\n")
        for i, s in enumerate(sections):
            r.write("%3d  p%-5s %2d items  %s\n"
                    % (i, s["page"], len(s["items"]), s["title"]))
        if args.show:
            r.write("\n--- the first %d sections in full ---\n" % args.show)
            for s in sections[:args.show]:
                r.write("\n======== «%s»  (p%s) ========\n" % (s["title"], s["page"]))
                for it in s["items"]:
                    r.write("  [p%s] %s\n" % (it["page"], it["text"]))

    with io.open(args.out, "w", encoding="utf-8") as f:
        json.dump({"source": args.source,
                   "edition": doc["meta"]["sourceLabel"],
                   "sections": sections}, f, ensure_ascii=False, indent=1)

    print("sections %d, paragraphs %d (%d numbered), dropped %d footnotes + "
          "%d editor insertions -> %s"
          % (len(sections), total, numbered, dropped["footnote"],
             dropped["editor"], args.report))


if __name__ == "__main__":
    main()
