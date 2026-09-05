"""Builds the structured *text* edition of a Library book from al-Maktaba
al-Shamela (shamela.ws) — the P2-4b "نص" edition that sits beside the scanned
image PDF.

WHY THIS EXISTS
---------------
Every catalog book already ships as a scanned image PDF (see
`lib/features/library/data/book_catalog.dart`). The owner also wants each book
as a real *text* edition: a chapter tree (فهرس), in-book search, selectable
text, font control. Shamela is the owner's chosen source (2026-09-02) and its
texts are keyed to a specific printed edition — see the sourcing table in
`PHASE2.md` (stage P2-4b) for which Shamela book id / edition was picked per
title and why.

HOW SHAMELA SERVES A BOOK
------------------------
One JSON blob per *printed page*:

    GET https://shamela.ws/ajax/pageContent/<bookId>/<pageId>
    -> {"nass": "<p>…</p>", "pageNum": <printed page number>,
        "title": "<section title, or ''>", "nextId": "<id|null>",
        "prevId": "<id|null>", "pageId": <int>}

`pageId` is Shamela's internal 1..N counter; `pageNum` is the real printed
page. Walk `nextId` from pageId 1 until it is null to get the whole book.
Pages whose `title` is non-empty start a new section — that is the chapter
tree.

`nass` markup (only these matter):
  * <span class="c3">…</span>  a Qur'an ayah
  * <span class="c4">…</span>  a citation / reference, e.g. [٢٥ الأنبياء]
  * <span class="c5">…</span>  a bold lead-in ("قال:", "أما بعد:")
  * <a class="btn_tag">…</a>   a per-paragraph copy button — dropped
  * <div class="hamesh">…</div> the muḥaqqiq's footnote apparatus — dropped
    (keeps the reader clean and shrinks the copyright surface; the base text
    is public domain, a modern editor's notes may not be — see PHASE2 P2-4b).

OUTPUT (one file per book, hosted on tito423/rafeeq-api as books/text/<id>.json)
-----------------------------------------------------------------------------
    {
      "id": "al_ubudiyyah",
      "schema": 1,
      "meta": {"titleAr","authorAr","sourceLabel","shamelaId","shamelaUrl",
               "printMatches": true, "pageCount", "sectionCount",
               "builtAt", "builtFrom"},
      "toc":  [{"title": "...", "page": <printed>, "pageIndex": <0-based>}],
      "pages":[{"p": <printed page number>,
                "paras": [{"t": "<plain text>", "k": "body|aya|ref|head"}]}]
    }

Nothing is invented: every paragraph is text Shamela served for that page.
OCR is never involved (Shamela is typed text), so `isOcr` is always false for
these editions.

USAGE
-----
    python scripts/build_book_text.py            # builds all 5 catalog books
    python scripts/build_book_text.py al_fawaid  # just one (id from BOOKS)

Writes to  scripts/book_text_build/<id>.json  and prints a verification
summary (page count, section count, first/last printed page, a text sample).
Only the Python standard library is used (matches build_hadith_db.py).
"""

import html
import http.client
import json
import os
import re
import ssl
import sys
import time
from datetime import datetime, timezone

