"""Take the modern editors' notes that carry the named scholars out of three
hosted books — the owner's ruling of 2026-09-22:

    «شيل أي حاجة لابن باز وابن عثيمين وابن جبرين وابن عبد الوهاب والألباني
    إلا التخريج، وأي حد معروف بالتشدد؛ لو شيلها يضر الكتاب سيبها، مش هيضر
    شيلها»

How the list below was arrived at (measured 2026-09-22 on all 213 hosted
books, downloaded from the public endpoint, every size equal to the catalogue):
every paragraph naming عثيمين / ابن باز / ابن جبرين / الجبرين / الألباني /
بن عبد الوهاب was read in context. Left alone, on purpose:
  * takhrij — a hadith graded, or a narrator judged, by al-Albani (111
    paragraphs) or Ibn Baz (bulugh al-maram p177, where the editor REFUTES his
    tahsin): the ruling's own exception;
  * namesakes — «عبد الرحمن بن سليمان العثيمين» the historian-editor,
    «بالبان بن بازران» in al-Bidaya, every «… بن عبد الوهاب» (all classical
    narrators; no mention of the Najdi anywhere), «جبرين» as a spelling of
    Jibril;
  * bibliographies and edition notes that merely list a book of theirs;
  * anything in an AUTHOR's own text (al-Raheeq names Ibn Taymiyyah and the
    Najdi's «مختصر السيرة» — that is al-Mubarakpuri's text, not an editor's).

What is taken out is an editor's opinion or praise, never a word of the
author's. Every cut must match EXACTLY ONCE or the script stops. Only two
words are changed rather than removed: «أمران: الأول:» → «» in al-Muwafaqat,
because the sentence that was «الآخر» is the one removed.

    py -3 scripts/strip_named_notes.py [--dry]
"""
import gzip
import io
import json
import os
import re
import subprocess
import sys
import urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from r2_common import BUCKET, r2_client  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CATALOG = os.path.join(ROOT, "rafeeq_app", "lib", "features", "library", "data",
                       "book_catalog.dart")
PUBLIC = "https://pub-39dbef68a1a845d5ba669b43a59516b9.r2.dev"
UA = "RafeeqAlDarb/3.56 (https://github.com/tito423/Rafeeq-Al-Darb) curl/8"
OUT = os.path.join(ROOT, "scripts", "strip_named_notes_out")

# (book, old, new) — `old` must occur exactly once in the book.
CUTS = [
    # Mashhur Hasan's introduction: how «شيخنا الألباني» came to the Salafi
    # da'wa. His opinion-history, nothing of al-Shatibi's.
    ("al_muwafaqat",
     "ومن الجدير بالذكر هنا أمران: الأول: أن الشاطبي مجدد ومصلح، وأن كتابه "
     "\"الموافقات\" تضمن التجديد، وكتاب \"الاعتصام\" تضمن الإصلاح. والآخر: أن "
     "شيخنا الألباني -حفظه الله- عرف \"الدعوة السلفية\" في أول أمره عن طريق "
     "محمد رشيد رضا.",
     "ومن الجدير بالذكر هنا أن الشاطبي مجدد ومصلح، وأن كتابه \"الموافقات\" "
     "تضمن التجديد، وكتاب \"الاعتصام\" تضمن الإصلاح."),
    # The editor asked al-Albani whether al-Shatibi met Ibn Taymiyyah.
    ("al_muwafaqat",
     "وسألتُ شيخنا الألباني -حفظه الله- عن هذه المسألة؛ فأجاب بأنه لم يثبت عنده "
     "ولم يطلع على ما يسمح بالجزم أو باحتمال أن تكون اللقيا قد تمت بين الشاطبي "
     "وابن تيمية أو ابن القيم.",
     None),  # None: the whole paragraph goes
    # A footnote on Banu Qurayza: Draz's note («"د".») stays; the editor's
    # «قلت: وسمعت شيخنا الألباني …» polemic that follows it goes, to the end
    # of the paragraph (its continuation page was already stripped).
    ("al_muwafaqat", re.compile(r" قلت: وسمعت شيخنا الألباني -حفظه الله- مرارًا.*$", re.S), ""),
    # Ighathat al-Lahfan: an editor's footnote citing Ibn Uthaymeen's fiqh
    # choice. The two classical references either side of it stay.
    ("ighathat_al_lahfan_fi_hukm_talaq_al_ghadban",
     "وهو اختيار شيخنا محمد بن صالح العثيمين -رحمه الله- انظر: «الشرح الممتع» (٢/ ١٩). ",
     ""),
    # Musnad Abi Bakr: the editor's gloss on «الناصبة» quotes Ibn Uthaymeen;
    # the lexical definition before it and Shawqi Abu Khalil after it stay.
    ("musnad_abi_bakr",
     "قال ابن عثيمين (ت ١٤٢١ هـ): \"النواصب هم الذين ينصبون العداء لآل البيت، "
     "ويقدحون فيهم، يسبونهم، فهم على النقيض من السنة\"، وقال شوقي أبو خليل",
     "قال شوقي أبو خليل"),
]

# Whole sections that are an editor's, located by TOC title and ended by the
# next TOC title. al-Muwafaqat's «ترجمة محقق الكتاب» is a student's eulogy of
# the editor («بقلم تلميذه أبي العباس الأثري») that opens his list of teachers
# with al-Albani; not a line of it is al-Shatibi's.
SECTIONS = [("al_muwafaqat", "ترجمة محقق الكتاب مشهور بن حسن آل سلمان", "الفهارس")]


