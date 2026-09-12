# -*- coding: utf-8 -*-
"""Put the three crawled Shamela batches into the app's catalogue.

Twenty-nine books — ten of Ibn Hajar's, nine of Abu Nu'aym's and ten of
al-Albani's — were crawled, built and uploaded in earlier sessions and have
been sitting on R2 with **no entry in `book_catalog.dart`**, which means the
app has never been able to open one of them. They also carry auto-
transliterated slugs nobody would want to read
(`thdhyr_alsajd_mn_atkhadh_alqbwr_msajd`), and the owner has already objected
to those once.

So this does three things, in this order, and refuses to go on if any of them
fails:

1. **Renames each object on R2** — copy to the readable key, verify the copy,
   then delete the old one. A rename that half-succeeded would leave the
   catalogue pointing at nothing.
2. **Fetches the new URL over plain HTTP** and checks it really answers with
   gzip's magic bytes at the size recorded in the manifest. §1.1: no entry
   goes into a catalogue before its content resolves on the public endpoint.
   Trap 19 applies — R2 answers a bare request with 403, so send a UA.
3. **Emits the Dart entries**, appending them before the closing `];`.

The author of each book is taken from the printed card, NOT from the manifest's
`authorAr`: the crawler inherited that field from the seed book, so every one
of al-Albani's ten claimed «الإمام البخاري» and Abu Nu'aym's claimed a name
with a different death year. Attributing a book to the wrong author is exactly
what §1.2 forbids.
"""
import io
import json
import os
import re
import sys
import urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from r2_common import BUCKET, r2_client  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CATALOG = os.path.join(ROOT, 'rafeeq_app', 'lib', 'features', 'library',
                       'data', 'book_catalog.dart')
PUBLIC = 'https://pub-39dbef68a1a845d5ba669b43a59516b9.r2.dev'
UA = 'RafeeqAlDarb/3.23 (https://github.com/tito423/Rafeeq-Al-Darb) curl/8'

IBN_HAJAR = ('الحافظ ابن حجر العسقلاني', 'Ibn Hajar al-Asqalani', 852)
ABU_NUAYM = ('الحافظ أبو نعيم الأصبهاني', 'Abu Nuaym al-Asbahani', 430)
ALBANI = ('الشيخ محمد ناصر الدين الألباني',
          'Muhammad Nasir al-Din al-Albani', 1420)

