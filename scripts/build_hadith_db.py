"""Builds scripts/pipeline_zips/hadith.{db,zip} from the real hadith-json
dumps already staged in scripts/temp_phase1/hadith9/ (source:
A7med3bdulBaset/hadith-json on GitHub, the same source HANDOVER.md/
RAFEEQ_PIPELINE.md already credit). No hadith text is invented; every row
comes straight from those files.

The output is NOT bundled into the Flutter app — it's uploaded to the
rafeeq-api content repo and downloaded on demand (see AppConfig.hadithDbUrl,
DbHelper.openDownloaded), the same pattern as mushaf pages/recitations,
because at ~74 MB it would otherwise roughly double the APK's size.

Fixes the ordering bug WORK_QUEUE.md flags for STAGE 2 ("hadith ordering was
previously broken — jumping 2 -> 9 -> 99"): that happens when a hadith number
is sorted/stored as TEXT ("2" < "9" < "99" lexicographically breaks the moment
you hit two digits). `number_in_book` here is INTEGER, and every query in the
app must ORDER BY it as a number, never as a string.

P2‑13 (2026‑09‑03): real per-hadith gradings, from a second real source —
scripts/temp_phase1/hadith_grades/{abudawud,tirmidhi,nasai,ibnmajah}.json,
an MIT-licensed sunnah.com-derived dataset (huggingface.co/datasets/
meeAtif/hadith_datasets) that carries a "Grade" string like "Hasan Sahih
(Al-Albani)" or "Sahih (Darussalam)" per hadith. It has no idInBook numbering
compatible with this build's own dataset (confirmed: Ibn Majah's global
sunnah.com numbering starts at 267, 266 ahead of this dataset's book-local
count, and the other three books' numbering only coincidentally lines up for
their first few hadiths) — so hadiths are matched between the two sources by
normalized Arabic text instead (see `_norm_arabic`), which measured a 93.9–
100% match rate per book (`scripts/temp_phase1/match_results2.txt`); anything
that doesn't match — including, for Ibn Majah, its ~266-hadith Muqaddimah,
which this grading source doesn't cover at all — keeps `grade`/`grader` NULL,
never a guess. Bukhari and Muslim stay NULL too: they're sahih by definition
(that's what "sahih" in their titles means, and is exactly what the grading
source itself encodes by leaving every one of their rows blank) — the app
shows a "من الصحيحين" badge for those two books directly, not from this
column. No graded, redistributable source was found for Muwatta Malik (or
for Ahmad/al-Darimi, the two extra books beyond the Home card's needed 7) —
their `grade`/`grader` are honestly NULL, not invented.
"""
import glob
import io
import json
import os
import re
import sqlite3
import unicodedata
import zipfile

BASE = r"e:\My Projects\Rafiq-Al-Darb\scripts\temp_phase1\hadith9"
GRADES_DIR = r"e:\My Projects\Rafiq-Al-Darb\scripts\temp_phase1\hadith_grades"
# Not under rafeeq_app/ — this is a regenerable ~74 MB pipeline artifact,
# never bundled into the app (hadith.db is downloaded, see AppConfig.hadithDbUrl
# and DbHelper.openDownloaded). scripts/pipeline_zips/ is already gitignored.
OUT_DIR = r"e:\My Projects\Rafiq-Al-Darb\scripts\pipeline_zips"
OUTDB = os.path.join(OUT_DIR, "hadith.db")
OUTZIP = os.path.join(OUT_DIR, "hadith.zip")

_TASHKIL = re.compile("[\u064b-\u0652\u0670\u0640]")
_STRIP_CATS = {"Cf", "Po", "Pd", "Pi", "Pf", "Ps", "Pe"}


def _norm_arabic(s):
    """Content-only fingerprint for matching the same hadith across two
    independent sunnah.com scrapes: strips harakat/tatweel, every Unicode
    "format" control char (RLM/LRM — the two sources differ here, e.g. one
    has a bare newline where the other has an RTL-marked space around a
    quoted saying) and all punctuation, then collapses whitespace. Verified
    (scripts/temp_phase1/match_test2.py) to raise the match rate from ~50%
    with a naive whitespace-only normalize to 93.9–100%.
    """
    if not s:
        return ""
    s = _TASHKIL.sub("", s)
    s = "".join(ch for ch in s if unicodedata.category(ch) not in _STRIP_CATS)
    return re.sub(r"\s+", " ", s).strip()


