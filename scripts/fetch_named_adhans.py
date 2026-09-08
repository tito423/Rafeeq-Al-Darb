"""Replace the ten bundled adhans with recordings that are actually attributed.

The problem: `assets/audio/adhan/azan1..10.mp3` came from islamcan.com's
generic numbered files (`azan1.mp3` ... `azan10.mp3`), and a muezzin's name was
assigned to each one WITHOUT any source stating who recites which file. Every
entry in `adhans.json` carried its own admission of this —
"اسم المؤذّن بحاجة إلى تأكيد المطابقة" — and islamcan's own adhan pages now
404, so the attributions can no longer be checked there even in principle.
Naming the wrong reciter over a call to prayer is exactly the kind of quiet
fabrication this project forbids.

The fix: archive.org's `adhan-mp3-collection` holds 230 adhan recordings whose
FILENAMES carry the muezzin, and it has a real recording for each of the ten
the owner asked for — including the three that needed the Haram spellings
(`ali-ibn-ahmad-mala`, `assem-bukhrare`, `muhammad-khaleel-raml`). Each file is
downloaded, checked to be real MP3 audio of a plausible adhan length, and
written over the correspondingly-numbered bundled asset, so the app needs no
code change and every name it displays is one the source actually states.

One deliberate correction: the owner's list said "مصطفى البنا", but the only
al-Banna adhan in the collection is **محمود علي البنا** (Mahmoud Ali al-Banna,
the Egyptian reciter). It is catalogued under his real name rather than
relabelled to match the request — the point of this script is to stop guessing
at attributions, so inventing a different one here would defeat it.

Usage:  py scripts/fetch_named_adhans.py
"""

import io
import urllib.parse
import json
import os
import urllib.request

BASE = "https://archive.org/download/adhan-mp3-collection/{}"
REPO = r"E:\My Projects\Rafiq-Al-Darb"
ASSETS = os.path.join(REPO, "rafeeq_app", "assets", "audio", "adhan")
CATALOG = os.path.join(
    REPO, "rafeeq_app", "assets", "data", "catalogs", "adhans.json"
)
SRC_NOTE = (
    "أرشيف adhan-mp3-collection على archive.org — اسم المؤذّن مذكور في اسم "
    "الملف عند المصدر"
)

# slot id -> (upstream filename, Arabic name shown in the app)
PICKS = [
    ("azan1", "mahmoud-ali-al-banna-cairo.mp3", "محمود علي البنا"),
    ("azan2", "abdulbasit-abdusamad-1-egypt.mp3", "عبد الباسط عبد الصمد"),
    ("azan3", "mohamed-siddiq-el-minshawi-egypt-1.mp3", "محمد صديق المنشاوي"),
    ("azan4", "nasreddine-toubar.mp3", "نصر الدين طوبار"),
    ("azan5", "mishary-rashid-alafasy-1-kuwait.mp3", "مشاري راشد العفاسي"),
    ("azan6", "ali-ibn-ahmad-mala-1-al-haram-al-maki.mp3",
     "علي بن أحمد ملا (الحرم المكي)"),
    ("azan7", "assem-bukhrare-al-haram-al-maki.mp3", "عاصم بخاري (الحرم المكي)"),
    ("azan8", "abdul-majid-al-surehi-1.mp3", "عبد المجيد السريحي"),
    ("azan9", "mansur-al-zahrane-hq.mp3", "منصور الزهراني"),
    ("azan10", "muhammad-khaleel-raml-al-haram-al-maki.mp3",
     "محمد خليل رمل (الحرم المكي)"),
]

MIN_BYTES = 100_000  # an adhan is ~1-3 minutes; anything tiny is an error page


def fetch(filename):
    url = BASE.format(urllib.parse.quote(filename))
    req = urllib.request.Request(url, headers={"User-Agent": "rafeeq-fetch"})
    with urllib.request.urlopen(req, timeout=180) as r:
        data = r.read()
        ctype = r.headers.get("Content-Type", "")
    if "audio" not in ctype and "octet-stream" not in ctype:
        raise ValueError(f"not audio ({ctype})")
    if len(data) < MIN_BYTES:
        raise ValueError(f"too small ({len(data)} bytes)")
    # MP3s start with an ID3 tag or a frame sync; anything else isn't one.
    if not (data[:3] == b"ID3" or (data[0] == 0xFF and data[1] & 0xE0 == 0xE0)):
        raise ValueError("not an MP3 stream")
    return data


def main():
    catalog = []
    for slot, filename, arabic in PICKS:
        data = fetch(filename)
        dest = os.path.join(ASSETS, f"{slot}.mp3")
        with open(dest, "wb") as f:
            f.write(data)
        print(f"  {slot}: {arabic}  <- {filename}  ({len(data) // 1024} KB)",
              flush=True)
        catalog.append(
            {
                "id": slot,
                "name": arabic,
                "asset": f"assets/audio/adhan/{slot}.mp3",
                "raw": slot,
                "url": BASE.format(urllib.parse.quote(filename)),
                "source": SRC_NOTE,
            }
        )

    with io.open(CATALOG, "w", encoding="utf-8", newline="\n") as f:
        json.dump(catalog, f, ensure_ascii=False, indent=2)
        f.write("\n")
    print(f"\nwrote {CATALOG} ({len(catalog)} muezzins, all attributed)")


if __name__ == "__main__":

    main()
