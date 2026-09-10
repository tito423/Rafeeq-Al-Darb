# -*- coding: utf-8 -*-
"""Build one downloadable SQLite pack per language from `hadeethenc.db`.

WHAT A PACK IS
`dist/hadeethenc/<lang>.zip` holding a single `hadeethenc_<lang>.db`. That
shape is not a choice — `DownloadManager._unzipToDatabases` takes the first
`.db` in the archive and drops it in the app's `databases/` directory, which
is exactly how `hadith.zip` already works.

WHY PER LANGUAGE AND NOT ONE FILE
`hadeethenc.db` is 60.5 MB for seven languages. A reader wants one. Each pack
is self-contained — it carries the Arabic original (`hadeeth_ar`,
`attribution_ar`, `grade_ar`) beside every translation, because the app shows
the Arabic and the translation together — so no pack depends on another.

WHY SQLITE AND NOT GZIPPED JSON LIKE THE QUR'AN TRANSLATIONS
A translation pack is 6,236 short ayah strings. This is 3,574 records each
carrying a hadith, a takhrij, a grading, an explanation and a list of hints;
Arabic alone is ~14 MB of text. CLAUDE.md trap #4 is exactly this — one
`_db.query('hadiths')` over the full corpus tried an 83 MB allocation and threw
`OutOfMemoryError` on a real device — and a `jsonDecode` of a 14 MB document
builds the whole object graph at once. SQLite lets the reader page.

NO FTS5 (trap #1). Android's SQLite has no FTS5 module and a
`CREATE VIRTUAL TABLE ... USING fts5` inside `onCreate` kills `openDatabase`
outright. Search is a `search` column normalised the same way
`lib/core/utils/arabic_normalize.dart` normalises, matched in Dart.

    py -3 scripts/build_hadeethenc_packs.py [lang ...]
"""

import io
import json
import os
import re
import sqlite3
import sys
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "hadeethenc.db")
CATS = os.path.join(ROOT, "hadeethenc_categories.json")
OUT = os.path.join(ROOT, "dist", "hadeethenc")
LOCALES = ["ar", "en", "es", "fr", "pt", "ru", "ur"]

# The Dart side of this lives in `lib/core/utils/arabic_normalize.dart`; the
# two must agree character for character or a query normalised on the device
# will not match a column normalised here. Codepoints are spelled out for the
# same reason they are there: a literal combining mark is unreviewable.
_DIACRITICS = re.compile(
    "[ؐ-ًؚ-ٟۖ-ۭـ]")
_ALEF_VARIANTS = re.compile("[آأإٰٱ]")


def normalize(s):
    out = _DIACRITICS.sub("", s or "")
    out = _ALEF_VARIANTS.sub("ا", out)
    out = out.replace("ى", "ي")   # alef maksura -> yeh
    return out.lower()


SCHEMA = """
CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT);
CREATE TABLE categories (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    title_ar TEXT NOT NULL,
    hadeeth_count INTEGER NOT NULL);
CREATE TABLE hadeeths (
    id TEXT PRIMARY KEY,
    category_id TEXT NOT NULL,
    title TEXT,
    hadeeth TEXT,
    attribution TEXT,
    grade TEXT,
    explanation TEXT,
    hints TEXT,
    reference TEXT,
    hadeeth_ar TEXT,
    attribution_ar TEXT,
    grade_ar TEXT,
    words_ar TEXT,
    search TEXT);
CREATE INDEX hadeeths_category ON hadeeths(category_id);
"""


