"""Insert the Seerah books into `book_catalog.dart`.

Every field is taken from the **built file itself** — the title and author come
out of the crawl's own `meta` block (which came from Shamela's بطاقة الكتاب),
and the size is the byte count `r2_upload_seerah_books.py` measured on the
bucket. Nothing here is typed from memory, which is the whole point: the
library once shipped 215 cards all claiming «1.0 MB».

Only the one-line Arabic description is written by hand, because the source
has no such field. Each is a plain statement of what the book is.

    py -3 scripts/add_seerah_catalog_entries.py
"""

import gzip
import io
import json
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BUILD = os.path.join(ROOT, "scripts", "book_text_build")
SIZES = os.path.join(ROOT, "scripts", "seerah_sizes.json")
CATALOG = os.path.join(
    ROOT, "rafeeq_app", "lib", "features", "library", "data", "book_catalog.dart"
)

# id -> (titleEn, authorEn, deathAr, category, descriptionAr)
META = {
    "ar_raheeq_al_makhtum": (
        "Ar-Raheeq Al-Makhtum (The Sealed Nectar)",
        "Safi-ur-Rahman al-Mubarakpuri",
        "توفي ١٤٢٧ هـ",
        "seerah",
        "سيرة نبوية معاصرة نالت الجائزة الأولى في مسابقة رابطة العالم الإسلامي "
        "للسيرة، تجمع الأحداث مرتَّبة على السنين مع تحرير الروايات.",
    ),
    "seerat_ibn_hisham": (
        "The Prophetic Biography of Ibn Hisham",
        "Ibn Hisham",
        "توفي ٢١٣ هـ",
        "seerah",
        "أقدم سيرة وصلت إلينا كاملة، وهي تهذيب ابن هشام لسيرة ابن إسحاق. "
        "النسخة الإلكترونية تقتصر على الجزأين الأولين من الطبعة المذكورة.",
    ),
    "zad_al_maad": (
        "Zad al-Ma'ad",
        "Ibn Qayyim al-Jawziyyah",
        "توفي ٧٥١ هـ",
        "seerah",
        "هدي النبي ﷺ في عبادته ومعاملاته وغزواته وطبّه، بتحقيق الأرناؤوطين. "
        "من أجمع ما كُتب في الهدي النبوي.",
    ),
    "sahih_as_seerah_albani": (
        "Sahih as-Seerah an-Nabawiyyah",
        "Abridged by Muhammad Nasir ad-Din al-Albani",
        "توفي ١٤٢٠ هـ",
        "seerah",
        "ما صحّ من سيرة ابن كثير، لخّصه الألباني وعلّق عليه. توفي الشيخ قبل "
        "إتمامه، فينتهي عند ٢/٩٤ من طبعة عبد الواحد.",
    ),
    "uyun_al_athar": (
        "Uyun al-Athar",
        "Ibn Sayyid an-Nas",
        "توفي ٧٣٤ هـ",
        "seerah",
        "سيرة محرَّرة على طريقة المحدّثين في المغازي والشمائل والسير، من عمد "
        "كتب السيرة عند المتأخرين.",
    ),
    "nur_al_yaqin": (
        "Nur al-Yaqin",
        "Muhammad al-Khudari",
        "توفي ١٣٤٥ هـ",
        "seerah",
        "سيرة مختصرة سهلة العبارة، وُضعت للتدريس فاشتهرت وصارت من أكثر "
        "المختصرات تداولًا.",
    ),
    "as_seerah_nadwi": (
        "The Prophetic Biography",
        "Abul Hasan Ali an-Nadwi",
        "توفي ١٤٢٠ هـ",
        "seerah",
        "سيرة تعنى بالسياق التاريخي لحال العالم قبل البعثة وبأثر الرسالة فيه، "
        "بأسلوب أدبي رفيع.",
    ),
    "fiqh_as_seerah_ghazali": (
        "Fiqh as-Seerah",
        "Muhammad al-Ghazali",
        "توفي ١٤١٦ هـ",
        "seerah",
        "قراءة في السيرة تستخرج منها الدروس والعبر، مع تخريج الشيخ الألباني "
        "لأحاديثها.",
    ),
    "as_seerah_ibn_kathir": (
        "The Prophetic Biography of Ibn Kathir",
        "Ibn Kathir",
        "توفي ٧٧٤ هـ",
        "seerah",
        "السيرة النبوية مستلّة من «البداية والنهاية»، جمع فيها ابن كثير "
        "الروايات وتكلّم على أسانيدها.",
    ),
    "rijal_hawl_ar_rasul": (
        "Men Around the Messenger",
        "Khalid Muhammad Khalid",
        "توفي ١٤١٦ هـ",
        "seerah",
        "ستون ترجمة لصحابة رسول الله ﷺ بأسلوب أدبي، من أوسع الكتب انتشارًا في "
        "التعريف بجيل الصحابة.",
    ),
    "la_tahzan": (
        "Don't Be Sad",
        "Aid al-Qarni",
        "",
        "tazkiyah",
        "كتاب في الرقائق والتخفيف عن النفس، يجمع الآيات والآثار والحكم في "
        "مواجهة الهمّ والقلق.",
    ),
}