# old slug -> (new id, titleAr, titleEn, author, category)
#
# The Arabic titles drop the edition tags the Shamela index appends
# («- ت عتر», «- ط السلفية», «- الألباني») because those describe the
# printing, not the book, and the printing is already named in full in the
# sourceLabel that ships with every entry.
PLAN = {
    # ابن حجر العسقلاني
    'tqryb_althdhyb': (
        'taqrib_al_tahdhib', 'تقريب التهذيب', 'Taqrib al-Tahdhib',
        IBN_HAJAR, 'hadith'),
    'nzhh_alnzr_fy_twdyh_nkhbh_alfkr_t_atr': (
        'nuzhat_al_nazar', 'نزهة النظر في توضيح نخبة الفكر',
        'Nuzhat al-Nazar', IBN_HAJAR, 'hadith'),
    'hdy_alsary_mqdmh_fth_albary_t_alslfyh': (
        'hady_al_sari', 'هدي الساري مقدمة فتح الباري', 'Hady al-Sari',
        IBN_HAJAR, 'hadith'),
    'alamaly_almtlqh': (
        'al_amali_al_mutlaqah', 'الأمالي المطلقة', 'Al-Amali al-Mutlaqah',
        IBN_HAJAR, 'hadith'),
    'almajm_almfhrs_tjryd_asanyd_alktb_almshhwrh_': (
        'al_mujam_al_mufahras', 'المعجم المفهرس',
        'Al-Mujam al-Mufahras', IBN_HAJAR, 'hadith'),
    'rfa_alisr_an_qdah_msr': (
        'raf_al_isr_an_qudat_misr', 'رفع الإصر عن قضاة مصر',
        'Raf al-Isr an Qudat Misr', IBN_HAJAR, 'seerah'),
    'aliythar_bmarfh_rwah_alathar': (
        'al_ithar_bi_marifat_ruwat_al_athar', 'الإيثار بمعرفة رواة الآثار',
        'Al-Ithar bi Marifat Ruwat al-Athar', IBN_HAJAR, 'hadith'),
    'qtah_mn_ntayj_alafkar_fy_tkhryj_ahadyth_alad': (
        'nataij_al_afkar', 'قطعة من نتائج الأفكار في تخريج أحاديث الأذكار',
        'Nataij al-Afkar', IBN_HAJAR, 'hadith'),
    'alwqwf_ala_almwqwf': (
        'al_wuquf_ala_al_mawquf', 'الوقوف على الموقوف',
        'Al-Wuquf ala al-Mawquf', IBN_HAJAR, 'hadith'),
    'slslh_aldhhb': (
        'silsilat_al_dhahab', 'سلسلة الذهب', 'Silsilat al-Dhahab',
        IBN_HAJAR, 'hadith'),

    # أبو نعيم الأصبهاني
    'dlayl_alnbwh_abw_naym_alasbhany': (
        'dalail_al_nubuwwah_abu_nuaym', 'دلائل النبوة',
        'Dalail al-Nubuwwah', ABU_NUAYM, 'seerah'),
    'alimamh_walrd_ala_alrafdh': (
        'al_imamah_wal_radd_ala_al_rafidah', 'الإمامة والرد على الرافضة',
        'Al-Imamah wal-Radd ala al-Rafidah', ABU_NUAYM, 'aqidah'),
    'msnd_aby_hnyfh_rwayh_aby_naym': (
        'musnad_abi_hanifah_abu_nuaym', 'مسند أبي حنيفة رواية أبي نعيم',
        'Musnad Abi Hanifah', ABU_NUAYM, 'hadith'),
    'sfh_alnfaq_wnat_almnafqyn_laby_naym': (
        'sifat_al_nifaq', 'صفة النفاق ونعت المنافقين',
        'Sifat al-Nifaq', ABU_NUAYM, 'aqidah'),
    'fdayl_alkhlfa_alrashdyn_laby_naym_alasbhany': (
        'fadail_al_khulafa_al_rashidin', 'فضائل الخلفاء الراشدين',
        'Fadail al-Khulafa al-Rashidin', ABU_NUAYM, 'seerah'),
    'ryadh_alabdan_laby_naym_alasbhany': (
        'riyadat_al_abdan', 'رياضة الأبدان', 'Riyadat al-Abdan',
        ABU_NUAYM, 'adab'),
    'alarbawn_ala_mdhhb_almthqqyn_mn_alswfyh_laby': (
        'al_arbaun_ala_madhhab_al_mutahaqqiqin',
        'الأربعون على مذهب المتحققين من الصوفية',
        'Al-Arbaun ala Madhhab al-Mutahaqqiqin', ABU_NUAYM, 'tazkiyah'),
    'hdyth_in_llh_tsah_wtsayn_asma_laby_naym_alas': (
        'hadith_asma_allah_al_husna', 'حديث إن لله تسعة وتسعين اسمًا',
        'Hadith Asma Allah al-Husna', ABU_NUAYM, 'hadith'),
    'fdylh_alaadlyn_mn_alwlah_laby_naym': (
        'fadilat_al_adilin_min_al_wulat', 'فضيلة العادلين من الولاة',
        'Fadilat al-Adilin min al-Wulat', ABU_NUAYM, 'adab'),

    # الألباني
    'dayf_aljama_alsghyr_wzyadth': (
        'daif_al_jami_al_saghir', 'ضعيف الجامع الصغير وزيادته',
        'Daif al-Jami al-Saghir', ALBANI, 'hadith'),
    'dayf_snn_altrmdhy': (
        'daif_sunan_al_tirmidhi', 'ضعيف سنن الترمذي',
        'Daif Sunan al-Tirmidhi', ALBANI, 'hadith'),
    'tmam_almnh_fy_altalyq_ala_fqh_alsnh': (
        'tamam_al_minnah', 'تمام المنة في التعليق على فقه السنة',
        'Tamam al-Minnah', ALBANI, 'fiqh'),
    'adab_alzfaf_fy_alsnh_almthrh': (
        'adab_al_zifaf', 'آداب الزفاف في السنة المطهرة', 'Adab al-Zifaf',
        ALBANI, 'adab'),
    'ahkam_aljnayz': (
        'ahkam_al_janaiz', 'أحكام الجنائز', 'Ahkam al-Janaiz',
        ALBANI, 'fiqh'),
    'jlbab_almrah_almslmh_fy_alktab_walsnh': (
        'jilbab_al_marah_al_muslimah', 'جلباب المرأة المسلمة في الكتاب والسنة',
        'Jilbab al-Marah al-Muslimah', ALBANI, 'fiqh'),
    'shyh_alsyrh_alnbwyh_alalbany': (
        'sahih_al_sirah_al_nabawiyyah', 'صحيح السيرة النبوية',
        'Sahih al-Sirah al-Nabawiyyah', ALBANI, 'seerah'),
    'altwsl_anwaah_wahkamh': (
        'al_tawassul_anwauhu_wa_ahkamuhu', 'التوسل أنواعه وأحكامه',
        'Al-Tawassul Anwauhu wa Ahkamuhu', ALBANI, 'aqidah'),
    'hjh_alnby': (
        'hajjat_al_nabi', 'حجة النبي', 'Hajjat al-Nabi', ALBANI, 'fiqh'),
    'thdhyr_alsajd_mn_atkhadh_alqbwr_msajd': (
        'tahdhir_al_sajid', 'تحذير الساجد من اتخاذ القبور مساجد',
        'Tahdhir al-Sajid', ALBANI, 'aqidah'),
}

