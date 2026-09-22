"""Library «المرحلة ١» (2026-09-22): nineteen explained books into the app.

The owner's rulings for this batch (see the memory note and
CONTENT-LICENSES.md): no bare mutun — the explained book instead; Shamela text
may be taken as served; every existing imam's book stays; and the seven names
he took out on 2026-09-17 stay out (ابن باز، ابن عثيمين، ابن تيمية، ابن جبرين،
ابن عبد الوهاب، الألباني، القرني).

For every book, in this order, stopping on the first failure:
  1. its printed card (kept by build_book_text.py) is read, and the book is
     REFUSED if one of the seven names appears on it — an editor, a حاشية, a
     تعليق printed with the book is exactly how a name comes back in;
  2. the built file is uploaded (gzip, no Content-Encoding — trap #6);
  3. the public URL is read back with a User-Agent (trap #19) and must answer
     with gzip's magic bytes at the uploaded size (§1.1);
  4. its entry is written into book_catalog.dart.

Titles, English names, death years and shelves are this table's; the edition
wording in each sourceLabel is the card's own.

    py -3 scripts/library_phase1.py [--report]
"""
import gzip
import io
import json
import os
import re
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from r2_common import BUCKET, r2_client  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BUILD = os.path.join(ROOT, "scripts", "book_text_build")
CATALOG = os.path.join(ROOT, "rafeeq_app", "lib", "features", "library", "data",
                       "book_catalog.dart")
PUBLIC = "https://pub-39dbef68a1a845d5ba669b43a59516b9.r2.dev"
UA = "RafeeqAlDarb/3.56 (https://github.com/tito423/Rafeeq-Al-Darb) curl/8"
REPORT = os.path.join(ROOT, "scripts", "library_phase1_out.txt")

SEVEN = ["ابن باز", "بن باز", "عثيمين", "ابن تيمية", "بن تيمية", "جبرين",
         "عبد الوهاب", "عبدالوهاب", "الألباني", "الالباني", "القرني"]

