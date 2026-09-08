"""Rehost one Quran translation per language to R2, for on-demand download.

The owner asked for 30+ languages for the QURAN TRANSLATION specifically — not
for the app's own UI chrome, which stays on its six locales (ar/en/es/ru/pt/fr).

Source: api.alquran.cloud, the same provider the bundled six translations
already came from and which the app already credits on its Sources screen. Its
`/edition?type=translation` listing offers 118 editions across 48 languages;
this script takes ONE well-established translation per language (47 languages —
the 48th, `ar`, is `quran-buck`, a Buckwalter transliteration rather than a
translation, so it is deliberately excluded).

Why download-on-demand rather than bundling: the six current translations live
in the bundled `quran_sciences.db` and STAY there, so the app is never worse
offline than it is today. The other 41 would add roughly 40 MB of text to an
APK that is already ~239 MB, on a sideloaded app the owner installs over the
wire. Gzipped they are ~250-350 KB each, so fetching just the language a reader
actually picks is effectively instant, and it follows the pattern the books and
hadith DB already use.

Every edition must contain all 6236 ayahs. Korean (`ko.korean`) and Kurdish
(`ku.asan`) were briefly shipped with 6235 — each has exactly one verse left
blank upstream (40:81 and 108:3), reproducibly — but the owner asked for any
language with a gap to be dropped rather than shipped incomplete, so both were
removed. A translation is all of the Qur'an or it is not offered.

Writes:
  * R2   `quran/translations/<lang>.json.gz`
  * repo `rafeeq_app/assets/data/catalogs/quran_translations.json` (the catalog
         the app bundles: language code, native name, translator, byte size)

Usage:  py scripts/r2_upload_quran_translations.py [lang ...] [--force]
        (no args = every language in PICKS)
"""

import gzip
import io
import json
import os
import sys
import threading
import time
import urllib.request
from concurrent.futures import ThreadPoolExecutor

import boto3
from botocore.exceptions import ClientError

