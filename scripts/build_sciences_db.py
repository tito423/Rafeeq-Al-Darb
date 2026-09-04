import json, os, re, sqlite3, html, io, sys

BASE = r"e:\My Projects\Rafiq-Al-Darb\scripts\temp_phase1"
APPDATA = r"e:\My Projects\Rafiq-Al-Darb\rafeeq_app\assets\data"
OUTDB = os.path.join(APPDATA, "quran_sciences.db")

report = io.StringIO()
def out(s=""):
    report.write(s + "\n")

POS_AR = {
    "N": "اسم", "PN": "اسم عَلَم", "PRON": "ضمير", "ADJ": "صفة",
    "DEM": "اسم إشارة", "REL": "اسم موصول", "INL": "حرف (آيات الابتداء)",
    "P": "حرف جر", "CONJ": "حرف عطف", "ACC": "حرف تنصيص", "ADV": "ظرف",
    "INTG": "أداة استفهام", "VOC": "حرف نداء", "NEG": "حرف نفي",
    "SUP": "حرف (تفسير/عطف بيان)", "V": "فعل",
}
CASE_AR = {"NOM": "مرفوع", "GEN": "مجرور", "ACC": "منصوب", "JUS": "مجزوم", "SUB": "منصوب"}
TAG_AR = {"PERF": "فعل ماضٍ", "IMPF": "فعل مضارع", "IMPV": "فعل أمر"}
NUM_AR = {"S": "مفرد", "D": "مثنى", "P": "جمع"}
GEN_AR = {"M": "مذكر", "F": "مؤنث"}

def clean_html(t):
    t = re.sub(r"<[^>]+>", " ", t)
    t = html.unescape(t)
    t = re.sub(r"[ \t]+", " ", t)
    t = re.sub(r"\n\s*\n+", "\n", t)
    return t.strip()

# ── 1) ayah counts from quran_local.db ──────────────────────────────
qcon = sqlite3.connect(os.path.join(APPDATA, "quran_local.db"))
counts = {r[0]: r[1] for r in qcon.execute(
    "SELECT surah_id, COUNT(*) FROM ayahs GROUP BY surah_id")}
qcon.close()
out(f"surah counts: {len(counts)}")

# ── 2) create sciences DB ───────────────────────────────────────────
if os.path.exists(OUTDB):
    os.remove(OUTDB)
con = sqlite3.connect(OUTDB)
cur = con.cursor()
cur.executescript("""
CREATE TABLE tafseer_texts(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  source TEXT NOT NULL, surah INTEGER NOT NULL,
  ayah_start INTEGER NOT NULL, ayah_end INTEGER NOT NULL,
  text TEXT NOT NULL);
CREATE TABLE word_meanings(
  surah INTEGER NOT NULL, ayah INTEGER NOT NULL, pos INTEGER NOT NULL,
  en TEXT, PRIMARY KEY(surah, ayah, pos));
CREATE TABLE word_grammar(
  surah INTEGER NOT NULL, ayah INTEGER NOT NULL, pos INTEGER NOT NULL,
  token TEXT, pos_ar TEXT, case_ar TEXT, root TEXT, lemma TEXT,
  PRIMARY KEY(surah, ayah, pos));
CREATE TABLE azkar_sections(
  id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL);
CREATE TABLE azkar_items(
  id INTEGER PRIMARY KEY AUTOINCREMENT, section_id INTEGER NOT NULL,
  body TEXT NOT NULL, footnote TEXT);
CREATE INDEX idx_wm ON word_meanings(surah, ayah);
CREATE INDEX idx_wg ON word_grammar(surah, ayah);
CREATE INDEX idx_tt ON tafseer_texts(source, surah, ayah_start, ayah_end);
""")

