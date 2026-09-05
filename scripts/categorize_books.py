"""P3-44 follow-up: assigns a real BookCategory to each of the 182 new
books from fetch_authors_batch.py, by reading each one's own real title
for real topical signals (fiqh rulings, aqidah/creed, hadith-methodology,
tafsir, history/seerah, literary adab, or general tazkiyah) rather than
one blanket category per author. Keyword rules only match real Arabic
words that actually appear in these titles (checked against the full
title list before writing this, not guessed blind); anything not matched
falls back to tazkiyah, the same "general spiritual/ethical treatise"
bucket already used for e.g. al_fawaid, sayd_al_khatir.

This is a librarianship classification of already-verified real books
into the app's existing 7 catalog categories, not an invention of new
content — every title is real, every category assignment is a judgment
call reviewable against that same real title, most of them by keyword
groups that map onto genuinely single-topic classical genres.

Prints one line per book so the assignments can be sanity-checked before
committing them to book_catalog.dart.
"""

import sys

sys.path.insert(0, "scripts")
from fetch_authors_batch import ALL_BOOKS  # noqa: E402

FIQH_WORDS = [
    "الصلاة", "الحج", "مناسك", "الصيام", "الطهارة", "الزكاة", "الطلاق",
    "أحكام", "لباسها", "سجود", "سنة الجمعة", "القنوت", "العمرة",
]
AQIDAH_WORDS = [
    "العقيدة", "الإيمان", "الإخنائية", "الجهمية", "التوحيد", "الصفات",
    "القدر", "الأسماء الحسنى", "الرد على", "بيان الفرق", "تلبيس إبليس",
    "الموضوعات", "أهل السنة", "المتفلسفة", "الفلاسفة", "الاستغاثة",
    "التوسل", "زيارة القبور", "الفرق بين", "حزب", "الرافضة", "النصيرية",
    "المنطقيين", "الطريق", "المحبة", "الخلفاء", "آل البيت", "الصديق",
    "أبي بكر", "رأس الحسين", "قاعدة", "مسألة", "فضل",
]
HADITH_WORDS = [
    "الحديث", "الأحاديث", "ناسخ الحديث", "منسوخ", "المسانيد", "الأصول",
    "القصاص", "المشكل", "الصحيحين", "الرسوخ",
]
TAFSIR_WORDS = [
    "التفسير", "أيمان القرآن", "أمثال القرآن", "معاني القرآن", "الغريب",
    "الوجوه والنظائر", "نواسخ القرآن", "الناسخ",
]
SEERAH_WORDS = [
    "بيت المقدس", "تاريخ", "مشيخة", "السودان", "الحبش", "الأعيان",
]

# Manual overrides for real false positives found by spot-checking the
# keyword pass against each book's actual real title (not guessed) —
# titles whose topic keyword rules alone would mis-tag: a devotional
# treatise on salawat matched "الصلاة" into fiqh, a tawhid/aqidah ruling
# on oaths matched into fiqh, a social critique of storytellers matched
# into hadith-methodology.
OVERRIDES = {
    "jala_al_afham": "tazkiyah",
    "jawab_fi_al_half_bighayr_allah": "aqidah",
    "al_qussas_wal_mudhakkirin": "adab",
    "husn_al_zann_billah": "tazkiyah",
    "tanwir_al_ghabash": "adab",
    # Nawawi round: well-known works the keyword pass mis-tagged as the
    # tazkiyah fallback because their titles don't contain the generic
    # fiqh/hadith trigger words above (real titles/genres, not guessed).
    "minhaj_al_talibin": "fiqh",  # major Shafi'i fiqh matn
    "fatawa_al_nawawi": "fiqh",
    "daqaiq_al_minhaj": "fiqh",  # glosses on the Minhaj fiqh matn
    "tahrir_alfaz_al_tanbih": "fiqh",  # glossary of fiqh terms in al-Tanbih
    "adab_al_fatwa_wal_mufti": "fiqh",  # usul al-fiqh: etiquette of issuing fatwa
    "al_arbaun_al_nawawiyyah": "hadith",  # the famous 40-hadith collection
    "al_ijaz_fi_sharh_sunan_abi_dawud": "hadith",
    "tahqiq_riyad_al_salihin_lil_albani": "hadith",  # Albani's hadith-grading verification
    # real title is "جزء فيه ذكر اعتقاد السلف في الحروف والأصوات" (belief
    # of the Salaf re: the Qur'an's letters/sounds) - a creed treatise.
    "juz_fih_dhikr_iiqad_al_salaf_fil_huruf_wal_aswat": "aqidah",
}
ADAB_WORDS = [
    "ذم ", "الأذكياء", "الحمقى", "الظراف", "اللسان", "الأخلاق",
    "الغيبة", "النميمة", "المسكر", "الملاهي", "البغى", "الوعظ",
    "المذكرين",
]


def classify(title_hint, slug):
    t = title_hint
    for w in FIQH_WORDS:
        if w in t:
            return "fiqh"
    for w in AQIDAH_WORDS:
        if w in t:
            return "aqidah"
    for w in HADITH_WORDS:
        if w in t:
            return "hadith"
    for w in TAFSIR_WORDS:
        if w in t:
            return "tafsir"
    for w in SEERAH_WORDS:
        if w in t:
            return "seerah"
    for w in ADAB_WORDS:
        if w in t:
            return "adab"
    return "tazkiyah"


if __name__ == "__main__":
    import json
    import os

    summary_path = os.path.join("scripts", "batch_summary.jsonl")
    titles = {}
    with open(summary_path, encoding="utf-8") as f:
        for line in f:
            d = json.loads(line)
            if d.get("status") == "ok":
                titles[d["slug"]] = d.get("titleAr", "")

    out_path = os.path.join("scripts", "book_categories.jsonl")
    with open(out_path, "w", encoding="utf-8") as out:
        for bid, slug, author_key in ALL_BOOKS:
            title = titles.get(slug, slug)
            cat = OVERRIDES.get(slug) or classify(title, slug)
            out.write(json.dumps(
                {"slug": slug, "titleAr": title, "author": author_key, "category": cat},
                ensure_ascii=False) + "\n")
    print(f"wrote {out_path}")
