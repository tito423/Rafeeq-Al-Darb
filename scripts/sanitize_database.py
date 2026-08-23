import sqlite3
import re
import sys
import shutil

sys.stdout.reconfigure(encoding='utf-8')

def clean_dua_content_and_ref(content, ref):
    if not content:
        return "", ""
    
    s = content.replace('\xa0', ' ')
    
    # Extract reference pattern like [البقرة - 201] or [آل عمران - 191-194]
    m = re.search(r'\[([^\]]+)\]', s)
    if m:
        extracted_ref = m.group(1).strip()
        # Clean extracted ref (remove dashes or normalize)
        extracted_ref = re.sub(r'^[.\s\-]+', '', extracted_ref)
        extracted_ref = re.sub(r'[.\s\-]+$', '', extracted_ref)
        ref = extracted_ref
        s = re.sub(r'\[[^\]]+\]', '', s)

    # Remove quotes, trailing dots, trailing dashes
    s = re.sub(r'["\'״”]+', '', s)
    s = re.sub(r'[.\s]+$', '', s)
    s = re.sub(r'^[.\s]+', '', s)
    
    if ref:
        ref = re.sub(r'["\'״”]+', '', ref)
        ref = re.sub(r'^[.\s\-]+', '', ref)
        ref = re.sub(r'[.\s\-]+$', '', ref)
        # Format nicely
        if not ref.startswith('سورة') and ('-' in ref or ':' in ref):
            parts = [p.strip() for p in re.split(r'[-:]', ref)]
            if len(parts) >= 2:
                ref = f"سورة {parts[0]}: {parts[1]}"
            else:
                ref = f"سورة {ref}"

    return s.strip(), ref.strip()

def clean_arabic_text(text):
    if not text or not isinstance(text, str):
        return text if text is not None else ""
    
    s = text
    s = s.replace('\xa0', ' ')

    # Remove python repr list artifacts
    s = re.sub(r"\\n['\"],\s*['\"]", "\n", s)
    s = re.sub(r"['\"],\s*['\"]\\n", "\n", s)
    s = re.sub(r"['\"],\s*['\"]", " ", s)
    s = re.sub(r"\\n", "\n", s)
    
    # Strip leading/trailing quote artifacts
    s = re.sub(r"^[\s'\",]+", "", s)
    s = re.sub(r"[\s'\",]+$", "", s)

    # Convert (( )) to « »
    s = re.sub(r'\(\(\s*', '«', s)
    s = re.sub(r'\s*\)\)', '»', s)

    lines = s.split('\n')
    cleaned_lines = []
    for line in lines:
        l = line.strip()
        if l in ["'", '"', ',', '.', "','", '","', '",', ",'", "''", '""', '—', '-']:
            continue
        if re.match(r"^[\s'\",.\-_]+$", l):
            continue
        l = re.sub(r"^['\"]+|['\"]+$", "", l).strip()
        if l:
            l = re.sub(r'[ \t]+', ' ', l)
            cleaned_lines.append(l)

    s = '\n'.join(cleaned_lines).strip()
    s = re.sub(r"^«\s*«", "«", s)
    s = re.sub(r"»\s*»$", "»", s)
    s = re.sub(r"^»", "", s)
    s = re.sub(r"«$", "", s)
    return s.strip()

def sanitize_quran_local_db(db_path):
    print(f"Sanitizing SQLite DB: {db_path}")
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    # 1. Sanitize 'azkar' table
    print("  -> Cleaning 'azkar' table...")
    cursor.execute("SELECT id, category, content, count, description, reference, fadl FROM azkar;")
    rows = cursor.fetchall()
    updated_azkar = 0
    for r in rows:
        id_val = r[0]
        cat = clean_arabic_text(r[1])
        content = clean_arabic_text(r[2])
        count = r[3].strip() if r[3] else "1"
        desc = clean_arabic_text(r[4])
        ref = clean_arabic_text(r[5])
        fadl = clean_arabic_text(r[6])

        if cat == 'دعاء' or ('[' in content and ']' in content):
            content, ref = clean_dua_content_and_ref(content, ref)

        cursor.execute(
            "UPDATE azkar SET category=?, content=?, count=?, description=?, reference=?, fadl=? WHERE id=?;",
            (cat, content, count, desc, ref, fadl, id_val)
        )
        updated_azkar += 1
    
    print(f"     Cleaned {updated_azkar} rows in 'azkar'.")

    # 2. Sanitize 'ayahs' table
    print("  -> Cleaning 'ayahs' table...")
    cursor.execute("SELECT id, text_uthmani, tafsir, tafsir_jalalayn, translation, word_meanings, irab, asbab FROM ayahs;")
    ayah_rows = cursor.fetchall()
    updated_ayahs = 0
    for r in ayah_rows:
        id_val = r[0]
        text_uthmani = r[1].strip() if r[1] else ""
        tafsir = clean_arabic_text(r[2])
        tafsir_jalalayn = clean_arabic_text(r[3])
        trans = clean_arabic_text(r[4])
        meanings = clean_arabic_text(r[5])
        irab = clean_arabic_text(r[6])
        asbab = clean_arabic_text(r[7])

        cursor.execute(
            """UPDATE ayahs SET 
               text_uthmani=?, tafsir=?, tafsir_jalalayn=?, translation=?, word_meanings=?, irab=?, asbab=? 
               WHERE id=?;""",
            (text_uthmani, tafsir, tafsir_jalalayn, trans, meanings, irab, asbab, id_val)
        )
        updated_ayahs += 1
    print(f"     Cleaned {updated_ayahs} rows in 'ayahs'.")

    # 3. Sanitize 'surahs' table
    print("  -> Cleaning 'surahs' table...")
    cursor.execute("SELECT id, name, english_name FROM surahs;")
    surah_rows = cursor.fetchall()
    for r in surah_rows:
        id_val = r[0]
        name = r[1].strip()
        en_name = r[2].strip()
        cursor.execute("UPDATE surahs SET name=?, english_name=? WHERE id=?;", (name, en_name, id_val))

    conn.commit()
    conn.execute("VACUUM;")
    conn.close()
    print("  -> Done sanitizing quran_local.db.")

def sanitize_hadith_db(db_path):
    print(f"\nSanitizing Hadith DB: {db_path}")
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    cursor.execute("SELECT id, text FROM hadiths;")
    rows = cursor.fetchall()
    updated = 0
    for r in rows:
        id_val = r[0]
        cleaned_text = clean_arabic_text(r[1])
        cursor.execute("UPDATE hadiths SET text=? WHERE id=?;", (cleaned_text, id_val))
        updated += 1

    conn.commit()
    conn.execute("VACUUM;")
    conn.close()
    print(f"  -> Cleaned {updated} hadiths in hadith.db.")

if __name__ == "__main__":
    sanitize_quran_local_db("assets/quran_local.db")
    if shutil.os.path.exists("assets/data/hadith.db"):
        sanitize_hadith_db("assets/data/hadith.db")
    print("\n✓ ALL DATABASES SANITIZED SUCCESSFULLY!")