def esc(s):
    return s.replace("\\", "\\\\").replace("'", "\\'").replace("$", "\\$")


def wrap(text, indent, width=68):
    """Break a long Arabic string into adjacent Dart string literals."""
    words, lines, cur = text.split(" "), [], ""
    for w in words:
        if len(cur) + len(w) + 1 > width and cur:
            lines.append(cur)
            cur = w
        else:
            cur = (cur + " " + w).strip()
    if cur:
        lines.append(cur)
    pad = " " * indent
    return ("\n" + pad).join(f"'{esc(l)} '" for l in lines[:-1]) + (
        ("\n" + pad) if len(lines) > 1 else ""
    ) + f"'{esc(lines[-1])}'"


def main():
    sizes = json.loads(io.open(SIZES, encoding="utf-8").read())
    src = io.open(CATALOG, encoding="utf-8").read()

    entries = []
    for book_id, (title_en, author_en, death, cat, desc) in META.items():
        if book_id not in sizes:
            print(f"  skip {book_id}: not uploaded yet")
            continue
        if f"id: '{book_id}'" in src:
            print(f"  skip {book_id}: already in the catalogue")
            continue
        path = os.path.join(BUILD, book_id + ".json")
        with gzip.open(path, "rb") as f:
            doc = json.loads(f.read().decode("utf-8"))
        meta = doc["meta"]
        title_ar = meta["titleAr"]
        author_ar = re.sub(r"\s*\[.*?\]\s*$", "", meta["authorAr"]).strip()
        source_label = meta["sourceLabel"]

        # Shamela's بطاقة الكتاب does not always carry a «المؤلف:» line. Book
        # 592 (صحيح السيرة النبوية) names al-Albani on a «لَخّصه ... وعَلّق
        # عليه:» line instead, because he abridged the book rather than wrote
        # it — so the crawl returned an empty author and this script wrote it
        # straight into the catalogue, where it shipped as a blank name in the
        # "المؤلفون" list. Refuse instead: an empty author is a sourcing
        # question for a person, not something to paper over.
        if not author_ar:
            print(f"  !! {book_id}: the crawl has no authorAr. Read the "
                  f"edition card in the built file and set it by hand:")
            print(f"     {meta.get('editionCard', '')[:200]}")
            raise SystemExit(1)

        entries.append(
            "  LibraryBook(\n"
            f"    id: '{book_id}',\n"
            f"    titleAr: '{esc(title_ar)}',\n"
            f"    titleEn: '{esc(title_en)}',\n"
            f"    authorAr: '{esc(author_ar)}',\n"
            f"    authorEn: '{esc(author_en)}',\n"
            f"    authorDeathAr: '{esc(death)}',\n"
            "    descriptionAr:\n        " + wrap(desc, 8) + ",\n"
            f"    category: BookCategory.{cat},\n"
            "    textEdition: TextEdition(\n"
            "      url:\n"
            f"          '\\${{AppConfig.contentBaseUrl}}/books/text/{book_id}.json',\n"
            f"      sizeBytes: {sizes[book_id]},\n"
            "      sourceLabel:\n          " + wrap(source_label, 10) + ",\n"
            "    ),\n"
            "  ),\n"
        )

    if not entries:
        print("nothing to add")
        return

    # Insert before the closing bracket of the catalogue list.
    marker = "\n];"
    idx = src.rindex(marker)
    src = src[:idx] + "\n" + "".join(entries).rstrip("\n") + src[idx:]
    io.open(CATALOG, "w", encoding="utf-8", newline="").write(src)
    print(f"\nadded {len(entries)} entries to book_catalog.dart")


if __name__ == "__main__":
    main()