# One chosen edition per language, plus the language's own native name for the
# picker. Where the app already bundles a translation (en/es/fr/pt/ru/ur) the
# SAME edition is kept, so a reader who already picked one sees no change.
# Elsewhere the pick is the most widely established translation on offer
# (e.g. Diyanet for Turkish, Bubenheim for German, Ma Jian for Chinese).
PICKS = {
    "am": ("am.sadiq", "አማርኛ", "Sadiq & Sani"),
    "az": ("az.mammadaliyev", "Azərbaycan", "Mammadaliyev & Bunyadov"),
    "ba": ("ba.mehanovic", "Bosanski (Mehanović)", "Mehanović"),
    "ber": ("ber.mensur", "Tamaziɣt", "Mensur"),
    "bg": ("bg.theophanov", "Български", "Tzvetan Theophanov"),
    "bn": ("bn.bengali", "বাংলা", "Muhiuddin Khan"),
    "bs": ("bs.korkut", "Bosanski", "Besim Korkut"),
    "ce": ("ce.magomedov", "Нохчийн", "Magomedov"),
    "cs": ("cs.hrbek", "Čeština", "Ivan Hrbek"),
    "de": ("de.bubenheim", "Deutsch", "Bubenheim & Elyas"),
    "dv": ("dv.divehi", "ދިވެހި", "Office of the President, Maldives"),
    "en": ("en.sahih", "English", "Saheeh International"),
    "es": ("es.cortes", "Español", "Julio Cortés"),
    "fa": ("fa.makarem", "فارسی", "Naser Makarem Shirazi"),
    "fr": ("fr.hamidullah", "Français", "Muhammad Hamidullah"),
    "ha": ("ha.gumi", "Hausa", "Abubakar Mahmoud Gumi"),
    "hi": ("hi.hindi", "हिन्दी", "Suhel Farooq Khan & Saifur Rahman Nadwi"),
    "id": ("id.indonesian", "Bahasa Indonesia", "Kementerian Agama RI"),
    "it": ("it.piccardo", "Italiano", "Hamza Roberto Piccardo"),
    "ja": ("ja.japanese", "日本語", "Ryoichi Mita"),
    "ml": ("ml.abdulhameed", "മലയാളം", "Abdul Hameed & Parappoor"),
    "ms": ("ms.basmeih", "Bahasa Melayu", "Abdullah Muhammad Basmeih"),
    "my": ("my.ghazi", "မြန်မာ", "Ghazi Hashim"),
    "nl": ("nl.siregar", "Nederlands", "Sofian S. Siregar"),
    "no": ("no.berg", "Norsk", "Einar Berg"),
    "pl": ("pl.bielawskiego", "Polski", "Józef Bielawski"),
    "ps": ("ps.abdulwali", "پښتو", "Abdulwali Khan"),
    "pt": ("pt.elhayek", "Português", "Samir El-Hayek"),
    "ro": ("ro.grigore", "Română", "George Grigore"),
    "ru": ("ru.kuliev", "Русский", "Эльмир Кулиев"),
    "sd": ("sd.amroti", "سنڌي", "Taj Mehmood Amroti"),
    "si": ("si.naseemismail", "සිංහල", "Naseem Ismail & Masood Vafy"),
    "so": ("so.abduh", "Soomaali", "Mahmud Muhammad Abduh"),
    "sq": ("sq.nahi", "Shqip", "Hasan Efendi Nahi"),
    "sv": ("sv.bernstrom", "Svenska", "Knut Bernström"),
    "sw": ("sw.barwani", "Kiswahili", "Ali Muhsin Al-Barwani"),
    "ta": ("ta.tamil", "தமிழ்", "Jan Turst Foundation"),
    "tg": ("tg.ayati", "Тоҷикӣ", "AbdolMohammad Ayati"),
    "th": ("th.thai", "ไทย", "King Fahad Quran Complex"),
    "tr": ("tr.diyanet", "Türkçe", "Diyanet İşleri"),
    "tt": ("tt.nugman", "Татарча", "Yakub Ibn Nugman"),
    "ug": ("ug.saleh", "ئۇيغۇرچە", "Muhammad Saleh"),
    "ur": ("ur.jalandhry", "اردو", "Fateh Muhammad Jalandhry"),
    "uz": ("uz.sodik", "Oʻzbekcha", "Muhammad Sodik Muhammad Yusuf"),
    "zh": ("zh.jian", "中文", "Ma Jian"),
}

# The six that ship inside `quran_sciences.db`. Listed in the catalog with
# `bundled: true` so the app knows it needs no download for them.
BUNDLED = {"en", "es", "fr", "pt", "ru", "ur"}

SRC = "https://api.alquran.cloud/v1/quran/{}"
DST_KEY = "quran/translations/{}.json.gz"
TOTAL_AYAHS = 6236
WORKERS = 8
FORCE = "--force" in sys.argv

REPO = r"E:\My Projects\Rafiq-Al-Darb"
CATALOG_PATH = os.path.join(
    REPO, "rafeeq_app", "assets", "data", "catalogs", "quran_translations.json"
)

env = {}
with open(os.path.join(REPO, "scripts", ".env")) as f:
    for line in f:
        line = line.strip()
        if line and not line.startswith("#") and "=" in line:
            k, v = line.split("=", 1)
            env[k] = v

BUCKET = "rafeeq-content"
_local = threading.local()
# lang -> real verse count, filled as each edition is fetched.
_counts = {}


def client():
    if not hasattr(_local, "s3"):
        _local.s3 = boto3.client(
            "s3",
            endpoint_url=env["R2_ENDPOINT"],
            aws_access_key_id=env["R2_ACCESS_KEY_ID"],
            aws_secret_access_key=env["R2_SECRET_ACCESS_KEY"],
            region_name="auto",
        )
    return _local.s3


