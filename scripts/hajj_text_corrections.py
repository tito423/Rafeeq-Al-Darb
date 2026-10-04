"""Typing errors in Shamela's copy of «الفقه المنهجي» (Hajj chapter), fixed on
the owner's request (2026-10-05: «في قسم العمرة صلح وإنما أهلك كمان قبلكم …
ودور على أي أخطاء إملائية تاني»).

How the list was made: every word of the chapter (diacritics stripped) that
occurs fewer than 3 times in hadith.db + all other bundled books was listed
(340 words) and read in context by hand. Only plain TYPING slips are here -
a letter swapped, dropped or doubled, which no Arabic reading supports. The
book's wording and its fiqh are untouched; doubtful cases are NOT here and
are listed at the bottom.

Quoted hadith / Qur'an (CLAUDE.md §1.2): the only entries that touch quoted
text are typing slips with a cited reference:
  - «من كمان قبلكم» -> «من كان قبلكم»: Muslim 1337 (Abu Hurayra) reads
    «فإنما هلك من كان قبلكم»; «كمان» is not an Arabic word here.
  - «اللهم أشهد» -> «اللهم اشهد»: Muslim 1218 (Jabir, the Farewell Hajj),
    imperative of شهد - hamzat wasl.
  - «ربنا أتنا» -> «ربنا آتنا»: al-Baqarah 2:201 in the Madinah mushaf
    «رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً».
  - «أصابعة» -> «أصابعه»: Muslim 1218 «فشبك رسول الله أصابعه».

Applied by build_hajj_guide_book.py on every rebuild, and to the shipped
asset in place by running this file (`py -3 scripts/hajj_text_corrections.py`).

Left as printed (doubtful, reported to the owner): «متحرشا» (Muslim has
«محرشا» - one letter, but a real word), «شعآئر» (an old orthography of the
Qur'an word, not a slip), «عبدالله/عبدالمطلب/وأبوداود» (joined spelling).
"""
import gzip
import io
import json
import os
import sys

# (wrong, right) - each must occur at least once; every occurrence is fixed.
CORRECTIONS = [
    ("من كمان قبلكم", "من كان قبلكم"),
    ("ويخطبم", "ويخطبهم"),
    ("أن يلتفظ بلسانه", "أن يتلفظ بلسانه"),
    ("لبيك الهم لبيك", "لبيك اللهم لبيك"),
    ("لبيك الهم بعمرة", "لبيك اللهم بعمرة"),
    ("طواف الواداع", "طواف الوداع"),
    ("وأمكانها معروفة", "وأماكنها معروفة"),
    ("أصابعة", "أصابعه"),
    ("إذا استوي على", "إذا استوى على"),
    ("أم تخبيراً", "أم تخييراً"),
    ("ومعني التقدير", "ومعنى التقدير"),
    ("والأعمال لتي", "والأعمال التي"),
    ("من أحدى حالتين", "من إحدى حالتين"),
    ("جمره العقبة", "جمرة العقبة"),
    ("صور المصطفي هو", "صور المصطفى وهو"),
    ("نبياً وسولاً", "نبياً ورسولاً"),
    ("إلا يفعل المتروك", "إلا بفعل المتروك"),
    ("فيبقي الحج", "فيبقى الحج"),
    ("من جمله دعائه", "من جملة دعائه"),
    ("بين حين وأخر", "بين حين وآخر"),
    ("اللهم أشهد", "اللهم اشهد"),
    ("ربنا أتنا", "ربنا آتنا"),
    ("ويدعوا أثناء", "ويدعو أثناء"),
    ("ويدعوا الله بخشوع", "ويدعو الله بخشوع"),
    ("على الفور، بل، بل يصح", "على الفور، بل يصح"),
]

ASSET = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                     "rafeeq_app", "assets", "data", "builtin_books",
                     "al_fiqh_al_manhaji_hajj.json")


def fix_text(t, hits=None):
    for wrong, right in CORRECTIONS:
        if wrong in t:
            if hits is not None:
                hits[wrong] = hits.get(wrong, 0) + t.count(wrong)
            t = t.replace(wrong, right)
    return t


def fix_pages(pages, hits=None):
    for pg in pages:
        for para in pg["paras"]:
            if isinstance(para, dict) and isinstance(para.get("t"), str):
                para["t"] = fix_text(para["t"], hits)
    return pages


def main():
    raw = open(ASSET, "rb").read()
    doc = json.loads(gzip.decompress(raw).decode("utf-8"))
    hits = {}
    fix_pages(doc["pages"], hits)
    missing = [w for w, _ in CORRECTIONS if w not in hits]
    body = json.dumps(doc, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    open(ASSET, "wb").write(gzip.compress(body, mtime=0))
    out = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
    out.write(f"fixed {sum(hits.values())} occurrences of {len(hits)} entries\n")
    if missing:
        out.write("NOT FOUND (already fixed or wrong entry): " + " | ".join(missing) + "\n")
    out.flush()


if __name__ == "__main__":
    main()
