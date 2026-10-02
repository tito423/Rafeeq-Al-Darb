"""Library «المرحلة ٣» (2026-10-03): the best-known books of each shelf, with
their shuruh, and a graded طالب العلم path.

Owner, 2026-10-03: «في كل قسم تحط فيه اشهر وافضل ١٠ كتب بشروحاتهم … ماعدا
الزهد والرقائق … وقسم طالب العلم … افضل واشهر وايسر واسهل الكتب … الوثوقية
والوسطية», then «فكك من شروط المصادر هات الكتب واتصرف بطريقة مش تعرضنا
للحقوق» and «راعي السهولة ولو احتجت تعليقات المحققين استنبط منها مش تاخدها
بالنص».

How that is honoured here:
  * every book is a pre-modern author's text, or a 20th-century author dead
    long enough for his work to be free (al-Jaziri 1360 AH, al-Hashimi 1362,
    al-Zurqani 1367, Ibn Badis 1359);
  * the modern muhaqqiq's words are not taken: the hamesh is dropped at build
    time (build_book_text.py), and his introduction / description of the
    manuscripts / biography of the author is cut here (EDITOR below) - each
    cut is printed in the report for a human to read before --publish;
  * the seven names stay out of the author line (the 2026-09-22 ruling); a
    name on the card only as the muhaqqiq of a book is reported, and the book
    is held when that name also appears in the body text.

    py -3 scripts/library_phase3.py --crawl     # Shamela pages -> scripts/shamela_raw/<id>.jsonl
    py -3 scripts/library_phase3.py --build     # -> scripts/book_text_build/<id>.json + report
    py -3 scripts/library_phase3.py --publish   # R2 upload + read-back + book_catalog.dart
"""
import gzip
import io
import json
import os
import re
import sys
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import library_phase2 as p2  # noqa: E402

ROOT = os.path.dirname(HERE)
BUILD = p2.BUILD
RAW = os.path.join(HERE, "shamela_raw")
REPORT = os.path.join(HERE, "library_phase3_out.txt")