def _split_grade(raw):
    """'Hasan Sahih (Al-Albani)' -> ('Hasan Sahih', 'Al-Albani'). Falls back
    to (raw, None) if there's no trailing "(...)" to read a grader from."""
    m = re.match(r"^(.*?)\s*\(([^()]+)\)\s*$", raw)
    if m:
        return m.group(1).strip(), m.group(2).strip()
    return raw.strip(), None


def load_grades(book_key):
    """book_key -> {normalized_arabic: (grade_text, grader)}. Empty dict for
    books with no graded source (see module docstring)."""
    path = os.path.join(GRADES_DIR, f"{book_key}.json")
    if not os.path.exists(path):
        return {}
    with open(path, encoding="utf-8") as f:
        rows = json.load(f)
    index = {}
    for r in rows:
        raw_grade = (r.get("Grade") or "").strip()
        if not raw_grade:
            continue
        key = _norm_arabic(r.get("Arabic_Text", ""))
        if not key:
            continue
        index[key] = _split_grade(raw_grade)
    return index

report = io.StringIO()


def out(s=""):
    # stdout on this Windows console can't encode the em dash / Arabic
    # titles (cp1252) — the report file (opened as UTF-8 below) is the
    # source of truth; stdout gets an ASCII-safe echo so the run isn't
    # silently killed by a UnicodeEncodeError.
    print(s.encode("ascii", "replace").decode("ascii"))
    report.write(s + "\n")


# Canonical order: the "Six Books" (Kutub al-Sittah) first, then the three
# more that round this app's set out to nine, matching the "9 authentic
# collections" copy already used across HANDOVER/WORK_QUEUE/the app itself.
BOOK_ORDER = [
    "bukhari", "muslim", "abudawud", "tirmidhi", "nasai", "ibnmajah",
    "ahmed", "malik", "darimi",
]

os.makedirs(OUT_DIR, exist_ok=True)
if os.path.exists(OUTDB):
    os.remove(OUTDB)
con = sqlite3.connect(OUTDB)
cur = con.cursor()
cur.executescript("""
CREATE TABLE books(
  id INTEGER PRIMARY KEY,
  book_key TEXT NOT NULL UNIQUE,
  sort_order INTEGER NOT NULL,
  name_ar TEXT NOT NULL, name_en TEXT NOT NULL,
  author_ar TEXT NOT NULL, author_en TEXT NOT NULL,
  hadith_count INTEGER NOT NULL, chapter_count INTEGER NOT NULL
);
CREATE TABLE chapters(
  book_id INTEGER NOT NULL, chapter_no INTEGER NOT NULL,
  name_ar TEXT NOT NULL, name_en TEXT NOT NULL,
  PRIMARY KEY(book_id, chapter_no)
);
CREATE TABLE hadiths(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  book_id INTEGER NOT NULL,
  chapter_no INTEGER NOT NULL,
  number_in_book INTEGER NOT NULL,
  arabic TEXT NOT NULL,
  narrator_en TEXT,
  text_en TEXT,
  grade TEXT,
  grader TEXT
);
CREATE INDEX idx_hadiths_book_chapter_num
  ON hadiths(book_id, chapter_no, number_in_book);
CREATE INDEX idx_hadiths_book_num ON hadiths(book_id, number_in_book);
-- detail='none' (no position/snippet data) instead of FTS5's default
-- 'full': cuts the index from ~20MB to a few MB across 40k+ hadiths, at the
-- cost of snippet()/highlight() and phrase queries — the app builds its own
-- "…context around the match…" preview from the raw text instead. Given how
-- large this dataset already is (real content, not something to trim), that
-- trade is worth taking rather than bundling the extra weight.
CREATE VIRTUAL TABLE hadiths_fts USING fts5(
  arabic, text_en, content='hadiths', content_rowid='id', detail='none'
);
""")