# --- the 5 catalog books and the exact Shamela edition chosen for each -------
# id  -> must match LibraryBook.id in book_catalog.dart
# See PHASE2.md stage P2-4b "Sourcing decisions" for the reasoning.
BOOKS = {
    "riyad_as_salihin": {
        "shamela_id": 12014,
        "source_label": "المكتبة الشاملة — رياض الصالحين، تحقيق شعيب الأرنؤوط، "
        "مؤسسة الرسالة، بيروت، الطبعة الثالثة ١٤١٩هـ/١٩٩٨م",
    },
    "mukhtasar_minhaj_al_qasidin": {
        "shamela_id": 98087,
        # The title page credits a taʿlīq by the Arnaut brothers on top of
        # Dahman's تقديم — recorded here for honest provenance (the muḥaqqiq
        # footnote apparatus itself is stripped by parse_nass's hamesh removal).
        "source_label": "المكتبة الشاملة — مختصر منهاج القاصدين، تقديم محمد "
        "أحمد دهمان وتعليق شعيب وعبد القادر الأرناؤوط، مكتبة دار البيان، "
        "دمشق، ١٣٩٨هـ/١٩٧٨م",
    },
    "al_fawaid": {
        "shamela_id": 6832,
        "source_label": "المكتبة الشاملة — الفوائد لابن القيم، دار الكتب "
        "العلمية، بيروت، الطبعة الثانية ١٣٩٣هـ/١٩٧٣م",
    },
    "sayd_al_khatir": {
        "shamela_id": 12028,
        "source_label": "المكتبة الشاملة — صيد الخاطر، بعناية حسن المساحي "
        "سويدان، دار القلم، دمشق، الطبعة الأولى ١٤٢٥هـ/٢٠٠٤م",
    },
    "al_ubudiyyah": {
        "shamela_id": 22647,
        "source_label": "المكتبة الشاملة — العبودية لابن تيمية، تحقيق محمد "
        "زهير الشاويش، المكتب الإسلامي، بيروت، الطبعة السابعة ١٤٢٦هـ/٢٠٠٥م",
    },
    # --- P3-15 catalog expansion (2026-09-03), نص-only (no مصوّر hunted for
    # these — see book_catalog.dart's LibraryBook.hasImage doc) -------------
    "al_aqidah_al_wasitiyyah": {
        "shamela_id": 22665,
        "source_label": "المكتبة الشاملة — العقيدة الواسطية لابن تيمية، "
        "تحقيق أشرف بن عبد المقصود",
    },
    "nawadir_al_usul": {
        "shamela_id": 720,
        # Owner-facing honesty, not a licence flag: classical hadith
        # scholarship (this DB's own upstream sources, e.g. sunnah.com-style
        # grading notes) lists this book among the sources that carry a
        # number of weak/unverified narrations — real for any edition of
        # this specific book, unrelated to Shamela or this project. Recorded
        # in LibraryBook.descriptionAr so it's visible in the app, not
        # buried.
        "source_label": "المكتبة الشاملة — نوادر الأصول في أحاديث الرسول "
        "للحكيم الترمذي، تحقيق عبد الرحمن عميرة، دار الجيل، بيروت",
    },
    "al_samt_wa_adab_al_lisan": {
        "shamela_id": 13039,
        "source_label": "المكتبة الشاملة — الصمت وآداب اللسان لابن أبي "
        "الدنيا، تحقيق أبو إسحاق الحويني الأثري، دار الكتاب العربي، بيروت، "
        "الطبعة الأولى ١٤١٠هـ/١٩٩٠م",
    },
    # --- P3-43 #16 (2026-09-05): growing the same 3-author set with one more
    # real title each, per PHASE3.md's own safe-default guidance (owner's ask
    # was open-ended; no scope answer given this round). Each id/edition
    # verified directly against its shamela.ws landing page before being
    # added here — printMatches=True and a real موافق-للمطبوع flag for all 3,
    # not assumed.
    "qasr_al_amal": {
        "shamela_id": 6899,
        "source_label": "المكتبة الشاملة — قصر الأمل لابن أبي الدنيا، تحقيق "
        "محمد خير رمضان يوسف، دار ابن حزم، بيروت، الطبعة الثانية "
        "١٤١٧هـ/١٩٩٧م",
    },
    "al_hasanah_wa_al_sayyiah": {
        "shamela_id": 7609,
        "source_label": "المكتبة الشاملة — الحسنة والسيئة لابن تيمية، دار "
        "الكتب العلمية، بيروت",
    },
    "adab_al_nafs": {
        "shamela_id": 37054,
        "source_label": "المكتبة الشاملة — أدب النفس للحكيم الترمذي، تحقيق "
        "د. أحمد عبد الرحيم السايح، الدار المصرية اللبنانية، مصر، الطبعة "
        "الأولى ١٤١٣هـ/١٩٩٣م",
    },
}

OUT_DIR = os.path.join(os.path.dirname(__file__), "book_text_build")
UA = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/126.0 Safari/537.36"
)
REQUEST_DELAY_S = 0.15  # be polite to shamela.ws (~1.5 req/s incl. latency)
HOST = "shamela.ws"

# This box's bundled Python has no CA bundle (and the machine has had TLS
# interception trouble before — HANDOVER.md §7). Certificate verification adds
# nothing for a read-only scrape of public pages, so use an unverified context
# and a single keep-alive connection (much faster than spawning curl per page).
_CTX = ssl._create_unverified_context()
_conn = None  # type: http.client.HTTPSConnection | None


def _get(path, tries=4):
    """`path` is the URL path (e.g. '/ajax/pageContent/12014/1')."""
    global _conn
    last = None
    for attempt in range(tries):
        try:
            if _conn is None:
                _conn = http.client.HTTPSConnection(HOST, timeout=30, context=_CTX)
            _conn.request("GET", path, headers={
                "User-Agent": UA,
                "Accept": "*/*",
                "Connection": "keep-alive",
            })
            resp = _conn.getresponse()
            body = resp.read()
            if resp.status != 200:
                raise RuntimeError(f"HTTP {resp.status}")
            return body.decode("utf-8", "replace")
        except Exception as e:  # noqa: BLE001, PERF203 — reconnect and retry
            last = e
            try:
                if _conn:
                    _conn.close()
            finally:
                _conn = None
            time.sleep(1.0 * (attempt + 1))
    raise RuntimeError(f"GET failed after {tries} tries: {path} ({last})")


