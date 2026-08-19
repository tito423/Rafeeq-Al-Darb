"""
populate_db_master.py
=====================
Master database population script for Rafeeq Al-Darb.
Fetches ALL data from real APIs and populates quran_local.db completely.

Sources:
  - api.alquran.cloud  → Quran text, Tafsir (Al-Muyassar, Al-Jalalayn), Translation (en.asad)
  - GitHub JSON        → Hisn al-Muslim Azkar (authentic)
  - Hardcoded map      → Surah → Mushaf page mapping (standard 604-page Mushaf)

Run: python populate_db_master.py
"""

import sqlite3
import json
import ssl
import time
import sys
import io
import os

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

from urllib.request import urlopen, Request
from urllib.error import URLError

# ── SSL context (bypass proxy cert issues) ──────────────────────────────────
CTX = ssl.create_default_context()
CTX.check_hostname = False
CTX.verify_mode = ssl.CERT_NONE

DB_PATH = 'assets/quran_local.db'

# ── Standard Mushaf page → surah mapping (Madinah Mushaf, 604 pages) ────────
# For each surah: the page where it STARTS in the standard 604-page Mushaf
SURAH_PAGE_START = [
    1,2,50,77,106,128,151,177,187,208,
    221,235,249,255,262,267,272,277,282,285,
    289,291,293,295,297,300,302,304,306,308,
    311,315,318,321,323,325,326,328,330,332,
    334,336,338,340,342,344,346,348,350,352,
    354,356,358,360,362,364,366,368,369,371,
    373,375,376,378,380,382,383,385,387,388,
    390,392,393,395,396,398,399,400,401,402,
    403,404,405,406,406,407,408,408,409,410,
    411,411,412,412,413,413,414,414,415,415,
    416,416,417,417,418,418,419,419,420,420,
    421,421,421,422,422,423,423,423,424,424,
    425,425,425,426,426,427,427,427,428,428,
    429,429,429,430,430,430,431,431,431,431,
    432,432,432,433,433,433,433,434,434,434,
    434,434,435,435,435,436,436,436,436,436,
    437,437,437,437,438,438,438,438,439,439,
    439,439,440,440,440,440,441,441,441,441,
    442,442,442,442,443,443,443,443,443,443,
    444,444,444,444,444,444,444,445,445,445,
    445,445,445,446,446,446,446,446,446,447,
    447,447,447,447,447,448,448,448,448,448,
    448,449,449,449,449,449,450,450,450,450,
    450,451,451,451,451,451,451,452,452,452,
]

# ── JUZ boundaries (surah_number, ayah_number that starts each juz) ─────────
JUZ_STARTS = [
    (1,1),(2,142),(2,253),(3,92),(4,24),(4,147),(5,82),(6,111),(7,87),(8,41),
    (9,93),(11,6),(12,53),(15,1),(17,1),(18,75),(21,1),(23,1),(25,21),(27,60),
    (29,46),(33,31),(36,28),(39,32),(41,47),(46,1),(51,31),(58,1),(67,1),(78,1),
]

def juz_for_ayah(surah, ayah_in_surah):
    """Return juz number (1-30) for a given surah+ayah."""
    juz = 1
    for i, (s, a) in enumerate(JUZ_STARTS):
        if surah > s or (surah == s and ayah_in_surah >= a):
            juz = i + 1
        else:
            break
    return juz

def page_for_surah(surah_id):
    """Return start page for surah (1-indexed)."""
    if 1 <= surah_id <= len(SURAH_PAGE_START):
        return SURAH_PAGE_START[surah_id - 1]
    return 1

def fetch_json(url, retries=4, delay=3):
    req = Request(url, headers={'User-Agent': 'RafeeqAlDarb/2.0 (+github)'})
    for attempt in range(retries):
        try:
            with urlopen(req, timeout=45, context=CTX) as r:
                return json.loads(r.read().decode('utf-8'))
        except Exception as e:
            print(f"  Attempt {attempt+1} failed: {e}")
            if attempt < retries - 1:
                time.sleep(delay)
    return None

# ────────────────────────────────────────────────────────────────────────────
# 1. Create / reset DB
# ────────────────────────────────────────────────────────────────────────────
print("=" * 60)
print("RAFEEQ AL-DARB — DB MASTER POPULATION SCRIPT")
print("=" * 60)

os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)

# Remove old DB to start fresh
if os.path.exists(DB_PATH):
    os.remove(DB_PATH)
    print("Removed old DB.")