# id -> (shamelaId, titleAr, titleEn, authorAr, authorEn, deathAH, category, shelfOrder)
PLAN = {
    # ── الحديث: the famous collections with the sharh students actually read
    "sharh_al_arbain_ibn_daqiq": (11244, "شرح الأربعين النووية", "Sharh al-Arbain al-Nawawiyyah",
        "الإمام ابن دقيق العيد", "Ibn Daqiq al-Id", 702, "hadith", 0),
    "dalil_al_falihin": (140, "دليل الفالحين لطرق رياض الصالحين", "Dalil al-Falihin (Sharh Riyad al-Salihin)",
        "محمد بن علان الصديقي", "Ibn Allan al-Siddiqi", 1057, "hadith", 0),
    "subul_al_salam": (21590, "سبل السلام شرح بلوغ المرام", "Subul al-Salam",
        "الأمير الصنعاني", "Al-Amir al-San'ani", 1182, "hadith", 0),
    "sharh_al_nawawi_ala_muslim": (1711, "المنهاج شرح صحيح مسلم بن الحجاج", "Al-Minhaj: Sharh Sahih Muslim",
        "الإمام محيي الدين النووي", "Imam al-Nawawi", 676, "hadith", 0),
    "jam_al_wasail": (2569, "جمع الوسائل في شرح الشمائل", "Jam al-Wasail (Sharh al-Shamail)",
        "الملا علي القاري", "Mulla Ali al-Qari", 1014, "hadith", 0),
    "mirqat_al_mafatih": (8176, "مرقاة المفاتيح شرح مشكاة المصابيح", "Mirqat al-Mafatih",
        "الملا علي القاري", "Mulla Ali al-Qari", 1014, "hadith", 0),
    "nayl_al_awtar": (9242, "نيل الأوطار شرح منتقى الأخبار", "Nayl al-Awtar",
        "الإمام الشوكاني", "Al-Shawkani", 1250, "hadith", 0),
    "al_tajrid_al_sarih": (96283, "التجريد الصريح لأحاديث الجامع الصحيح", "Al-Tajrid al-Sarih (Mukhtasar Sahih al-Bukhari)",
        "زين الدين الزبيدي", "Zayn al-Din al-Zabidi", 893, "hadith", 0),
    # ── الفقه: one easy sharh per school that had none, and the comparative primer
    "maraqi_al_falah": (412, "مراقي الفلاح شرح نور الإيضاح", "Maraqi al-Falah (Hanafi)",
        "حسن الشرنبلالي", "Al-Shurunbulali", 1069, "fiqh", 0),
    "bulghat_al_salik": (21607, "بلغة السالك لأقرب المسالك (حاشية الصاوي على الشرح الصغير)", "Bulghat al-Salik (Maliki)",
        "أحمد الصاوي على شرح الدردير", "Al-Sawi on al-Dardir", 1241, "fiqh", 0),
    "al_fiqh_ala_al_madhahib_al_arbaa": (9849, "الفقه على المذاهب الأربعة", "Al-Fiqh ala al-Madhahib al-Arba'a",
        "عبد الرحمن الجزيري", "Abd al-Rahman al-Jaziri", 1360, "fiqh", 0),
    # ── العقيدة: Ahl al-Sunnah's own classics, Ash'ari and athari alike
    "al_ibanah_ashari": (8178, "الإبانة عن أصول الديانة", "Al-Ibanah an Usul al-Diyanah",
        "الإمام أبو الحسن الأشعري", "Abu al-Hasan al-Ash'ari", 324, "aqidah", 0),
    "al_asma_wal_sifat_bayhaqi": (9270, "الأسماء والصفات", "Al-Asma wa al-Sifat",
        "الإمام البيهقي", "Al-Bayhaqi", 458, "aqidah", 0),
    "lawami_al_anwar": (8353, "لوامع الأنوار البهية شرح الدرة المضية", "Lawami al-Anwar al-Bahiyyah",
        "الإمام السفاريني", "Al-Saffarini", 1188, "aqidah", 0),
    "al_shariah_ajurri": (13035, "الشريعة", "Al-Shari'ah",
        "الإمام أبو بكر الآجري", "Al-Ajurri", 360, "aqidah", 0),
    "al_aqaid_al_islamiyyah_ibn_badis": (9092, "العقائد الإسلامية من الآيات القرآنية والأحاديث النبوية", "Al-Aqaid al-Islamiyyah",
        "عبد الحميد بن باديس", "Abd al-Hamid ibn Badis", 1359, "aqidah", 0),
    # ── التفسير: from the shortest (al-Jalalayn) to the fullest
    "tafsir_ibn_kathir": (8473, "تفسير القرآن العظيم", "Tafsir Ibn Kathir",
        "الحافظ ابن كثير", "Ibn Kathir", 774, "tafsir", 0),
    "tafsir_al_jalalayn": (12876, "تفسير الجلالين", "Tafsir al-Jalalayn",
        "جلال الدين المحلي وجلال الدين السيوطي", "Al-Mahalli and al-Suyuti", 911, "tafsir", 0),
    "tafsir_al_baghawi": (41, "معالم التنزيل (تفسير البغوي)", "Tafsir al-Baghawi",
        "الإمام البغوي", "Al-Baghawi", 510, "tafsir", 0),
    "tafsir_al_nasafi": (1394, "مدارك التنزيل وحقائق التأويل (تفسير النسفي)", "Tafsir al-Nasafi",
        "الإمام النسفي", "Al-Nasafi", 710, "tafsir", 0),
    "zad_al_masir": (23619, "زاد المسير في علم التفسير", "Zad al-Masir",
        "الإمام أبو الفرج ابن الجوزي", "Ibn al-Jawzi", 597, "tafsir", 0),
    "asbab_al_nuzul_wahidi": (11456, "أسباب نزول القرآن", "Asbab Nuzul al-Quran",
        "الإمام الواحدي", "Al-Wahidi", 468, "tafsir", 0),
    "fath_al_qadir_shawkani": (23623, "فتح القدير", "Fath al-Qadir",
        "الإمام الشوكاني", "Al-Shawkani", 1250, "tafsir", 0),
    "al_tashil_ibn_juzayy": (30186, "التسهيل لعلوم التنزيل", "Al-Tashil li-Ulum al-Tanzil",
        "ابن جزي الكلبي", "Ibn Juzayy al-Kalbi", 741, "tafsir", 0),
    # ── السيرة
    "al_shifa_qadi_iyad": (23645, "الشفا بتعريف حقوق المصطفى", "Al-Shifa",
        "القاضي عياض", "Qadi Iyad", 544, "seerah", 0),
    "jawami_al_seerah": (1036, "جوامع السيرة", "Jawami al-Seerah",
        "الإمام ابن حزم الأندلسي", "Ibn Hazm", 456, "seerah", 0),
    "al_rawd_al_unuf": (1514, "الروض الأنف في شرح السيرة النبوية لابن هشام", "Al-Rawd al-Unuf",
        "الإمام السهيلي", "Al-Suhayli", 581, "seerah", 0),
    "khulasat_siyar_sayyid_al_bashar": (6583, "خلاصة سير سيد البشر", "Khulasat Siyar Sayyid al-Bashar",
        "المحب الطبري", "Al-Muhibb al-Tabari", 694, "seerah", 0),
    "al_mawahib_al_ladunniyyah": (23685, "المواهب اللدنية بالمنح المحمدية", "Al-Mawahib al-Ladunniyyah",
        "الإمام القسطلاني", "Al-Qastallani", 923, "seerah", 0),
    # ── التاريخ
    "tarikh_al_tabari": (9783, "تاريخ الرسل والملوك (تاريخ الطبري)", "Tarikh al-Tabari",
        "الإمام ابن جرير الطبري", "Ibn Jarir al-Tabari", 310, "tarikh", 0),
    "al_kamil_fil_tarikh": (21712, "الكامل في التاريخ", "Al-Kamil fi al-Tarikh",
        "عز الدين ابن الأثير", "Ibn al-Athir", 630, "tarikh", 0),
    "tarikh_ibn_khaldun": (12320, "ديوان المبتدأ والخبر (تاريخ ابن خلدون ومقدمته)", "Tarikh Ibn Khaldun (with the Muqaddimah)",
        "عبد الرحمن ابن خلدون", "Ibn Khaldun", 808, "tarikh", 0),
    "al_ibar_dhahabi": (25841, "العبر في خبر من غبر", "Al-Ibar fi Khabar man Ghabar",
        "الإمام شمس الدين الذهبي", "Al-Dhahabi", 748, "tarikh", 0),
    "wafayat_al_ayan": (1000, "وفيات الأعيان وأنباء أبناء الزمان", "Wafayat al-A'yan",
        "ابن خلكان", "Ibn Khallikan", 681, "tarikh", 0),
    # ── الآداب
    "ghidha_al_albab": (25791, "غذاء الألباب في شرح منظومة الآداب", "Ghidha al-Albab",
        "الإمام السفاريني", "Al-Saffarini", 1188, "adab", 0),
    "adab_al_ishrah_ghazzi": (8186, "آداب العشرة وذكر الصحبة والأخوة", "Adab al-Ishrah",
        "بدر الدين الغزي", "Badr al-Din al-Ghazzi", 984, "adab", 0),
    "al_mustatraf": (23802, "المستطرف في كل فن مستظرف", "Al-Mustatraf",
        "شهاب الدين الأبشيهي", "Al-Ibshihi", 850, "adab", 0),
    "uyun_al_akhbar": (23790, "عيون الأخبار", "Uyun al-Akhbar",
        "ابن قتيبة الدينوري", "Ibn Qutaybah", 276, "adab", 0),
    # ── طالب العلم: 1 آداب الطلب، 2 المتون الأولى بشروحها، 3 التوسّع، 4 المقاصد
    "iqtida_al_ilm_al_amal": (12985, "اقتضاء العلم العمل", "Iqtida al-Ilm al-Amal",
        "الخطيب البغدادي", "Al-Khatib al-Baghdadi", 463, "talibIlm", 1),
    "sharh_qatr_al_nada": (6970, "شرح قطر الندى وبل الصدى", "Sharh Qatr al-Nada",
        "ابن هشام الأنصاري", "Ibn Hisham al-Ansari", 761, "talibIlm", 2),
    "jawahir_al_balaghah": (9256, "جواهر البلاغة في المعاني والبيان والبديع", "Jawahir al-Balaghah",
        "أحمد الهاشمي", "Ahmad al-Hashimi", 1362, "talibIlm", 2),
    "sharh_ibn_aqil": (9904, "شرح ابن عقيل على ألفية ابن مالك", "Sharh Ibn Aqil",
        "ابن عقيل", "Ibn Aqil", 769, "talibIlm", 3),
    "sharh_shudhur_al_dhahab": (6969, "شرح شذور الذهب في معرفة كلام العرب", "Sharh Shudhur al-Dhahab",
        "ابن هشام الأنصاري", "Ibn Hisham al-Ansari", 761, "talibIlm", 3),
    "tadrib_al_rawi": (9329, "تدريب الراوي في شرح تقريب النواوي", "Tadrib al-Rawi",
        "الحافظ جلال الدين السيوطي", "Al-Suyuti", 911, "talibIlm", 3),
    "al_ashbah_wal_nazair_suyuti": (21719, "الأشباه والنظائر", "Al-Ashbah wa al-Nazair",
        "الحافظ جلال الدين السيوطي", "Al-Suyuti", 911, "talibIlm", 3),
    "manahil_al_irfan": (7249, "مناهل العرفان في علوم القرآن", "Manahil al-Irfan",
        "محمد عبد العظيم الزرقاني", "Al-Zurqani", 1367, "talibIlm", 3),
}