total_hadiths = 0
total_chapters = 0
total_graded = 0
for order, key in enumerate(BOOK_ORDER, start=1):
    path = os.path.join(BASE, f"{key}.json")
    with open(path, encoding="utf-8") as f:
        data = json.load(f)

    meta = data["metadata"]
    chapters = data["chapters"]
    hadiths = data["hadiths"]
    grades = load_grades(key)
    book_graded = 0

    cur.execute(
        "INSERT INTO books(id, book_key, sort_order, name_ar, name_en, "
        "author_ar, author_en, hadith_count, chapter_count) "
        "VALUES(?,?,?,?,?,?,?,?,?)",
        (
            order, key, order,
            meta["arabic"]["title"], meta["english"]["title"],
            meta["arabic"]["author"], meta["english"]["author"],
            len(hadiths), len(chapters),
        ),
    )

    for ch in chapters:
        cur.execute(
            "INSERT INTO chapters(book_id, chapter_no, name_ar, name_en) "
            "VALUES(?,?,?,?)",
            (order, ch["id"], ch["arabic"] or "", ch["english"] or ""),
        )
    total_chapters += len(chapters)

    for h in hadiths:
        eng = h.get("english")
        narrator = eng.get("narrator") if isinstance(eng, dict) else None
        text_en = eng.get("text") if isinstance(eng, dict) else (
            eng if isinstance(eng, str) else None
        )
        grade_text = grader = None
        hit = grades.get(_norm_arabic(h["arabic"] or ""))
        if hit:
            grade_text, grader = hit
            book_graded += 1
        cur.execute(
            "INSERT INTO hadiths(book_id, chapter_no, number_in_book, "
            "arabic, narrator_en, text_en, grade, grader) VALUES(?,?,?,?,?,?,?,?)",
            (order, h["chapterId"], h["idInBook"], h["arabic"] or "",
             narrator, text_en, grade_text, grader),
        )
    total_hadiths += len(hadiths)
    total_graded += book_graded
    out(f"{key}: {meta['english']['title']} — "
        f"{len(chapters)} chapters, {len(hadiths)} hadiths, "
        f"{book_graded} graded" + (" (no graded source)" if not grades else ""))

cur.execute("INSERT INTO hadiths_fts(rowid, arabic, text_en) "
            "SELECT id, arabic, text_en FROM hadiths")

con.commit()

# ── sanity checks ────────────────────────────────────────────────────
out()
out(f"TOTAL: {len(BOOK_ORDER)} books, {total_chapters} chapters, "
    f"{total_hadiths} hadiths, {total_graded} graded "
    f"({100*total_graded/total_hadiths:.1f}%)")

# The ordering-bug regression check: within any chapter that has >=10
# hadiths, number_in_book must come back strictly increasing when sorted
# as INTEGER (this is exactly the "2 -> 9 -> 99" bug WORK_QUEUE flags).
bad = 0
for book_id, chapter_no in cur.execute(
    "SELECT DISTINCT book_id, chapter_no FROM hadiths"
).fetchall():
    nums = [r[0] for r in cur.execute(
        "SELECT number_in_book FROM hadiths WHERE book_id=? AND chapter_no=? "
        "ORDER BY number_in_book", (book_id, chapter_no)).fetchall()]
    if nums != sorted(nums):
        bad += 1
out(f"chapters with out-of-order integer numbering after ORDER BY: {bad} "
    "(must be 0)")

cur.execute("VACUUM")
con.commit()
con.close()

size_mb = os.path.getsize(OUTDB) / 1024 / 1024
out(f"hadith.db size: {size_mb:.1f} MB")

if os.path.exists(OUTZIP):
    os.remove(OUTZIP)
with zipfile.ZipFile(OUTZIP, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as z:
    z.write(OUTDB, "hadith.db")
zip_mb = os.path.getsize(OUTZIP) / 1024 / 1024
out(f"hadith.zip size: {zip_mb:.1f} MB (this is what gets uploaded/downloaded — "
    "DownloadManager.unzipToDatabases expects a .zip)")

with open(r"e:\My Projects\Rafiq-Al-Darb\scripts\hadith_report.txt", "w",
          encoding="utf-8") as f:
    f.write(report.getvalue())
print("\nreport written to scripts/hadith_report.txt")
