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

import gzip
import html
import http.client
import io
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
    # Added 2026-09-10 for the Islamic-quote notifications: the owner named
    # these two by title and they were not in the catalogue. Their Shamela
    # ids were looked up in the local index (`shamela_index.py find`) rather
    # than through Shamela's own search, which searches INSIDE books and not
    # their titles (CLAUDE.md trap #17).
    "rawdat_al_uqala": {
        "shamela_id": 6944,
        "source_label": "المكتبة الشاملة — روضة العقلاء ونزهة الفضلاء، "
        "لأبي حاتم محمد بن حبان البستي، تحقيق محمد محيي الدين عبد الحميد "
        "وآخرين، دار الكتب العلمية، بيروت",
    },
    "hilyat_al_awliya": {
        "shamela_id": 10495,
        "source_label": "المكتبة الشاملة — حلية الأولياء وطبقات الأصفياء، "
        "لأبي نعيم الأصبهاني، مطبعة السعادة، مصر، الطبعة الأولى "
        "١٣٩٤هـ/١٩٧٤م",
    },
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
    # --- Hadith expansion (2026-09-08): the owner asked for the well-known
    # hadith books alongside the nine collections. Each Shamela id was
    # verified against its own book card and its pageContent API before
    # being listed here; the edition lines are copied from those cards.
    "bulugh_al_maram": {
        "shamela_id": 9111,
        "source_label": "المكتبة الشاملة — بلوغ المرام من أدلة الأحكام، "
        "أبو الفضل أحمد بن علي بن حجر العسقلاني (ت ٨٥٢هـ)، دار الفلق - "
        "الرياض، الطبعة السابعة ١٤٢٤هـ",
    },
    "al_adab_al_mufrad": {
        "shamela_id": 12991,
        "source_label": "المكتبة الشاملة — الأدب المفرد، محمد بن إسماعيل "
        "البخاري (ت ٢٥٦هـ)، تحقيق محمد فؤاد عبد الباقي، المطبعة السلفية "
        "ومكتبتها - القاهرة، الطبعة الثانية ١٣٧٩هـ",
    },
    "sahih_al_adab_al_mufrad": {
        "shamela_id": 1341,
        "source_label": "المكتبة الشاملة — صحيح الأدب المفرد للإمام البخاري، "
        "بأحكام محمد ناصر الدين الألباني، دار الصديق للنشر والتوزيع، "
        "الطبعة الرابعة ١٤١٨هـ/١٩٩٧م",
    },
    "al_shamail_al_muhammadiyyah": {
        "shamela_id": 23647,
        "source_label": "المكتبة الشاملة — الشمائل المحمدية، أبو عيسى محمد "
        "بن سورة الترمذي (ت ٢٧٩هـ)، إخراج وتعليق محمد أحمد حلاق، دار إحياء "
        "التراث العربي، بيروت",
    },
    "mishkat_al_masabih": {
        "shamela_id": 8360,
        "source_label": "المكتبة الشاملة — مشكاة المصابيح، محمد بن عبد الله "
        "الخطيب التبريزي، تحقيق محمد ناصر الدين الألباني، المكتب الإسلامي - "
        "بيروت، الطبعة الثالثة ١٩٨٥م",
    },
    "al_targhib_wal_tarhib": {
        "shamela_id": 6847,
        "source_label": "المكتبة الشاملة — الترغيب والترهيب من الحديث "
        "الشريف، زكي الدين عبد العظيم المنذري (ت ٦٥٦هـ)، تحقيق إبراهيم شمس "
        "الدين، دار الكتب العلمية - بيروت، الطبعة الأولى ١٤١٧هـ",
    },
    "umdat_al_ahkam": {
        "shamela_id": 538,
        "source_label": "المكتبة الشاملة — العمدة في الأحكام، عبد الغني بن "
        "عبد الواحد المقدسي (ت ٦٠٠هـ)، تحقيق عبد المحسن بن محمد القاسم، "
        "الطبعة الثانية ١٤٤٢هـ/٢٠٢١م",
    },
    # --- Seerah section + the titles the owner named (2026-09-09) ----------
    # Every `source_label` below is the edition line from that book's own
    # بطاقة الكتاب on shamela.ws, read before the crawl was started — not a
    # publisher guessed from the title. All twelve say «ترقيم الكتاب موافق
    # للمطبوع» except where noted, so the page numbers are the printed ones.
    "ar_raheeq_al_makhtum": {
        "shamela_id": 9820,
        "source_label": "المكتبة الشاملة — الرحيق المختوم، صفي الرحمن "
        "المباركفوري (ت ١٤٢٧هـ)، دار الفكر (طبعة خاصة بدار ومكتبة الهلال) - "
        "بيروت، ٢٠٠٢م",
    },
    "seerat_ibn_hisham": {
        "shamela_id": 7450,
        # Shamela's own note: this electronic copy carries only the first two
        # of the printed four volumes. Recorded here because the reader will
        # reach the end of volume 2 and should not think the book is corrupt.
        "source_label": "المكتبة الشاملة — السيرة النبوية لابن هشام "
        "(ت ٢١٣هـ)، قدّم لها وعلّق عليها وضبطها طه عبد الرؤوف سعد، شركة "
        "الطباعة الفنية المتحدة — النسخة الإلكترونية تقتصر على الجزأين "
        "الأولين",
    },
    "zad_al_maad": {
        "shamela_id": 21713,
        "source_label": "المكتبة الشاملة — زاد المعاد في هدي خير العباد، ابن "
        "قيم الجوزية (ت ٧٥١هـ)، تحقيق شعيب الأرنؤوط وعبد القادر الأرنؤوط، "
        "مؤسسة الرسالة - بيروت، الإصدار الثاني المنقّح المزيد، الطبعة الأولى "
        "١٤١٧هـ/١٩٩٦م",
    },
    # NOT re-crawled: al-Shamail is already in the catalogue as
    # `al_shamail_al_muhammadiyyah` (Shamela 23647, ط إحياء التراث).
    # Adding Shamela 13037 (ت الجليمي) would have put the same book in the
    # library twice under two ids.
    "sahih_as_seerah_albani": {
        "shamela_id": 592,
        # Shamela's own note: al-Albani died before finishing the abridgement,
        # reaching 2/94 of Abd al-Wahid's edition. An honest, real limit.
        "source_label": "المكتبة الشاملة — صحيح السيرة النبوية (من البداية "
        "والنهاية لابن كثير)، لخّصه وعلّق عليه محمد ناصر الدين الألباني "
        "(ت ١٤٢٠هـ)، المكتبة الإسلامية - عمّان، الطبعة الأولى ١٤٢١هـ — "
        "توفي الشيخ قبل إتمامه",
    },
    "uyun_al_athar": {
        "shamela_id": 23653,
        "source_label": "المكتبة الشاملة — عيون الأثر في فنون المغازي "
        "والشمائل والسير، ابن سيد الناس (ت ٧٣٤هـ)، تعليق إبراهيم محمد رمضان، "
        "دار القلم - بيروت، الطبعة الأولى ١٤١٤هـ/١٩٩٣م",
    },
    "nur_al_yaqin": {
        "shamela_id": 23692,
        "source_label": "المكتبة الشاملة — نور اليقين في سيرة سيد المرسلين، "
        "محمد بن عفيفي الباجوري المعروف بالشيخ الخضري (ت ١٣٤٥هـ)، دار الفيحاء "
        "- دمشق، الطبعة الثانية ١٤٢٥هـ",
    },
    "as_seerah_nadwi": {
        "shamela_id": 9914,
        "source_label": "المكتبة الشاملة — السيرة النبوية، أبو الحسن علي "
        "الحسني الندوي (ت ١٤٢٠هـ)، تحقيق وتعليق سيد عبد الماجد الغوري، دار "
        "ابن كثير - دمشق وبيروت، الطبعة الثانية عشرة ١٤٢٥هـ/٢٠٠٤م",
    },
    "fiqh_as_seerah_ghazali": {
        "shamela_id": 23659,
        "source_label": "المكتبة الشاملة — فقه السيرة، محمد الغزالي السقا "
        "(ت ١٤١٦هـ)، تخريج الأحاديث محمد ناصر الدين الألباني، دار القلم - "
        "دمشق، الطبعة الأولى ١٤٢٧هـ",
    },
    "as_seerah_ibn_kathir": {
        "shamela_id": 930,
        "source_label": "المكتبة الشاملة — السيرة النبوية، ابن كثير "
        "(ت ٧٧٤هـ)، مستلًّا من البداية والنهاية، تحقيق د. مصطفى عبد الواحد، "
        "عيسى البابي الحلبي - القاهرة، ١٣٩٥هـ/١٩٧٦م",
    },
    "rijal_hawl_ar_rasul": {
        "shamela_id": 9835,
        "source_label": "المكتبة الشاملة — رجال حول الرسول، خالد محمد خالد "
        "ثابت (ت ١٤١٦هـ)، دار الفكر - بيروت، الطبعة الأولى ١٤٢١هـ/٢٠٠٠م",
    },
    "la_tahzan": {
        "shamela_id": 12729,
        "source_label": "المكتبة الشاملة — لا تحزن، عائض بن عبد الله القرني، "
        "مكتبة العبيكان",
    },
}