# A section the modern editor wrote, not the author: his introduction, his
# description of the manuscripts and of his method, his biography of the
# author, the publisher's word. Matched on the فهرس title Shamela serves.
EDITOR = re.compile(
    r"مقدم[ةه]\s*(ال)?(محقق|تحقيق|الناشر|المعتني|الطبع[ةه]|المراجع|المصحح|الدراس[ةه])"
    r"|كلم[ةه]\s*(الناشر|المحقق)|تقديم\s*(الطبع[ةه]|الناشر|المحقق)"
    r"|ترجم[ةه]\s*(ال)?(مؤلف|مصنف|المؤلف|المصنف|الشارح|الناظم)"
    r"|وصف\s*(ال)?(نسخ|مخطوط)|النسخ\s*الخطي[ةه]|نماذج\s*(من\s*)?(ال)?مخطوط|صور\s*(ال)?(مخطوط|نسخ)"
    r"|منهج\s*(ال)?(تحقيق|عمل|المحقق)|عمل(ي|نا)\s*في\s*(ال)?(تحقيق|كتاب)|خط[ةه]\s*(ال)?تحقيق"
    r"|دراس[ةه]\s*(ال)?كتاب|التعريف\s*ب(ال)?(كتاب|مؤلف|مصنف)|توثيق\s*نسب[ةه]\s*(ال)?كتاب"
    r"|^تقريظ|^الدراس[ةه]$|^قسم\s*الدراس[ةه]")


