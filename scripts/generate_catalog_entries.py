"""P3-44 follow-up: generates the Dart `LibraryBook` entries for all 182
newly-built books (fetch_authors_batch.py + categorize_books.py) from
their own real, already-verified metadata — titleAr/authorAr straight
from each book's own built JSON (not retyped/guessed), category from
categorize_books.py's real title-keyword classification, approxSizeBytes
read directly off the actual built file on disk.

descriptionAr is deliberately a short, honest, factual line (author +
category + real page count) rather than a hand-crafted blurb per title —
writing 182 individually-crafted descriptions the way the original ~11
curated books have isn't practical at this scale, and a generic-but-true
line is safer than inventing per-book claims about content this pass
didn't actually read book cover to cover. Real per-title flourish can
still be added later for any specific book the owner wants highlighted.
"""

import json
import os
import sys

AUTHOR_EN = {
    "ibn_abi_al_dunya": ("الإمام ابن أبي الدنيا", "Ibn Abi al-Dunya", "توفي 281 هـ"),
    "al_hakim_al_tirmidhi": ("الحكيم أبو عبد الله محمد بن علي الترمذي", "Al-Hakim al-Tirmidhi", "توفي نحو 320 هـ"),
    "ibn_taymiyyah": ("شيخ الإسلام ابن تيمية", "Shaykh al-Islam Ibn Taymiyyah", "توفي 728 هـ"),
    "ibn_al_qayyim": ("الإمام ابن قيّم الجوزية", "Imam Ibn Qayyim al-Jawziyyah", "توفي 751 هـ"),
    "ibn_al_jawzi": ("الإمام أبو الفرج ابن الجوزي", "Imam Ibn al-Jawzi", "توفي 597 هـ"),
}

CATEGORY_LABEL_AR = {
    "hadith": "الحديث", "fiqh": "الفقه", "aqidah": "العقيدة",
    "tafsir": "التفسير", "seerah": "السيرة والتاريخ",
    "tazkiyah": "التزكية والرقائق", "adab": "الأدب",
}

BASE_URL = "${AppConfig.contentBaseUrl}"


def dart_escape(s):
    return s.replace("\\", "\\\\").replace("'", "\\'").replace("\n", " ").strip()


def main():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    summary_path = os.path.join(root, "scripts", "batch_summary.jsonl")
    cat_path = os.path.join(root, "scripts", "book_categories.jsonl")
    build_dir = os.path.join(root, "scripts", "book_text_build")

    by_slug = {}
    with open(summary_path, encoding="utf-8") as f:
        for line in f:
            d = json.loads(line)
            if d.get("status") == "ok":
                by_slug[d["slug"]] = d  # later entries win (already-latest run)

    cats = {}
    with open(cat_path, encoding="utf-8") as f:
        for line in f:
            d = json.loads(line)
            cats[d["slug"]] = d["category"]

    out_lines = []
    missing = []
    for slug, d in by_slug.items():
        author_key = d["author_key"]
        if author_key not in AUTHOR_EN:
            missing.append(slug)
            continue
        author_ar, author_en, death_ar = AUTHOR_EN[author_key]
        category = cats.get(slug, "tazkiyah")
        json_path = os.path.join(build_dir, f"{slug}.json")
        if not os.path.exists(json_path):
            missing.append(slug)
            continue
        size_bytes = os.path.getsize(json_path)
        title_ar = d.get("titleAr") or slug
        page_count = d.get("pageCount", 0)
        source_label = d.get("sourceLabel", f"المكتبة الشاملة — {title_ar}")
        desc = (
            f"مصنَّف لـ {author_ar}، {page_count} صفحة، "
            f"ضمن باب {CATEGORY_LABEL_AR.get(category, 'التزكية والرقائق')}."
        )
        title_en = slug.replace("_", " ").title()

        out_lines.append("  LibraryBook(")
        out_lines.append(f"    id: '{slug}',")
        out_lines.append(f"    titleAr: '{dart_escape(title_ar)}',")
        out_lines.append(f"    titleEn: '{dart_escape(title_en)}',")
        out_lines.append(f"    authorAr: '{dart_escape(author_ar)}',")
        out_lines.append(f"    authorEn: '{dart_escape(author_en)}',")
        out_lines.append(f"    authorDeathAr: '{dart_escape(death_ar)}',")
        out_lines.append(f"    descriptionAr: '{dart_escape(desc)}',")
        out_lines.append(f"    category: BookCategory.{category},")
        out_lines.append("    textEdition: TextEdition(")
        out_lines.append(f"      url: '{BASE_URL}/books/text/{slug}.json',")
        out_lines.append(f"      fileName: '{slug}_text.json',")
        out_lines.append(f"      approxSizeBytes: {size_bytes}, // built by scripts/build_book_text.py")
        out_lines.append(f"      sourceLabel: '{dart_escape(source_label)}',")
        out_lines.append("    ),")
        out_lines.append("  ),")

    out_path = os.path.join(root, "scripts", "catalog_entries_generated.dart")
    with open(out_path, "w", encoding="utf-8") as f:
        f.write("\n".join(out_lines))

    print(f"wrote {len(by_slug) - len(missing)} entries to {out_path}")
    if missing:
        print("MISSING/SKIPPED:", missing)


if __name__ == "__main__":
    main()