OUT_DIR = os.path.join(os.path.dirname(__file__), "book_text_build")
RAW_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                       "shamela_raw")
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
    # P3-44: some editions' meta card uses "الكتاب : x" (space before the
    # colon) instead of "الكتاب: x" — a real Shamela page-template
    # variant found by hand (3 of 182 books in one batch came back with
    # an empty title/author because of it), not a guess. `\s*:` tolerates
    # both.
    title = ""
    tm = re.search(r"الكتاب\s*:\s*(.+)", card)
    if tm:
        title = tm.group(1).strip()
    author = ""
    am = re.search(r"المؤلف\s*:\s*(.+)", card)
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
def load_cache(book_id):
    """Pages already crawled by `fetch_shamela_pages.py`, keyed by pageId.

    That script stores one API response per line verbatim, which is the whole
    point of it: «changing how a book is parsed never costs another crawl of
    someone else's server». حلية الأولياء is 3,891 pages, and walking `nextId`
    one request at a time to re-read text already on disk would be both slow
    and rude.
    """
    path = os.path.join(RAW_DIR, f"{book_id}.jsonl")
    if not os.path.exists(path):
        return {}
    cache = {}
    with io.open(path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                doc = json.loads(line)
            except ValueError:
                continue
            cache[str(doc.get("pageId"))] = doc
    return cache


def build_book(book_id, shamela_id, source_label):
    base = f"/ajax/pageContent/{shamela_id}"
    cache = load_cache(book_id)
    if cache:
        print(f"  {len(cache)} pages read from the local crawl, not refetched")
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

        data = cache.get(str(page_id))
        if data is None:
            data = json.loads(_get(f"{base}/{page_id}"))
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


def write_book_json(doc, out_path):
    """P3-44: the owner asked for gzip compression to be a standing rule
    for every book text edition on R2 — real bandwidth savings for a
    reader on mobile data (typically 70-80% smaller; this JSON is heavy
    on repeated structure and Arabic text, which compresses very well).
    The app's own `BookText.fromFile` detects gzip by magic bytes, not
    the (unchanged) `.json` filename/URL, and still reads a plain,
    uncompressed file exactly as before — real backward compatibility,
    not a breaking format change. Writing it gzip-compressed here, at
    the one place every build script's output funnels through, means
    every future book is compressed by default without a separate
    after-the-fact pass (`gzip_and_reupload_all_books.py` exists only
    because this rule didn't exist yet when the first ~193 were built).
    """
    raw = json.dumps(doc, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    with open(out_path, "wb") as f:
        f.write(gzip.compress(raw, compresslevel=9))
    return len(raw), os.path.getsize(out_path)


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
        before, after = write_book_json(doc, out)
        print(f"  wrote {out}  ({after/1024:.0f} KB gzip, {before/1024:.0f} KB raw)")
        verify_and_print(doc)


if __name__ == "__main__":
    main()