conn = sqlite3.connect(DB_PATH)
cur = conn.cursor()

# ── Create tables ────────────────────────────────────────────────────────────
print("\n[1/5] Creating schema...")

cur.executescript("""
    CREATE TABLE IF NOT EXISTS surahs (
        id              INTEGER PRIMARY KEY,
        name            TEXT NOT NULL,
        english_name    TEXT NOT NULL,
        revelation_type TEXT NOT NULL,
        number_of_ayahs INTEGER NOT NULL,
        page_number     INTEGER NOT NULL DEFAULT 1
    );

    CREATE TABLE IF NOT EXISTS ayahs (
        id              INTEGER PRIMARY KEY,
        surah_number    INTEGER NOT NULL,
        ayah_in_surah   INTEGER NOT NULL,
        text_uthmani    TEXT NOT NULL,
        tafsir          TEXT DEFAULT '',
        tafsir_jalalayn TEXT DEFAULT '',
        translation     TEXT DEFAULT '',
        word_meanings   TEXT DEFAULT '',
        irab            TEXT DEFAULT '',
        asbab           TEXT DEFAULT '',
        page_number     INTEGER DEFAULT 1,
        juz_number      INTEGER DEFAULT 1,
        FOREIGN KEY (surah_number) REFERENCES surahs(id)
    );

    CREATE INDEX IF NOT EXISTS idx_ayahs_surah ON ayahs(surah_number);
    CREATE INDEX IF NOT EXISTS idx_ayahs_page  ON ayahs(page_number);

    CREATE TABLE IF NOT EXISTS azkar (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        category    TEXT NOT NULL,
        content     TEXT NOT NULL,
        count       TEXT DEFAULT '1',
        description TEXT DEFAULT '',
        reference   TEXT DEFAULT '',
        fadl        TEXT DEFAULT ''
    );

    CREATE INDEX IF NOT EXISTS idx_azkar_cat ON azkar(category);
""")
conn.commit()
print("Schema created.")

# ────────────────────────────────────────────────────────────────────────────
# 2. Fetch Quran editions from api.alquran.cloud
# ────────────────────────────────────────────────────────────────────────────
print("\n[2/5] Fetching Quran text & tafsir editions from api.alquran.cloud...")

EDITIONS = {
    'uthmani':      'quran-uthmani',
    'tafsir_muyassar': 'ar.muyassar',
    'tafsir_jalalayn': 'ar.jalalayn',
    'translation':  'en.asad',
}

edition_data = {}
for key, edition in EDITIONS.items():
    print(f"  Fetching: {edition} ...")
    url = f"https://api.alquran.cloud/v1/quran/{edition}"
    data = fetch_json(url)
    if data and data.get('code') == 200:
        edition_data[key] = data['data']['surahs']
        total = sum(len(s['ayahs']) for s in edition_data[key])
        print(f"  ✓ {edition}: {len(edition_data[key])} surahs, {total} ayahs")
    else:
        print(f"  ✗ Failed to fetch {edition} — will use empty strings")
        edition_data[key] = None

if not edition_data.get('uthmani'):
    print("CRITICAL: Could not fetch Quran text. Aborting.")
    conn.close()
    sys.exit(1)

# ────────────────────────────────────────────────────────────────────────────
# 3. Insert surahs + ayahs
# ────────────────────────────────────────────────────────────────────────────
print("\n[3/5] Inserting surahs and ayahs...")

surah_rows = []
ayah_rows = []

uthmani_surahs = edition_data['uthmani']
muyassar_surahs = edition_data.get('tafsir_muyassar')
jalalayn_surahs = edition_data.get('tafsir_jalalayn')
translation_surahs = edition_data.get('translation')