def last_page(sid):
    """Shamela's pageIds run 1..N; N is found by doubling then halving."""
    import fetch_shamela_pages as f
    ok = lambda p: f.fetch(sid, p, tries=3) is not None
    lo, hi = 1, 64
    while ok(hi):
        lo, hi = hi, hi * 2
    while hi - lo > 1:
        mid = (lo + hi) // 2
        lo, hi = (mid, hi) if ok(mid) else (lo, mid)
    return lo


def crawl(ids):
    import fetch_shamela_pages as f
    os.makedirs(RAW, exist_ok=True)
    for bid in ids:
        sid = PLAN[bid][0]
        n = last_page(sid)
        print(f"== {bid} (shamela {sid}): {n} pages", flush=True)
        f.run(sid, n, os.path.join(RAW, bid + ".jsonl"))


def cut_editor(book):
    """Empty the pages of every EDITOR section; tidy() then drops them and
    re-points the TOC. Returns [(title, pages, first line)]."""
    toc = book.get("toc") or []
    pages = book["pages"]
    starts = sorted({e["pageIndex"] for e in toc} | {len(pages)})
    cuts = []
    for e in toc:
        if not EDITOR.search(e["title"]):
            continue
        a = e["pageIndex"]
        b = next(s for s in starts if s > a)
        first = next((p["t"] for pg in pages[a:b] for p in pg["paras"] if p["t"].strip()), "")
        if any(pg["paras"] for pg in pages[a:b]):
            cuts.append((e["title"], b - a, first[:120]))
        for pg in pages[a:b]:
            pg["paras"] = []
    # the cut sections leave the فهرس too, or they would point at the
    # author's first page under the editor's heading
    book["toc"] = [e for e in toc if not EDITOR.search(e["title"])]
    book["meta"]["sectionCount"] = len(book["toc"])
    return cuts


def build(ids):
    import build_book_text as bbt
    out = io.open(REPORT, "w", encoding="utf-8")
    for bid in ids:
        sid = PLAN[bid][0]
        try:
            doc = bbt.build_book(bid, sid, "المكتبة الشاملة")
        except Exception as e:  # noqa: BLE001 - one bad book does not stop the batch
            out.write(f"\n== {bid}: BUILD FAILED {e}\n")
            continue
        cuts = cut_editor(doc)
        if cuts:
            doc["meta"]["editorIntroRemoved"] = [c[0] for c in cuts]
        p2.tidy(doc)
        path = os.path.join(BUILD, bid + ".json")
        bbt.write_book_json(doc, path)
        card = doc["meta"].get("editionCard", "")
        body = " ".join(p["t"] for pg in doc["pages"] for p in pg["paras"])
        names = {n: body.count(n) for n in p2.SEVEN if body.count(n)}
        out.write(f"\n== {bid}  shamela {sid}  {os.path.getsize(path)} B  "
                  f"{len(doc['pages'])} pages  {len(doc['toc'])} sections\n{card}\n"
                  f"  names on card: {[n for n in p2.CARD_NAMES if n in card] or 'none'}\n"
                  f"  names in text: {names or 'none'}\n"
                  f"  editor sections cut: {len(cuts)}\n")
        for t, n, first in cuts:
            out.write(f"    - «{t}» {n} p: {first}\n")
        out.write("  first sections: " + " | ".join(e["title"] for e in doc["toc"][:8]) + "\n")
        first = next((p["t"] for pg in doc["pages"] for p in pg["paras"] if p["t"].strip()), "")
        out.write(f"  opens on: {first[:200]}\n")
        out.flush()
    out.close()
    print(io.open(REPORT, encoding="utf-8").read())