def build(lang, cats, src):
    os.makedirs(OUT, exist_ok=True)
    db_name = "hadeethenc_%s.db" % lang
    db_path = os.path.join(OUT, db_name)
    zip_path = os.path.join(OUT, "%s.zip" % lang)
    for p in (db_path, zip_path):
        if os.path.exists(p):
            os.remove(p)

    out = sqlite3.connect(db_path)
    out.executescript(SCHEMA)

    rows = src.execute(
        "SELECT t.id, h.category_id, t.title, t.hadeeth, t.attribution,"
        "       t.grade, t.explanation, t.hints, t.reference,"
        "       t.hadeeth_ar, t.attribution_ar, t.grade_ar,"
        "       h.words_meanings_ar"
        "  FROM texts t JOIN hadeeths h ON h.id = t.id"
        " WHERE t.lang = ?"
        " ORDER BY CAST(h.category_id AS INTEGER), CAST(t.id AS INTEGER)",
        (lang,)).fetchall()

    per_cat = {}
    ungraded = 0
    no_takhrij = 0
    with_words = 0
    for r in rows:
        (hid, cat, title, hadeeth, attribution, grade, explanation, hints,
         reference, hadeeth_ar, attribution_ar, grade_ar, words_ar) = r
        # Arabic is its own original: the crawl leaves `*_ar` empty on the
        # Arabic row rather than duplicating the same string twice. Fill it
        # here so every pack answers the same question the same way.
        if lang == "ar":
            hadeeth_ar = hadeeth
            attribution_ar = attribution
            grade_ar = grade
        if not (grade or "").strip():
            ungraded += 1
        if not (attribution or "").strip():
            no_takhrij += 1
        if (words_ar or "[]") not in ("", "[]"):
            with_words += 1
        per_cat[cat] = per_cat.get(cat, 0) + 1
        # معاني الكلمات — the per-hadith glossary. It is Arabic whatever the
        # pack's language is, because it explains the ARABIC word; a reader of
        # the translation still meets the original above it.
        out.execute(
            "INSERT INTO hadeeths VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
            (hid, cat, title, hadeeth, attribution, grade, explanation,
             hints, reference, hadeeth_ar, attribution_ar, grade_ar,
             words_ar or "[]",
             normalize("%s %s" % (title or "", hadeeth or ""))))

    for cid in sorted(cats, key=int):
        if per_cat.get(cid):
            out.execute("INSERT INTO categories VALUES (?,?,?,?)",
                        (cid, cats[cid][lang], cats[cid]["ar"], per_cat[cid]))

    meta = {
        "lang": lang,
        "count": str(len(rows)),
        "source_ar": "موسوعة الأحاديث النبوية",
        "source_en": "Hadeeth Encyclopedia (HadeethEnc.com)",
        "source_url": "https://hadeethenc.com",
        "built_from": "hadeethenc.com/api/v1",
        # The publisher's own redistribution terms, read from the "الشروط
        # والسياسات" modal on hadeethenc.com/ar/home on
        # 2026-09-10. Redistribution IS permitted, conditionally — CLAUDE.md
        # trap #18 is why this was read before a byte was rehosted rather
        # than after.
        "terms_url": "https://hadeethenc.com/ar/home",
        "terms_summary_ar": "يتاح تنزيل محتوى الترجمات وإعادة نشره "
                            "بشرط عدم التعديل أو الإضافة أو الحذف، "
                            "والإشارة بوضوح للناشر وللمصدر (HadeethEnc.com)، "
                            "وذكر رقم الإصدار، وعدم تضمين إعلانات "
                            "لا تليق بمحتوى الأحاديث.",
        # Condition 3 asks for the version number and condition 4 for the
        # version information "inside the document". The API carries neither:
        # `hadeeths/one/` returns no version field, `hadeeths/list/`'s `meta`
        # is only paging, and the PDF downloads answer with a placeholder
        # `Last-Modified: Thu, 26 Mar 2000`. So the retrieval date is what is
        # true and what is recorded; nothing is invented to fill the field.
        "version": "",
        "retrieved_hadeeths": "2026-09-09",
        "retrieved_categories": "2026-09-10",
    }
    for k, v in meta.items():
        out.execute("INSERT INTO meta VALUES (?,?)", (k, v))

    out.commit()
    out.execute("VACUUM")
    out.close()

    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        z.write(db_path, db_name)

    return {
        "lang": lang,
        "hadeeths": len(rows),
        "db_bytes": os.path.getsize(db_path),
        "zip_bytes": os.path.getsize(zip_path),
        "ungraded": ungraded,
        "no_takhrij": no_takhrij,
        "with_words": with_words,
        "categories": sum(1 for c in cats if per_cat.get(c)),
    }


def main():
    wanted = [a for a in sys.argv[1:] if not a.startswith("-")] or LOCALES
    cats = json.load(io.open(CATS, encoding="utf-8"))
    src = sqlite3.connect(SRC)

    report = []
    for lang in wanted:
        report.append(build(lang, cats, src))

    path = os.path.join(ROOT, "hadeethenc_packs.json")
    with io.open(path, "w", encoding="utf-8", newline="\n") as f:
        json.dump(report, f, ensure_ascii=False, indent=2)
        f.write("\n")

    # Windows' console is cp1256 and cannot print Arabic (trap #10), so the
    # summary is deliberately ASCII.
    for r in report:
        print("%-3s %5d hadeeths  %3d cats  db %7.2f MB  zip %6.2f MB"
              "  ungraded %d  no-takhrij %d  glossary %d"
              % (r["lang"], r["hadeeths"], r["categories"],
                 r["db_bytes"] / 1e6, r["zip_bytes"] / 1e6,
                 r["ungraded"], r["no_takhrij"], r["with_words"]))
    print("wrote %s" % path)


if __name__ == "__main__":
    main()