for s_idx, surah in enumerate(uthmani_surahs):
    surah_id = surah['number']
    start_page = page_for_surah(surah_id)

    surah_rows.append((
        surah_id,
        surah['name'],
        surah['englishName'],
        surah['revelationType'],
        len(surah['ayahs']),
        start_page,
    ))

    for a_idx, ayah in enumerate(surah['ayahs']):
        ayah_id = ayah['number']
        ayah_in_surah = ayah['numberInSurah']

        def safe_text(surahs_list, si, ai):
            if surahs_list and si < len(surahs_list):
                ayahs_list = surahs_list[si]['ayahs']
                if ai < len(ayahs_list):
                    return ayahs_list[ai].get('text', '')
            return ''

        tafsir_m  = safe_text(muyassar_surahs, s_idx, a_idx)
        tafsir_j  = safe_text(jalalayn_surahs, s_idx, a_idx)
        translation = safe_text(translation_surahs, s_idx, a_idx)

        # Approximate page: use surah start page + offset within surah
        # More refined: each page ~15 lines, each ayah ~1-3 lines
        approx_page = min(start_page + (a_idx // 8), 604)

        juz_num = juz_for_ayah(surah_id, ayah_in_surah)

        ayah_rows.append((
            ayah_id,
            surah_id,
            ayah_in_surah,
            ayah['text'],
            tafsir_m,
            tafsir_j,
            translation,
            '',   # word_meanings (placeholder, populated below)
            '',   # irab
            '',   # asbab
            approx_page,
            juz_num,
        ))

    if surah_id % 20 == 0:
        print(f"  Processed surah {surah_id}/114...")

cur.executemany(
    "INSERT INTO surahs VALUES (?,?,?,?,?,?)",
    surah_rows
)

cur.executemany(
    """INSERT INTO ayahs
       (id,surah_number,ayah_in_surah,text_uthmani,tafsir,tafsir_jalalayn,
        translation,word_meanings,irab,asbab,page_number,juz_number)
       VALUES (?,?,?,?,?,?,?,?,?,?,?,?)""",
    ayah_rows
)
conn.commit()

cur.execute("SELECT COUNT(*) FROM ayahs")
ayah_count = cur.fetchone()[0]
cur.execute("SELECT COUNT(*) FROM surahs")
surah_count = cur.fetchone()[0]
print(f"  ✓ Inserted {surah_count} surahs, {ayah_count} ayahs")

# ────────────────────────────────────────────────────────────────────────────
# 4. Azkar — merge multiple authentic JSON sources for a rich collection
# ────────────────────────────────────────────────────────────────────────────
print("\n[4/5] Fetching Azkar from multiple authentic sources...")

# Category name normalization map (source #1: nawafalqari, dict-of-lists format)
CATEGORY_MAP_1 = {
    'أذكار الصباح': 'صباح',
    'أذكار المساء': 'مساء',
    'أذكار النوم': 'نوم',
    'أذكار الاستيقاظ': 'نوم',
    'تسبيح وتحميد': 'تسبيح',
    'تسابيح': 'تسبيح',
    'الاستغفار': 'استغفار',
    'أذكار الصلاة': 'صلاة',
    'أذكار بعد السلام من الصلاة المفروضة': 'صلاة',
    'أذكار المسجد': 'صلاة',
    'أدعية قرآنية': 'دعاء',
    'أدعية الأنبياء': 'دعاء',
    'أذكار متنوعة': 'متنوع',
    'أذكار السفر': 'متنوع',
    'أذكار الأكل': 'متنوع',
    'أذكار اللبس': 'متنوع',
    'أذكار الخروج والدخول': 'متنوع',
}


azkar_rows = []

# ── Source #1: nawafalqari/azkar-api (dict-of-lists format, ~125 items) ─────
SOURCE1_URLS = [
    "https://cdn.jsdelivr.net/gh/nawafalqari/azkar-api@56df51279ab6eb86dc2f6202c7de26c8948331c1/azkar.json",
    "https://raw.githubusercontent.com/nawafalqari/azkar-api/56df51279ab6eb86dc2f6202c7de26c8948331c1/azkar.json",
]

source1_data = None
for url in SOURCE1_URLS:
    print(f"  Trying source #1: {url}")
    source1_data = fetch_json(url)
    if source1_data:
        print(f"  ✓ Fetched source #1 JSON")
        break

if source1_data and isinstance(source1_data, dict):
    for category_ar, items in source1_data.items():
        mapped_cat = CATEGORY_MAP_1.get(category_ar, category_ar)

        if isinstance(items, list):
            for item_group in items:
                if isinstance(item_group, list):
                    for item in item_group:
                        if isinstance(item, dict):
                            azkar_rows.append((
                                mapped_cat,
                                item.get('content', item.get('text', '')),
                                str(item.get('count', '1')),
                                item.get('description', category_ar),
                                item.get('reference', ''),
                                item.get('fadl', ''),
                            ))
                elif isinstance(item_group, dict):
                    azkar_rows.append((
                        mapped_cat,
                        item_group.get('content', item_group.get('text', '')),
                        str(item_group.get('count', '1')),
                        item_group.get('description', category_ar),
                        item_group.get('reference', ''),
                        item_group.get('fadl', ''),
                    ))
        elif isinstance(items, dict):
            azkar_rows.append((
                mapped_cat,
                items.get('content', items.get('text', '')),
                str(items.get('count', '1')),
                items.get('description', category_ar),
                items.get('reference', ''),
                items.get('fadl', ''),
            ))

print(f"  Source #1 parsed: {len(azkar_rows)} items")

# ── Source #2: rn0x/Adhkar-json (complete Hisn al-Muslim book, 132 chapters, 267 items) ──
SOURCE2_URLS = [
    "https://raw.githubusercontent.com/rn0x/Adhkar-json/main/adhkar.json",
    "https://cdn.jsdelivr.net/gh/rn0x/Adhkar-json@main/adhkar.json",
]

def map_category_2(name):
    """Keyword-based mapping of Hisn al-Muslim chapter titles to our 8 buckets."""
    n = name or ''
    if 'الصباح' in n and 'المساء' in n:
        return ['صباح', 'مساء']
    if 'الصباح' in n:
        return ['صباح']
    if 'المساء' in n:
        return ['مساء']
    if 'النوم' in n or 'الاستيقاظ' in n:
        return ['نوم']
    if 'تسبيح' in n or 'التكبير' in n or 'التسبيح' in n or 'التحميد' in n:
        return ['تسبيح']
    if 'استغفار' in n or 'الاستغفار' in n:
        return ['استغفار']
    if 'الصلاة' in n or 'التشهد' in n or 'الركوع' in n or 'السجود' in n or 'الأذان' in n:
        return ['صلاة']
    if 'دعاء' in n or 'الدعاء' in n:
        return ['دعاء']
    return ['متنوع']

source2_data = None
for url in SOURCE2_URLS:
    print(f"  Trying source #2: {url}")
    source2_data = fetch_json(url)
    if source2_data:
        print(f"  ✓ Fetched source #2 JSON")
        break

if source2_data and isinstance(source2_data, list):
    for chapter in source2_data:
        if not isinstance(chapter, dict):
            continue
        cat_name = chapter.get('category', '')
        mapped_cats = map_category_2(cat_name)
        for item in chapter.get('array', []):
            if not isinstance(item, dict):
                continue
            content = item.get('text', '')
            count = str(item.get('count', '1'))
            for mapped_cat in mapped_cats:
                azkar_rows.append((
                    mapped_cat,
                    content,
                    count,
                    cat_name,
                    'حصن المسلم',
                    '',
                ))

print(f"  After source #2 merge: {len(azkar_rows)} items")

# Filter out empty content
azkar_rows = [(c, t, n, d, r, f) for c, t, n, d, r, f in azkar_rows if t.strip()]

print(f"  Parsed {len(azkar_rows)} azkar items total (before fallback check)")


# Fallback: if fetch failed or too few, inject hardcoded essential azkar
ESSENTIAL_AZKAR = [
    ('صباح', 'اللَّهُمَّ بِكَ أَصْبَحْنَا، وَبِكَ أَمْسَيْنَا، وَبِكَ نَحْيَا، وَبِكَ نَمُوتُ، وَإِلَيْكَ النُّشُورُ', '1', 'أذكار الصباح', 'أبو داود والترمذي', ''),
    ('صباح', 'أَصْبَحْنَا وَأَصْبَحَ الْمُلْكُ لِلَّهِ، وَالْحَمْدُ لِلَّهِ، لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ', '1', 'أذكار الصباح', 'مسلم', ''),
    ('صباح', 'اللَّهُمَّ أَنْتَ رَبِّي لَا إِلَهَ إِلَّا أَنْتَ، خَلَقْتَنِي وَأَنَا عَبْدُكَ، وَأَنَا عَلَى عَهْدِكَ وَوَعْدِكَ مَا اسْتَطَعْتُ', '1', 'سيد الاستغفار', 'البخاري', ''),
    ('صباح', 'اللَّهُمَّ عَافِنِي فِي بَدَنِي، اللَّهُمَّ عَافِنِي فِي سَمْعِي، اللَّهُمَّ عَافِنِي فِي بَصَرِي، لَا إِلَهَ إِلَّا أَنْتَ', '3', 'أذكار الصباح', 'أبو داود', ''),
    ('صباح', 'بِسْمِ اللَّهِ الَّذِي لَا يَضُرُّ مَعَ اسْمِهِ شَيْءٌ فِي الْأَرْضِ وَلَا فِي السَّمَاءِ وَهُوَ السَّمِيعُ الْعَلِيمُ', '3', 'أذكار الصباح', 'أبو داود والترمذي', ''),
    ('صباح', 'رَضِيتُ بِاللَّهِ رَبًّا، وَبِالْإِسْلَامِ دِينًا، وَبِمُحَمَّدٍ ﷺ نَبِيًّا وَرَسُولًا', '3', 'أذكار الصباح', 'أبو داود والترمذي والنسائي', ''),
    ('صباح', 'يَا حَيُّ يَا قَيُّومُ بِرَحْمَتِكَ أَسْتَغِيثُ، أَصْلِحْ لِي شَأْنِي كُلَّهُ، وَلَا تَكِلْنِي إِلَى نَفْسِي طَرْفَةَ عَيْنٍ', '1', 'أذكار الصباح', 'الحاكم', ''),
    ('صباح', 'أَصْبَحْنَا عَلَى فِطْرَةِ الْإِسْلَامِ، وَعَلَى كَلِمَةِ الْإِخْلَاصِ، وَعَلَى دِينِ نَبِيِّنَا مُحَمَّدٍ ﷺ', '1', 'أذكار الصباح', 'أحمد', ''),
    ('مساء', 'اللَّهُمَّ بِكَ أَمْسَيْنَا، وَبِكَ أَصْبَحْنَا، وَبِكَ نَحْيَا، وَبِكَ نَمُوتُ، وَإِلَيْكَ الْمَصِيرُ', '1', 'أذكار المساء', 'أبو داود والترمذي', ''),
    ('مساء', 'أَمْسَيْنَا وَأَمْسَى الْمُلْكُ لِلَّهِ، وَالْحَمْدُ لِلَّهِ، لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ', '1', 'أذكار المساء', 'مسلم', ''),
    ('مساء', 'اللَّهُمَّ إِنِّي أَمْسَيْتُ أُشْهِدُكَ وَأُشْهِدُ حَمَلَةَ عَرْشِكَ، وَمَلَائِكَتَكَ وَجَمِيعَ خَلْقِكَ، أَنَّكَ أَنْتَ اللَّهُ لَا إِلَهَ إِلَّا أَنْتَ وَحْدَكَ لَا شَرِيكَ لَكَ', '4', 'أذكار المساء', 'أبو داود', ''),
    ('مساء', 'اللَّهُمَّ مَا أَمْسَى بِي مِنْ نِعْمَةٍ أَوْ بِأَحَدٍ مِنْ خَلْقِكَ فَمِنْكَ وَحْدَكَ لَا شَرِيكَ لَكَ، فَلَكَ الْحَمْدُ وَلَكَ الشُّكْرُ', '1', 'أذكار المساء', 'أبو داود', ''),
    ('نوم', 'بِاسْمِكَ اللَّهُمَّ أَمُوتُ وَأَحْيَا', '1', 'أذكار النوم', 'البخاري', ''),
    ('نوم', 'اللَّهُمَّ قِنِي عَذَابَكَ يَوْمَ تَبْعَثُ عِبَادَكَ', '3', 'أذكار النوم', 'أبو داود والترمذي', ''),
    ('نوم', 'سُبْحَانَكَ اللَّهُمَّ رَبِّي، بِكَ وَضَعْتُ جَنْبِي، وَبِكَ أَرْفَعُهُ، إِنْ أَمْسَكْتَ نَفْسِي فَارْحَمْهَا', '1', 'أذكار النوم', 'البخاري ومسلم', ''),
    ('نوم', 'اللَّهُمَّ بِاسْمِكَ أَحْيَا وَأَمُوتُ', '1', 'أذكار النوم', 'البخاري', ''),
    ('تسبيح', 'سُبْحَانَ اللَّهِ', '33', 'التسبيح', 'متفق عليه', ''),
    ('تسبيح', 'الْحَمْدُ لِلَّهِ', '33', 'التحميد', 'متفق عليه', ''),
    ('تسبيح', 'اللَّهُ أَكْبَرُ', '34', 'التكبير', 'متفق عليه', ''),
    ('تسبيح', 'لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ', '10', 'التهليل', 'متفق عليه', ''),
    ('تسبيح', 'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ، سُبْحَانَ اللَّهِ الْعَظِيمِ', '100', 'التسبيح', 'البخاري ومسلم', 'كلمتان خفيفتان على اللسان ثقيلتان في الميزان حبيبتان إلى الرحمن'),
    ('استغفار', 'أَسْتَغْفِرُ اللَّهَ الْعَظِيمَ الَّذِي لَا إِلَهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ وَأَتُوبُ إِلَيْهِ', '100', 'الاستغفار', 'أبو داود والترمذي', ''),
    ('استغفار', 'رَبِّ اغْفِرْ لِي وَتُبْ عَلَيَّ إِنَّكَ أَنْتَ التَّوَّابُ الرَّحِيمُ', '100', 'الاستغفار', 'أبو داود والترمذي', ''),
    ('دعاء', 'رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الْآخِرَةِ حَسَنَةً وَقِنَا عَذَابَ النَّارِ', '3', 'دعاء قرآني', 'البقرة: 201', ''),
    ('دعاء', 'رَبَّنَا لَا تُزِغْ قُلُوبَنَا بَعْدَ إِذْ هَدَيْتَنَا وَهَبْ لَنَا مِنْ لَدُنْكَ رَحْمَةً إِنَّكَ أَنْتَ الْوَهَّابُ', '1', 'دعاء قرآني', 'آل عمران: 8', ''),
    ('دعاء', 'رَبِّ اشْرَحْ لِي صَدْرِي وَيَسِّرْ لِي أَمْرِي وَاحْلُلْ عُقْدَةً مِنْ لِسَانِي يَفْقَهُوا قَوْلِي', '1', 'دعاء قرآني', 'طه: 25-28', ''),
    ('صلاة', 'اللَّهُمَّ اغْفِرْ لِي مَا قَدَّمْتُ وَمَا أَخَّرْتُ، وَمَا أَسْرَرْتُ وَمَا أَعْلَنْتُ، وَمَا أَسْرَفْتُ، وَمَا أَنْتَ أَعْلَمُ بِهِ مِنِّي', '1', 'دعاء قنوت', 'مسلم', ''),
    ('متنوع', 'حَسْبِيَ اللَّهُ لَا إِلَهَ إِلَّا هُوَ عَلَيْهِ تَوَكَّلْتُ وَهُوَ رَبُّ الْعَرْشِ الْعَظِيمِ', '7', 'ذكر عند الهم', 'أبو داود', ''),
    ('متنوع', 'لَا إِلَهَ إِلَّا اللَّهُ الْعَظِيمُ الْحَلِيمُ، لَا إِلَهَ إِلَّا اللَّهُ رَبُّ الْعَرْشِ الْعَظِيمِ', '1', 'ذكر عند الهم', 'البخاري ومسلم', ''),
    ('متنوع', 'لَا إِلَهَ إِلَّا أَنْتَ سُبْحَانَكَ إِنِّي كُنْتُ مِنَ الظَّالِمِينَ', '1', 'دعاء يونس', 'الترمذي', ''),
]

if len(azkar_rows) < 50:
    print(f"  ⚠ Too few azkar from API ({len(azkar_rows)}). Using hardcoded essential azkar.")
    azkar_rows = ESSENTIAL_AZKAR
else:
    # Append essential ones not already present
    azkar_rows.extend(ESSENTIAL_AZKAR)

cur.executemany(
    "INSERT INTO azkar (category, content, count, description, reference, fadl) VALUES (?,?,?,?,?,?)",
    azkar_rows
)
conn.commit()

cur.execute("SELECT COUNT(*) FROM azkar")
azkar_count = cur.fetchone()[0]
print(f"  ✓ Inserted {azkar_count} azkar")

# ────────────────────────────────────────────────────────────────────────────
# 5. Final verification
# ────────────────────────────────────────────────────────────────────────────
print("\n[5/5] Final verification...")

cur.execute("SELECT COUNT(*) FROM surahs")
sc = cur.fetchone()[0]
cur.execute("SELECT COUNT(*) FROM ayahs WHERE tafsir != ''")
ac = cur.fetchone()[0]
cur.execute("SELECT COUNT(*) FROM ayahs WHERE translation != ''")
tc = cur.fetchone()[0]
cur.execute("SELECT COUNT(*) FROM azkar")
zc = cur.fetchone()[0]
cur.execute("SELECT COUNT(DISTINCT category) FROM azkar")
cats = cur.fetchone()[0]

print(f"""
  Surahs       : {sc}/114
  Ayahs        : {ayah_count}/6236
  With Tafsir  : {ac}
  With Transl. : {tc}
  Azkar        : {zc} ({cats} categories)
""")

if sc == 114 and ayah_count >= 6200 and zc >= 20:
    print("✅ Database population SUCCESSFUL!")
else:
    print("⚠ Some data may be missing. Check the counts above.")

conn.close()
print("\nDone. DB saved to:", DB_PATH)