# id -> (titleAr, titleEn, authorAr, authorEn, deathAH, category, shelfOrder)
PLAN = {
    "sharh_al_aqidah_al_tahawiyyah": ("شرح العقيدة الطحاوية", "Sharh al-Aqidah al-Tahawiyyah",
        "ابن أبي العز الحنفي", "Ibn Abi al-Izz al-Hanafi", 792, "aqidah", 0),
    "al_iqtisad_fil_itiqad": ("الاقتصاد في الاعتقاد", "Al-Iqtisad fi al-Itiqad",
        "الإمام أبو حامد الغزالي", "Imam Abu Hamid al-Ghazali", 505, "aqidah", 0),
    "qawaid_al_aqaid": ("قواعد العقائد", "Qawaid al-Aqaid",
        "الإمام أبو حامد الغزالي", "Imam Abu Hamid al-Ghazali", 505, "aqidah", 0),
    "tawdih_al_maqasid_sharh_al_nuniyyah": ("توضيح المقاصد شرح نونية ابن القيم", "Tawdih al-Maqasid",
        "أحمد بن إبراهيم بن عيسى", "Ahmad ibn Ibrahim ibn Isa", 1327, "aqidah", 0),
    "al_lubab_fi_sharh_al_kitab": ("اللباب في شرح الكتاب", "Al-Lubab fi Sharh al-Kitab",
        "عبد الغني الغنيمي الميداني", "Abd al-Ghani al-Maydani", 1298, "fiqh", 0),
    "al_ikhtiyar_li_talil_al_mukhtar": ("الاختيار لتعليل المختار", "Al-Ikhtiyar li Talil al-Mukhtar",
        "عبد الله بن محمود الموصلي", "Abdullah ibn Mahmud al-Mawsili", 683, "fiqh", 0),
    "al_thamar_al_dani": ("الثمر الداني شرح رسالة ابن أبي زيد القيرواني", "Al-Thamar al-Dani",
        "صالح عبد السميع الآبي الأزهري", "Salih Abd al-Sami al-Abi al-Azhari", 1335, "fiqh", 0),
    "al_fawakih_al_dawani": ("الفواكه الدواني على رسالة ابن أبي زيد القيرواني", "Al-Fawakih al-Dawani",
        "أحمد بن غانم النفراوي", "Ahmad ibn Ghanim al-Nafrawi", 1126, "fiqh", 0),
    "kifayat_al_akhyar": ("كفاية الأخيار في حل غاية الاختصار", "Kifayat al-Akhyar",
        "تقي الدين الحصني", "Taqi al-Din al-Hisni", 829, "fiqh", 0),
    "al_iqna_fi_hall_alfaz_abi_shuja": ("الإقناع في حل ألفاظ أبي شجاع", "Al-Iqna fi Hall Alfaz Abi Shuja",
        "الخطيب الشربيني", "Al-Khatib al-Shirbini", 977, "fiqh", 0),
    "fath_al_qarib_al_mujib": ("فتح القريب المجيب في شرح ألفاظ التقريب", "Fath al-Qarib al-Mujib",
        "ابن قاسم الغزي", "Ibn Qasim al-Ghazzi", 918, "fiqh", 0),
    "al_uddah_sharh_al_umdah": ("العدة شرح العمدة", "Al-Uddah Sharh al-Umdah",
        "بهاء الدين المقدسي", "Baha al-Din al-Maqdisi", 624, "fiqh", 0),
    "al_rawd_al_murbi": ("الروض المربع شرح زاد المستقنع", "Al-Rawd al-Murbi",
        "منصور بن يونس البهوتي", "Mansur ibn Yunus al-Buhuti", 1051, "fiqh", 0),
    "bidayat_al_mujtahid": ("بداية المجتهد ونهاية المقتصد", "Bidayat al-Mujtahid",
        "ابن رشد الحفيد", "Ibn Rushd", 595, "fiqh", 0),
    "ihkam_al_ahkam": ("إحكام الأحكام شرح عمدة الأحكام", "Ihkam al-Ahkam",
        "ابن دقيق العيد", "Ibn Daqiq al-Id", 702, "hadith", 0),
    "tanwir_al_hawalik": ("تنوير الحوالك شرح موطأ مالك", "Tanwir al-Hawalik",
        "الحافظ جلال الدين السيوطي", "Jalal al-Din al-Suyuti", 911, "hadith", 0),
    "al_rahiq_al_makhtum": ("الرحيق المختوم", "Al-Raheeq al-Makhtum",
        "صفي الرحمن المباركفوري", "Safi al-Rahman al-Mubarakpuri", 1427, "seerah", 0),
    # The two shuruh that replace the bare mutun on the «طالب العلم» shelf,
    # in the place those mutun held (shelfOrder 2).
    "sharh_al_waraqat_al_mahalli": ("شرح الورقات في أصول الفقه", "Sharh al-Waraqat",
        "جلال الدين المحلي", "Jalal al-Din al-Mahalli", 864, "talibIlm", 2),
    "sharh_al_ajurrumiyyah_hifzi": ("شرح الآجرومية", "Sharh al-Ajurrumiyyah",
        "حسن بن محمد الحفظي", "Hasan ibn Muhammad al-Hifzi", 0, "talibIlm", 2),
}

# The bare mutun leaving the shelf, replaced by the two shuruh above.
RETIRED = ["al_waraqat", "al_ajurrumiyyah"]


def card_field(card, name):
    m = re.search(rf"^{name}:\s*(.+)$", card, re.M)
    return m.group(1).strip() if m else ""


def load(book_id):
    raw = open(os.path.join(BUILD, book_id + ".json"), "rb").read()
    return raw, json.loads(gzip.decompress(raw) if raw[:2] == b"\x1f\x8b" else raw)


def public_ok(book_id, size):
    url = f"{PUBLIC}/books/text/{book_id}.json"
    head = subprocess.run(["curl", "-sSI", "-A", UA, url], capture_output=True, text=True).stdout
    first = subprocess.run(["curl", "-sS", "-A", UA, "-r", "0-1", url], capture_output=True).stdout
    length = re.search(r"Content-Length:\s*(\d+)", head, re.I)
    enc = re.search(r"Content-Encoding", head, re.I)
    return (first[:2] == b"\x1f\x8b" and length and int(length.group(1)) == size and not enc)