def fetch_edition(edition):
    """Download one edition and flatten it to {"S:A": text} for all 6236 ayahs.

    Raises if the edition is short — a partial translation must never ship.
    """
    req = urllib.request.Request(
        SRC.format(edition), headers={"User-Agent": "rafeeq-uploader"}
    )
    with urllib.request.urlopen(req, timeout=180) as resp:
        doc = json.loads(resp.read().decode("utf-8"))
    if doc.get("code") != 200:
        raise ValueError(f"api returned {doc.get('code')} {doc.get('status')}")
    out = {}
    for surah in doc["data"]["surahs"]:
        for ayah in surah["ayahs"]:
            text = (ayah.get("text") or "").strip()
            if text:
                out[f"{surah['number']}:{ayah['numberInSurah']}"] = text
    if len(out) != TOTAL_AYAHS:
        raise ValueError(f"incomplete: {len(out)}/{TOTAL_AYAHS} ayahs")
    return out


def upload_lang(lang):
    edition, native, translator = PICKS[lang]
    key = DST_KEY.format(lang)
    c = client()

    if not FORCE:
        try:
            h = c.head_object(Bucket=BUCKET, Key=key)
            return (lang, h["ContentLength"], "skipped")
        except ClientError:
            pass

    last_err = None
    for attempt in range(3):
        try:
            verses = fetch_edition(edition)
            payload = json.dumps(
                {
                    "lang": lang,
                    "edition": edition,
                    "translator": translator,
                    "ayahs": len(verses),
                    "verses": verses,
                },
                ensure_ascii=False,
                separators=(",", ":"),
            ).encode("utf-8")
            buf = io.BytesIO()
            # mtime=0 keeps the bytes deterministic across runs.
            with gzip.GzipFile(fileobj=buf, mode="wb", compresslevel=9, mtime=0) as gz:
                gz.write(payload)
            body = buf.getvalue()
            c.put_object(
                Bucket=BUCKET,
                Key=key,
                Body=body,
                ContentType="application/json",
                ContentEncoding="gzip",
            )
            _counts[lang] = len(verses)
            return (lang, len(body), "uploaded")
        except Exception as e:  # noqa: BLE001
            last_err = e
            time.sleep(2)
    return (lang, 0, f"FAILED: {last_err}")


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    wanted = args or sorted(PICKS)
    bad = [w for w in wanted if w not in PICKS]
    if bad:
        sys.exit(f"unknown language(s): {bad}")

    print(f"=== {len(wanted)} languages -> quran/translations/ ===", flush=True)
    results = {}
    failed = []
    with ThreadPoolExecutor(max_workers=WORKERS) as pool:
        for lang, size, status in pool.map(upload_lang, wanted):
            results[lang] = size
            if status.startswith("FAILED"):
                failed.append(lang)
                print(f"  {lang}: {status}", flush=True)
            else:
                print(f"  {lang}: {size / 1024:.0f} KB ({status})", flush=True)

    # Rebuild the bundled catalog from whatever is genuinely on R2 now, so the
    # app can never list a language whose file failed to upload.
    entries = []
    for lang in sorted(PICKS):
        edition, native, translator = PICKS[lang]
        size = results.get(lang)
        if size is None:
            try:
                size = client().head_object(
                    Bucket=BUCKET, Key=DST_KEY.format(lang)
                )["ContentLength"]
            except ClientError:
                continue
        if not size:
            continue
        entries.append(
            {
                "lang": lang,
                "native_name": native,
                "edition": edition,
                "translator": translator,
                "gz_bytes": size,
                "ayahs": _counts.get(lang, TOTAL_AYAHS),
                "bundled": lang in BUNDLED,
            }
        )

    os.makedirs(os.path.dirname(CATALOG_PATH), exist_ok=True)
    with open(CATALOG_PATH, "w", encoding="utf-8", newline="\n") as f:
        json.dump(
            {
                "version": 1,
                "source": "api.alquran.cloud — one established translation per "
                "language, rehosted first-party on R2",
                "total": len(entries),
                "translations": entries,
            },
            f,
            ensure_ascii=False,
            indent=2,
        )
        f.write("\n")

    total_mb = sum(e["gz_bytes"] for e in entries) / 1048576
    print(
        f"\ncatalog: {len(entries)} languages, {total_mb:.1f} MB total gzipped",
        flush=True,
    )
    print(f"wrote {CATALOG_PATH}", flush=True)
    if failed:
        print(f"INCOMPLETE — failed: {failed}", flush=True)
        sys.exit(1)
    print("DONE", flush=True)


if __name__ == "__main__":
    main()