# ── 3) tafseer sources, real per-ayah data ──────────────────────────
# P3‑9: this used to read 3 "grouped ranges" files that turned out to only
# ever contain the first ~10 ayahs of every surah (api.quran.com's
# by_chapter endpoint paginates at 10/page by default; the original fetch
# never handled pagination) — load_grouped()'s range-fallback then silently
# stretched the *last present* verse's range to the end of the surah
# whenever a surah ran out of source data early, so ~83% of the Quran was
# showing an earlier, unrelated ayah's tafsir. Separately, the source
# labelled "jalalayn" was never real Tafsir al-Jalalayn at all — verified
# against api.quran.com's own `/resources/tafsirs` listing, id 14 (what was
# fetched) is and has always been Tafsir Ibn Kathir; real Jalalayn isn't
# offered by this provider. `fetch_tafsirs_complete.py` re-fetched all 3
# sources complete (`?per_page=300`, one request per chapter — covers even
# Al-Baqarah's 286 ayahs in one page) as real per-ayah JSON, and gives the
# third source its real, verified identity instead of a fabricated one.
TAFSIR_COMPLETE = os.path.join(BASE, "tafsir_complete")

def load_tafsir_complete(key, source):
    # Sources like Muyassar genuinely group several consecutive ayahs under
    # one shared commentary entry (a real characteristic of how the tafsir
    # itself is written, not missing data) — the entry then only carries
    # the *last* ayah of that group as its verse_key. Each entry's real
    # coverage is therefore (previous entry's ayah + 1) through its own
    # ayah, inferred from the actual sorted sequence of ayahs present.
    # Deliberately NOT extended past the last present entry to a surah's
    # final ayah — that exact "stretch to the end" fallback is what caused
    # the original bug (silently showing an earlier ayah's tafsir for
    # ~83% of the Quran once source data ran out early). If a surah's tail
    # genuinely has no entry, it's left with no tafsir for that source
    # rather than a fabricated/misattributed one.
    src_dir = os.path.join(TAFSIR_COMPLETE, key)
    if not os.path.isdir(src_dir):
        out(f"{source}: MISSING ({src_dir} not found — run fetch_tafsirs_complete.py first)")
        return 0
    n = 0
    missing = []
    for ch in range(1, 115):
        p = os.path.join(src_dir, f"ch{ch}.json")
        if not os.path.exists(p):
            missing.append(ch)
            continue
        items = json.load(open(p, encoding="utf-8"))
        parsed = []
        for it in items:
            vk = str(it.get("verse_key", ""))
            try:
                s, a = (int(x) for x in vk.split(":"))
            except Exception:
                continue
            txt = clean_html(it.get("text", ""))
            if not txt:
                continue
            parsed.append((s, a, txt))
        parsed.sort(key=lambda r: r[1])
        prev_a = 0
        for s, a, txt in parsed:
            a_lo = prev_a + 1 if a > prev_a else a
            cur.execute(
                "INSERT INTO tafseer_texts(source,surah,ayah_start,ayah_end,text) VALUES(?,?,?,?,?)",
                (source, s, a_lo, a, txt))
            n += 1
            prev_a = a
    out(f"{source}: {n} ayah entries (missing chapters: {missing or 'none'})")
    return n

load_tafsir_complete("muyassar", "muyassar")
load_tafsir_complete("ibn_kathir", "ibn_kathir")
load_tafsir_complete("qurtubi", "qurtubi")
# P3‑31 (2026‑09‑04): 4 more real Arabic tafsirs, same trusted pipeline —
# see fetch_tafsirs_complete.py's own comment for why these 4 specifically
# (every Arabic tafsir this already-vetted API actually offers) rather
# than the owner's full ~20-source wishlist.
load_tafsir_complete("tantawi", "tantawi")
load_tafsir_complete("tabari", "tabari")
load_tafsir_complete("sadi", "sadi")
load_tafsir_complete("baghawi", "baghawi")

con.commit()

# report partial counts
for src in ("muyassar", "ibn_kathir", "qurtubi", "tantawi", "tabari", "sadi", "baghawi"):
    c = cur.execute("SELECT COUNT(*) FROM tafseer_texts WHERE source=?", (src,)).fetchone()[0]
    out(f"tafseer {src}: {c} ranges")
# ── 4) word-by-word meanings (Quranic Arabic Corpus glosses) ────────
wm = json.load(open(os.path.join(BASE, "word_meanings.json"), encoding="utf-8"))
rows = [(w["s"], w["a"], w["pos"], w.get("en", "").strip())
        for w in wm["words"] if w.get("en", "").strip()]