def dart_str(s):
    return "'" + s.replace("\\", "\\\\").replace("'", "\\'").replace("$", "\\$") + "'"


def main():
    report = "--report" in sys.argv
    out = io.open(REPORT, "w", encoding="utf-8")
    entries, refused = [], []
    for book_id, (t_ar, t_en, a_ar, a_en, death, cat, shelf) in PLAN.items():
        path = os.path.join(BUILD, book_id + ".json")
        if not os.path.exists(path):
            refused.append((book_id, "not built"))
            continue
        raw, book = load(book_id)
        meta = book["meta"]
        card = meta.get("editionCard", "")
        hit = [n for n in SEVEN if n in card]
        body = " ".join(p["t"] if isinstance(p, dict) else p
                        for pg in book["pages"] for p in pg["paras"])
        mentions = {n: body.count(n) for n in SEVEN if body.count(n)}
        out.write(f"\n== {book_id}  ({len(raw)} B, {meta['pageCount']} pages)\n{card}\n"
                  f"  seven-names on card: {hit or 'none'}\n"
                  f"  seven-names in text: {mentions or 'none'}\n")
        if hit:
            refused.append((book_id, "card names " + ", ".join(hit)))
            continue
        label = "المكتبة الشاملة — " + "، ".join(x for x in (
            card_field(card, "الكتاب"), card_field(card, "المؤلف"),
            card_field(card, "الناشر"), card_field(card, "الطبعة")) if x)
        entries.append((book_id, t_ar, t_en, a_ar, a_en, death, cat, shelf, len(raw), label))
    out.write("\nREFUSED: " + (", ".join(f"{b} ({why})" for b, why in refused) or "none") + "\n")
    out.close()
    print(io.open(REPORT, encoding="utf-8").read())
    if report:
        return

    s3 = r2_client()
    for e in entries:
        body = open(os.path.join(BUILD, e[0] + ".json"), "rb").read()
        s3.put_object(Bucket=BUCKET, Key=f"books/text/{e[0]}.json", Body=body,
                      ContentType="application/json")
        if not public_ok(e[0], len(body)):
            sys.exit(f"{e[0]}: public endpoint did not return the uploaded bytes")
        print("uploaded + verified", e[0], len(body))

    src = io.open(CATALOG, encoding="utf-8").read()
    for rid in RETIRED:
        src, n = re.subn(
            r"\n  // [^\n]*\n  LibraryBook\(\n    id: '" + rid + r"',.*?\n  \),"
            r"|\n  LibraryBook\(\n    id: '" + rid + r"',.*?\n  \),",
            "", src, count=1, flags=re.S)
        print("retired", rid, n)
    lines = ["", "  // ── 2026-09-22 — library «المرحلة ١»: explained books, per the owner's",
             "  // rulings (no bare mutun; Shamela text as served). scripts/library_phase1.py."]
    for (bid, t_ar, t_en, a_ar, a_en, death, cat, shelf, size, label) in entries:
        lines += [
            "  LibraryBook(",
            f"    id: {dart_str(bid)},",
            f"    titleAr: {dart_str(t_ar)},",
            f"    titleEn: {dart_str(t_en)},",
            f"    authorAr: {dart_str(a_ar)},",
            f"    authorEn: {dart_str(a_en)},",
        ]
        if death:
            lines.append(f"    deathYearAh: {death},")
        lines.append(f"    category: BookCategory.{cat},")
        if shelf:
            lines.append(f"    shelfOrder: {shelf},")
        lines += [
            "    textEdition: TextEdition(",
            "      url:",
            f"          '${{AppConfig.contentBaseUrl}}/books/text/{bid}.json',",
            f"      sizeBytes: {size},",
            "      editorNotesRemoved: true,",
            f"      sourceLabel: {dart_str(label)},",
            "    ),",
            "  ),",
        ]
    end = src.rindex("];")
    src = src[:end].rstrip() + "\n" + "\n".join(lines) + "\n" + src[end:]
    io.open(CATALOG, "w", encoding="utf-8", newline="\n").write(src)
    print(f"catalogue: +{len(entries)} books, -{len(RETIRED)} mutun")


if __name__ == "__main__":
    main()