# Held after reading the --build report (book id -> why).
HOLD = {}


def publish(ids):
    """As library_phase2.main(): upload, read back, then write the entries."""
    s3 = None
    entries = []
    cat_src = io.open(p2.CATALOG, encoding="utf-8").read()
    for bid in ids:
        if f"id: '{bid}'" in cat_src or bid in HOLD:
            print("skip", bid, HOLD.get(bid, "already catalogued"))
            continue
        path = os.path.join(BUILD, bid + ".json")
        if not os.path.exists(path):
            print("skip", bid, "not built")
            continue
        raw, book = p2.load(bid)
        card = book["meta"].get("editionCard", "")
        author_line = p2.card_field(card, "المؤلف")
        if any(n in author_line for n in p2.CARD_NAMES):
            print("REFUSED", bid, "author is one of the seven")
            continue
        _, t_ar, t_en, a_ar, a_en, death, cat, shelf = PLAN[bid]
        label = "المكتبة الشاملة — " + "، ".join(x for x in (
            p2.card_field(card, "الكتاب"), p2.card_field(card, "المؤلف"),
            p2.card_field(card, "الناشر"), p2.card_field(card, "الطبعة")) if x)
        if s3 is None:
            from r2_common import BUCKET, r2_client
            s3 = r2_client()
        s3.put_object(Bucket=BUCKET, Key=f"books/text/{bid}.json", Body=raw,
                      ContentType="application/json")
        if not p2.public_ok(bid, len(raw)):
            sys.exit(f"{bid}: public endpoint did not return the uploaded bytes")
        print("uploaded + verified", bid, len(raw), flush=True)
        entries.append((bid, t_ar, t_en, a_ar, a_en, death, cat, shelf, len(raw), label,
                        len(book["pages"])))
    src = io.open(p2.CATALOG, encoding="utf-8").read()
    header = "  // ── 2026-10-03 — library «المرحلة ٣»: the best-known books of each shelf"
    lines = [""] if header in src else ["", header,
                                      "  // with their shuruh. scripts/library_phase3.py."]
    for (bid, t_ar, t_en, a_ar, a_en, death, cat, shelf, size, label, npages) in entries:
        lines += [
            "  LibraryBook(",
            f"    id: {p2.dart_str(bid)},",
            f"    titleAr: {p2.dart_str(t_ar)},",
            f"    titleEn: {p2.dart_str(t_en)},",
            f"    authorAr: {p2.dart_str(a_ar)},",
            f"    authorEn: {p2.dart_str(a_en)},",
            f"    deathYearAh: {death},",
            f"    pages: {npages},",
            f"    category: BookCategory.{cat},",
        ]
        if shelf:
            lines.append(f"    shelfOrder: {shelf},")
        lines += [
            "    textEdition: TextEdition(",
            "      url:",
            f"          '${{AppConfig.contentBaseUrl}}/books/text/{bid}.json',",
            f"      sizeBytes: {size},",
            "      editorNotesRemoved: true,",
            f"      sourceLabel: {p2.dart_str(label)},",
            "    ),",
            "  ),",
        ]
    if entries:
        end = src.index("\n];\n", src.index("libraryBookCatalog"))
        src = src[:end].rstrip() + "\n" + "\n".join(lines) + "\n" + src[end:]
        io.open(p2.CATALOG, "w", encoding="utf-8", newline="\n").write(src)
    print(f"catalogue: +{len(entries)} books")


def main():
    args = sys.argv[1:]
    ids = [a for a in args if not a.startswith("--")] or list(PLAN)
    unknown = [i for i in ids if i not in PLAN]
    if unknown:
        sys.exit(f"unknown: {unknown}")
    if "--crawl" in args:
        crawl(ids)
    if "--build" in args:
        build(ids)
    if "--publish" in args:
        publish(ids)


if __name__ == "__main__":
    main()
