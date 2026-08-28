import json, os, re, sqlite3, html, io, sys

BASE = r"e:\My Projects\Rafiq-Al-Darb\scripts\temp_phase1"
APPDATA = r"e:\My Projects\Rafiq-Al-Darb\rafeeq_app\assets\data"
OUTDB = os.path.join(APPDATA, "quran_sciences.db")
QC = os.path.join(BASE, "tafsir_qc")

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
CREATE TABLE ayah_sciences(
  surah INTEGER NOT NULL, ayah INTEGER NOT NULL,
  tafseer_saadi TEXT, tafseer_ibn_kathir TEXT,
  PRIMARY KEY(surah, ayah));
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

# ── 3) tafseer sources (grouped ranges stored once — normalized) ────
def load_grouped(fname, source):
    d = json.load(open(os.path.join(BASE, fname), encoding="utf-8"))
    verses = sorted(d["verses"], key=lambda v: (v["s"], v["a"]))
    by_surah = {}
    for v in verses:
        by_surah.setdefault(v["s"], []).append(v)
    n = 0
    for s, lst in by_surah.items():
        if s not in counts:
            continue
        end = counts[s]
        for i, v in enumerate(lst):
            nxt = lst[i + 1]["a"] if i + 1 < len(lst) and lst[i + 1]["s"] == s else end + 1
            a_hi = min(nxt - 1, end)
            if a_hi < v["a"]:
                a_hi = v["a"]
            txt = clean_html(v["text"])
            if not txt:
                continue
            cur.execute(
                "INSERT INTO tafseer_texts(source,surah,ayah_start,ayah_end,text) VALUES(?,?,?,?,?)",
                (source, s, v["a"], a_hi, txt))
            n += 1
    out(f"{source}: {n} range entries")
    return n

load_grouped("tafseer_ar_muyassar.json", "muyassar")
load_grouped("tafseer_ar_jalalayn.json", "jalalayn")
load_grouped("tafseer_ar_qurtubi.json", "qurtubi")

# quran.com tafsirs (per-verse)
def load_qc(tafsir_id, col):
    done = os.path.exists(os.path.join(QC, "_complete.txt"))
    if not os.path.isdir(QC):
        out(f"{col}: FETCH PENDING (background fetch not complete)")
        return
    n = 0
    missing = []
    for ch in range(1, 115):
        p = os.path.join(QC, f"{tafsir_id}_ch{ch}.json")
        if not os.path.exists(p):
            missing.append(ch)
            continue
        try:
            d = json.load(open(p, encoding="utf-8-sig"))
        except Exception as e:
            out(f"{col} ch{ch} PARSE ERROR {e}")
            continue
        items = d.get("tafsirs") if isinstance(d, dict) else None
        if items is None and isinstance(d, dict):
            items = d.get("verses") or []
        for it in items or []:
            vk = str(it.get("verse_key", ""))
            try:
                s, a = (int(x) for x in vk.split(":"))
            except Exception:
                continue
            txt = clean_html(it.get("text", ""))
            if not txt:
                continue
            cur.execute(
                f"INSERT INTO ayah_sciences(surah,ayah,{col}) VALUES(?,?,?) "
                f"ON CONFLICT(surah,ayah) DO UPDATE SET {col}=excluded.{col}",
                (s, a, txt))
            n += 1
    out(f"{col}: {n} ayah rows (fetch complete={done}, missing={len(missing)})")

load_qc(91, "tafseer_saadi")
load_qc(14, "tafseer_ibn_kathir")

con.commit()

# report partial counts
for src in ("muyassar", "jalalayn", "qurtubi"):
    c = cur.execute("SELECT COUNT(*) FROM tafseer_texts WHERE source=?", (src,)).fetchone()[0]
    out(f"tafseer {src}: {c} ranges")
for col in ("tafseer_saadi", "tafseer_ibn_kathir"):
    c = cur.execute(f"SELECT COUNT({col}) FROM ayah_sciences WHERE {col} IS NOT NULL").fetchone()[0]
    out(f"col {col}: {c}")

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
for t in ("tafseer_texts", "ayah_sciences", "word_meanings", "word_grammar", "azkar_sections", "azkar_items"):
    c = cur.execute(f"SELECT COUNT(*) FROM {t}").fetchone()[0]
    out(f"table {t}: {c}")
con.close()
out(f"DB size: {os.path.getsize(OUTDB)} bytes")

open(r"e:\My Projects\Rafiq-Al-Darb\scripts\sciences_report.txt", "w", encoding="utf-8").write(report.getvalue())
print("BUILD DONE")