def fetch_meta_card(shamela_id):
    """The بطاقة الكتاب block on the book landing page (edition, page count…)."""
    h = _get(f"/book/{shamela_id}")
    m = re.search(r'<div style="line-height: 1\.8;">(.*?)</div>', h, re.S)
    card = ""
    if m:
        card = re.sub(r"<br\s*/?>", "\n", m.group(1))
        card = re.sub(r"<[^>]+>", "", card).strip()
    title = ""
    tm = re.search(r"الكتاب:\s*(.+)", card)
    if tm:
        title = tm.group(1).strip()
    author = ""
    am = re.search(r"المؤلف:\s*(.+)", card)
    if am:
        author = am.group(1).strip()
    print_matches = "موافق للمطبوع" in card
    return {
        "card": card,
        "title": title,
        "author": author,
        "print_matches": print_matches,
    }


# --- parse one page's `nass` HTML ---------------------------------------------
_P_RE = re.compile(r"<p\b[^>]*>(.*?)</p>", re.S)
_HAMESH_RE = re.compile(r'<div[^>]*class="[^"]*hamesh[^"]*"[^>]*>.*?</div>', re.S)
_BTN_TAG_RE = re.compile(r'<a[^>]*class="[^"]*btn_tag[^"]*"[^>]*>.*?</a>', re.S)
_ANCHOR_RE = re.compile(r'<span[^>]*class="[^"]*anchor[^"]*"[^>]*>.*?</span>', re.S)
_C3_RE = re.compile(r'<span[^>]*class="[^"]*\bc3\b[^"]*"[^>]*>(.*?)</span>', re.S)
_C4_RE = re.compile(r'<span[^>]*class="[^"]*\bc4\b[^"]*"[^>]*>(.*?)</span>', re.S)
_TAG_RE = re.compile(r"<[^>]+>")
_WS_RE = re.compile(r"[ \t ]+")


def _clean_text(fragment):
    """HTML fragment -> plain, whitespace-normalised text."""
    txt = _TAG_RE.sub("", fragment)
    txt = html.unescape(txt)
    txt = txt.replace("\r", " ").replace("\n", " ")
    txt = _WS_RE.sub(" ", txt)
    return txt.strip()


def parse_nass(nass):
    """Return a list of {"t": str, "k": "body|aya|ref|head"}."""
    nass = _HAMESH_RE.sub("", nass)  # drop the footnote apparatus block
    out = []
    for raw_p in _P_RE.findall(nass):
        p = _BTN_TAG_RE.sub("", raw_p)
        p = _ANCHOR_RE.sub("", p)

        plain = _clean_text(p)
        if not plain:
            continue

        # A whole paragraph that is just a bracketed line = a heading
        # (Shamela uses [مقدمة المؤلف], [باب كذا] …).
        stripped = plain.strip()
        if (
            len(stripped) <= 120
            and stripped.startswith("[")
            and stripped.endswith("]")
        ):
            out.append({"t": stripped[1:-1].strip(), "k": "head"})
            continue

        # Ayah-dominant paragraph: the c3 span text is most of the paragraph.
        c3_parts = [_clean_text(x) for x in _C3_RE.findall(p)]
        c3_len = sum(len(x) for x in c3_parts)
        if c3_parts and c3_len >= 0.6 * len(plain):
            aya = " ".join(x for x in c3_parts if x)
            ref_parts = [_clean_text(x) for x in _C4_RE.findall(p)]
            ref = next((x for x in ref_parts if x), "")
            out.append({"t": aya, "k": "aya", **({"r": ref} if ref else {})})
            continue

        out.append({"t": plain, "k": "body"})
    return out