def text(p):
    return p["t"] if isinstance(p, dict) else p


def load(bid):
    req = urllib.request.Request(f"{PUBLIC}/books/text/{bid}.json", headers={"User-Agent": UA})
    raw = urllib.request.urlopen(req, timeout=300).read()
    return json.loads(gzip.decompress(raw) if raw[:2] == b"\x1f\x8b" else raw)


def apply_cut(doc, old, new):
    hits = []
    for pg in doc["pages"]:
        for j, para in enumerate(pg["paras"]):
            t = text(para)
            n = len(old.findall(t)) if isinstance(old, re.Pattern) else t.count(old)
            if n:
                hits.append((pg, j, n))
    if len(hits) != 1 or hits[0][2] != 1:
        sys.exit(f"cut matched {sum(h[2] for h in hits)} times, not once: {str(old)[:60]}")
    pg, j, _ = hits[0]
    t = text(pg["paras"][j])
    if new is None:
        if t.strip() != old.strip():
            sys.exit(f"whole-paragraph cut is not the whole paragraph: {old[:60]}")
        del pg["paras"][j]
    else:
        t = old.sub(new, t) if isinstance(old, re.Pattern) else t.replace(old, new)
        pg["paras"][j] = {**pg["paras"][j], "t": t} if isinstance(pg["paras"][j], dict) else t
    return pg


def drop_section(doc, title, until):
    first = lambda pg: text(pg["paras"][0]).strip() if pg["paras"] else ""
    idx = [i for i, pg in enumerate(doc["pages"]) if first(pg) == title]
    end = [i for i, pg in enumerate(doc["pages"]) if first(pg) == until]
    if len(idx) != 1 or len(end) != 1 or end[0] <= idx[0]:
        sys.exit(f"section «{title}» not found exactly once ({idx}, {end})")
    a, b = idx[0], end[0]
    del doc["pages"][a:b]
    toc = doc["toc"]
    ti = [i for i, e in enumerate(toc) if e["title"] == title]
    if len(ti) != 1:
        sys.exit(f"toc entry «{title}» not found exactly once")
    del toc[ti[0]]
    for e in toc[ti[0]:]:
        e["pageIndex"] = max(0, e["pageIndex"] - (b - a))
    return b - a


def public_ok(bid, size):
    url = f"{PUBLIC}/books/text/{bid}.json"
    head = subprocess.run(["curl", "-sSI", "-A", UA, url], capture_output=True, text=True).stdout
    first = subprocess.run(["curl", "-sS", "-A", UA, "-r", "0-1", url], capture_output=True).stdout
    length = re.search(r"Content-Length:\s*(\d+)", head, re.I)
    return (first[:2] == b"\x1f\x8b" and length and int(length.group(1)) == size
            and not re.search(r"Content-Encoding", head, re.I))


def main():
    dry = "--dry" in sys.argv
    os.makedirs(OUT, exist_ok=True)
    books = sorted({c[0] for c in CUTS} | {s[0] for s in SECTIONS})
    rep = io.open(os.path.join(OUT, "report.txt"), "w", encoding="utf-8")
    built = {}
    for bid in books:
        doc = load(bid)
        before = sum(len(text(p)) for pg in doc["pages"] for p in pg["paras"])
        for b, old, new in CUTS:
            if b == bid:
                pg = apply_cut(doc, old, new)
                rep.write(f"\n{bid} p{pg.get('p')}: cut «{str(old)[:80]}…»\n")
        for b, title, until in SECTIONS:
            if b == bid:
                n = drop_section(doc, title, until)
                rep.write(f"\n{bid}: section «{title}» removed ({n} pages)\n")
        after = sum(len(text(p)) for pg in doc["pages"] for p in pg["paras"])
        doc["meta"]["pageCount"] = len(doc["pages"])
        doc["meta"]["namedNotesStrippedBy"] = "scripts/strip_named_notes.py"
        body = gzip.compress(json.dumps(doc, ensure_ascii=False).encode("utf-8"), mtime=0)
        open(os.path.join(OUT, bid + ".json"), "wb").write(body)
        built[bid] = body
        rep.write(f"{bid}: {before} -> {after} chars ({before - after} removed), {len(body)} B\n")
    rep.close()
    sys.stdout.buffer.write(open(os.path.join(OUT, "report.txt"), "rb").read())
    if dry:
        return
    s3 = r2_client()
    src = io.open(CATALOG, encoding="utf-8").read()
    for bid, body in built.items():
        s3.put_object(Bucket=BUCKET, Key=f"books/text/{bid}.json", Body=body,
                      ContentType="application/json")
        if not public_ok(bid, len(body)):
            sys.exit(f"{bid}: public endpoint did not return the uploaded bytes")
        src, n = re.subn(r"(/books/text/" + bid + r"\.json',\s*sizeBytes: )\d+",
                         lambda m: m.group(1) + str(len(body)), src)
        if n != 1:
            sys.exit(f"{bid}: catalogue entry found {n} times")
        print("uploaded + verified + catalogued", bid, len(body))
    io.open(CATALOG, "w", encoding="utf-8", newline="\n").write(src)


if __name__ == "__main__":
    main()