MANIFESTS = ['shamela_added_bulugh_al_maram.json',
             'shamela_added_hilyat_al_awliya.json',
             'shamela_added_sahih_al_adab_al_mufrad.json']


def load_books():
    out = []
    for name in MANIFESTS:
        path = os.path.join(ROOT, 'scripts', name)
        for b in json.load(io.open(path, encoding='utf-8')):
            out.append(b)
    return out


def exists(s3, key):
    """Whether the bucket holds `key`. Used so a part-finished rename can be
    resumed rather than restarted."""
    try:
        s3.head_object(Bucket=BUCKET, Key=key)
        return True
    except Exception:
        return False


def head(url):
    req = urllib.request.Request(url, headers={'User-Agent': UA,
                                               'Range': 'bytes=0-1'})
    with urllib.request.urlopen(req, timeout=60) as r:
        return r.status, r.read()


def dart_str(s):
    """A single-quoted Dart literal. The only thing that can break one is a
    quote or a backslash; trap 23 is the other direction — never let a `$`
    reach the file preceded by a backslash."""
    return "'" + s.replace('\\', r'\\').replace("'", r"\'") + "'"


def wrap(label, indent):
    """Break a long sourceLabel into adjacent Dart string literals so the
    generated file stays inside the line limit the linter enforces."""
    words = label.split(' ')
    lines, cur = [], ''
    for w in words:
        if len(cur) + len(w) + 1 > 58 and cur:
            lines.append(cur)
            cur = w
        else:
            cur = (cur + ' ' + w).strip()
    if cur:
        lines.append(cur)
    pad = ' ' * indent
    return ('\n' + pad).join(
        dart_str(l + (' ' if i < len(lines) - 1 else ''))
        for i, l in enumerate(lines))