# --- walk a whole book ------------------------------------------------------
def build_book(book_id, shamela_id, source_label):
    base = f"/ajax/pageContent/{shamela_id}"
    meta_card = fetch_meta_card(shamela_id)

    pages = []
    toc = []
    seen_ids = set()
    page_id = "1"
    n = 0
    last_title = None
    while page_id is not None:
        if page_id in seen_ids:
            raise RuntimeError(f"loop detected at pageId {page_id}")
        seen_ids.add(page_id)

        raw = _get(f"{base}/{page_id}")
        data = json.loads(raw)
        printed = int(data.get("pageNum") or 0)
        title = (data.get("title") or "").strip()
        paras = parse_nass(data.get("nass") or "")

        # Shamela returns the *nearest* heading for every page, so a section
        # that spans several pages repeats its title — collapse those so each
        # فهرس entry points at the page the section starts on.
        if title and title != last_title:
            # level 0 = a major division (كتاب … / مقدمة / خطبة), else a باب/فصل.
            level = 0 if re.match(r"^(كتاب |مقدمة|خطبة|تمهيد)", title) else 1
            toc.append({
                "title": title, "page": printed,
                "pageIndex": len(pages), "level": level,
            })
        last_title = title or last_title
        pages.append({"p": printed, "paras": paras})

        n += 1
        if n % 25 == 0:
            print(f"  … {n} pages (printed p.{printed})")

        nxt = data.get("nextId")
        page_id = str(nxt) if nxt not in (None, "", 0, "0") else None
        time.sleep(REQUEST_DELAY_S)

    doc = {
        "id": book_id,
        "schema": 1,
        "meta": {
            "titleAr": meta_card["title"],
            "authorAr": meta_card["author"],
            "sourceLabel": source_label,
            "shamelaId": shamela_id,
            "shamelaUrl": f"https://shamela.ws/book/{shamela_id}",
            "printMatches": meta_card["print_matches"],
            # Some Shamela books (e.g. 12014) carry the موافق للمطبوع flag but
            # their `pageNum` values are still out of order in stretches — see
            # `print_reliable()`. The reader only *shows* printed-page numbers
            # and enables "go to printed page" when this is true.
            "printReliable": print_reliable(pages, meta_card["print_matches"]),
            "editionCard": meta_card["card"],
            "pageCount": len(pages),
            "sectionCount": len(toc),
            "builtAt": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "builtFrom": "scripts/build_book_text.py (shamela.ws ajax/pageContent)",
        },
        "toc": toc,
        "pages": pages,
    }
    return doc


def print_reliable(pages, print_matches):
    """True when the printed page numbers can be trusted (safe to show and to
    navigate by). Requires the موافق-للمطبوع flag, near-perfect monotonicity,
    AND no large backward jump — Riyad as-Salihin / book 12014 keeps the flag
    yet its `pageNum` drops ~100 four times through the book."""
    nums = [p["p"] for p in pages if p["p"]]
    if not print_matches or len(nums) < 10:
        return False
    deltas = [b - a for a, b in zip(nums, nums[1:])]
    ok = sum(1 for d in deltas if d >= 0)
    min_delta = min(deltas)
    return ok / len(deltas) >= 0.985 and min_delta >= -3


def verify_and_print(doc):
    pages = doc["pages"]
    toc = doc["toc"]
    n_paras = sum(len(p["paras"]) for p in pages)
    n_chars = sum(len(pa["t"]) for p in pages for pa in p["paras"])
    printed_nums = [p["p"] for p in pages if p["p"]]
    empty_pages = sum(1 for p in pages if not p["paras"])

    print("  ---- verification ----")
    print(f"  edition card:\n    " + doc["meta"]["editionCard"].replace("\n", "\n    "))
    print(f"  printMatches (ترقيم موافق للمطبوع): {doc['meta']['printMatches']}")
    print(f"  printReliable (page numbers monotonic): {doc['meta']['printReliable']}")
    print(f"  pages: {len(pages)}   sections(فهرس): {len(toc)}   "
          f"paragraphs: {n_paras}   chars: {n_chars}")
    if printed_nums:
        print(f"  printed page range: {min(printed_nums)}..{max(printed_nums)}")
    print(f"  pages with no text: {empty_pages}")
    if toc[:3]:
        print("  first sections: " + " | ".join(
            f"{t['title']} (ص{t['page']})" for t in toc[:3]))
    # a real text sample from ~1/3 through the book
    mid = pages[len(pages) // 3] if pages else {"paras": []}
    sample = next((pa["t"] for pa in mid["paras"] if pa["k"] == "body"), "")
    print(f"  sample (ص{mid.get('p')}): {sample[:260]}")
    if empty_pages > len(pages) * 0.1:
        print("  !! WARNING: many empty pages — parser or source problem")
    if not doc["meta"]["printMatches"]:
        print("  !! WARNING: this Shamela copy is NOT marked موافق للمطبوع")


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    want = sys.argv[1:] or list(BOOKS)
    for book_id in want:
        if book_id not in BOOKS:
            print(f"unknown book id: {book_id} (known: {', '.join(BOOKS)})")
            continue
        cfg = BOOKS[book_id]
        print(f"\n=== {book_id}  (shamela {cfg['shamela_id']}) ===")
        doc = build_book(book_id, cfg["shamela_id"], cfg["source_label"])
        out = os.path.join(OUT_DIR, f"{book_id}.json")
        with open(out, "w", encoding="utf-8") as f:
            json.dump(doc, f, ensure_ascii=False, separators=(",", ":"))
        size = os.path.getsize(out)
        print(f"  wrote {out}  ({size/1024:.0f} KB)")
        verify_and_print(doc)


if __name__ == "__main__":
    main()