cur.executemany("INSERT OR REPLACE INTO word_meanings(surah,ayah,pos,en) VALUES(?,?,?,?)", rows)
out(f"word_meanings rows: {len(rows)}")

# ── 5) word grammar / i'rab (Quranic Arabic Corpus 0.x XML) ────────
xml_path = os.path.join(BASE, "corpus_morphology.xml")
pat = re.compile(r'<word number="(\d+)" token="([^"]*)" morphology="([^"]*)"')
grows = []
with open(xml_path, encoding="utf-8") as f:
    ch = vs = 0
    for line in f:
        mch = re.search(r'<chapter number="(\d+)"', line)
        if mch:
            ch = int(mch.group(1))
            continue
        mvs = re.search(r'<verse number="(\d+)"', line)
        if mvs:
            vs = int(mvs.group(1))
            continue
        mw = pat.search(line)
        if mw:
            posn, token, morph = int(mw.group(1)), html.unescape(mw.group(2)), html.unescape(mw.group(3))
            mpos = re.search(r"POS:(\w+)", morph)
            pos_tag = mpos.group(1) if mpos else ""
            pos_ar = POS_AR.get(pos_tag, "حرف" if not pos_tag else pos_tag)
            case_ar = ""
            for c in ("NOM", "GEN", "ACC", "JUS", "SUB"):
                if re.search(r"\b" + c + r"\b", morph):
                    case_ar = CASE_AR[c]
                    break
            for t, ar in TAG_AR.items():
                if re.search(r"\b" + t + r"\b", morph):
                    if case_ar:
                        case_ar += " / " + ar
                    else:
                        case_ar = ar
                    break
            mroot = re.search(r"ROOT:(\S+)", morph)
            mlem = re.search(r"LEM:(\S+)", morph)
            num = next((NUM_AR[x] for x in ("S", "D", "P") if re.search(r"\b" + x + r"\b", morph)), "")
            gen = next((GEN_AR[x] for x in ("M", "F") if re.search(r"\b" + x + r"\b", morph)), "")
            extra = " ، ".join(x for x in (num, gen) if x)
            if extra:
                case_ar = (case_ar + " ، " + extra) if case_ar else extra
            grows.append((ch, vs, posn, token, pos_ar, case_ar,
                          mroot.group(1) if mroot else "", mlem.group(1) if mlem else ""))
cur.executemany("INSERT OR REPLACE INTO word_grammar(surah,ayah,pos,token,pos_ar,case_ar,root,lemma) VALUES(?,?,?,?,?,?,?,?)", grows)
out(f"word_grammar rows: {len(grows)}")

# ── 6) azkar (Hisn al-Muslim, real) ────────────────────────────────
az = json.load(open(os.path.join(BASE, "hisn_almuslim.json"), encoding="utf-8"))
n_sections = 0
n_items = 0
for title, body in az.items():
    cur.execute("INSERT INTO azkar_sections(title) VALUES(?)", (title,))
    sid = cur.lastrowid
    n_sections += 1
    texts = body.get("text", [])
    foots = body.get("footnote", []) or []
    for i, t in enumerate(texts):
        t = t.strip()
        if not t:
            continue
        foot = foots[i].strip() if i < len(foots) and isinstance(foots[i], str) else ""
        cur.execute("INSERT INTO azkar_items(section_id, body, footnote) VALUES(?,?,?)", (sid, t, foot))
        n_items += 1
out(f"azkar sections: {n_sections}, items: {n_items}")

con.commit()
cur.execute("VACUUM")
con.commit()
for t in ("tafseer_texts", "word_meanings", "word_grammar", "azkar_sections", "azkar_items"):
    c = cur.execute(f"SELECT COUNT(*) FROM {t}").fetchone()[0]
    out(f"table {t}: {c}")
con.close()
out(f"DB size: {os.path.getsize(OUTDB)} bytes")

open(r"e:\My Projects\Rafiq-Al-Darb\scripts\sciences_report.txt", "w", encoding="utf-8").write(report.getvalue())
print("BUILD DONE")