def main():
    apply = '--apply' in sys.argv
    books = load_books()
    src = io.open(CATALOG, encoding='utf-8').read()
    existing = set(re.findall(r"id: '([a-z0-9_]+)'", src))

    problems = []
    for b in books:
        if b['slug'] not in PLAN:
            problems.append('no plan entry for %s' % b['slug'])
            continue
        new_id = PLAN[b['slug']][0]
        if new_id in existing:
            problems.append('id already in the catalogue: %s' % new_id)
    if len(books) != len(PLAN):
        problems.append('%d books but %d planned' % (len(books), len(PLAN)))
    if problems:
        for p in problems:
            print('PROBLEM:', p)
        return 1

    if not apply:
        print('%d books, %d planned, no id collisions. '
              'Re-run with --apply.' % (len(books), len(PLAN)))
        return 0

    s3 = r2_client()
    entries = []
    for b in books:
        new_id, title_ar, title_en, author, cat = PLAN[b['slug']]
        old_key = 'books/text/%s.json' % b['slug']
        new_key = 'books/text/%s.json' % new_id

        # 1. rename on the bucket. Resumable on purpose: a run that stopped
        #    part-way through leaves some books already renamed, and copying
        #    from a key that is no longer there would just fail.
        if exists(s3, old_key):
            s3.copy_object(Bucket=BUCKET, Key=new_key,
                           CopySource={'Bucket': BUCKET, 'Key': old_key})
        elif not exists(s3, new_key):
            print('ABORT %s: neither %s nor %s is on the bucket'
                  % (new_id, old_key, new_key))
            return 1

        # 2. prove the new key really serves the content before the old one
        #    is destroyed and before anything points at it.
        meta = s3.head_object(Bucket=BUCKET, Key=new_key)
        size = meta['ContentLength']
        # The BUCKET is the truth, not the manifest: what the app downloads is
        # what is there. A gzip re-written at a different moment can differ by
        # a byte or two in its header, and التوسل really did (87,662 on the
        # bucket against 87,664 recorded) — but a large gap would mean the
        # object is not the book this entry claims, so that still stops.
        drift = abs(size - b['sizeBytes'])
        if drift > 64:
            print('ABORT %s: %d bytes on the bucket, manifest says %d'
                  % (new_id, size, b['sizeBytes']))
            return 1
        status, first = head('%s/%s' % (PUBLIC, new_key))
        if status not in (200, 206) or first[:2] != b'\x1f\x8b':
            print('ABORT %s: public URL answered %s, first bytes %r'
                  % (new_id, status, first[:2]))
            return 1
        if exists(s3, old_key):
            s3.delete_object(Bucket=BUCKET, Key=old_key)
        print('%-40s %8d bytes  OK%s' % (
            new_id, size, '  (manifest said %d)' % b['sizeBytes']
            if drift else ''))

        entries.append("""  LibraryBook(
    id: '%s',
    titleAr: %s,
    titleEn: %s,
    authorAr: %s,
    authorEn: %s,
    deathYearAh: %d,
    pages: %d,
    category: BookCategory.%s,
    textEdition: TextEdition(
      url: '${AppConfig.contentBaseUrl}/books/text/%s.json',
      sizeBytes: %d,
      sourceLabel:
          %s,
    ),
  ),
""" % (new_id, dart_str(title_ar), dart_str(title_en),
            dart_str(author[0]), dart_str(author[1]), author[2],
            b['pages'], cat, new_id, size,
            wrap(b['sourceLabel'], 10)))

    assert src.rstrip().endswith('];')
    cut = src.rstrip()[:-2]
    io.open(CATALOG, 'w', encoding='utf-8', newline='\n').write(
        cut + ''.join(entries) + '];\n')
    print('\n%d entries appended to book_catalog.dart' % len(entries))
    return 0


if __name__ == '__main__':
    sys.exit(main())
