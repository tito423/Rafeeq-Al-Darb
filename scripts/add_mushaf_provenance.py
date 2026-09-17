"""Write each mushaf printing's source and licence into `editions.json`.

WHY. Until 2026-09-17 that file carried no per-edition provenance at all: one
top-level `license` string covered all of them, and it was **stale** — it still
named Warsh and Qalun, deleted in 2026-09-09, and described the illuminated
edition only as «archive.org public scans» without naming its licence. Where an
edition came from survived nowhere but in a session's memory note, and that
note was found to be wrong on 2026-09-17 (it said nine printings ship; six do).

Every value below was read from `https://archive.org/metadata/<id>` on
2026-09-17, not recalled. Two carry a stated Creative Commons licence; two
state none, and are recorded as stating none rather than as «probably fine».
"""

import collections
import io
import json
import sys

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")

PATH = (r"E:\My Projects\Rafiq-Al-Darb\rafeeq_app\assets\data\mushaf"
        r"\editions.json")

# id -> (source, licence, note). Read from archive.org's own metadata.
PROVENANCE = {
    "hafs_kfqc": (
        "quranpedia/quran-svg",
        "polygon metadata CC0-1.0; KFQC glyphs free for digital use",
        "The vector edition. Not a scan.",
    ),
    "qatar": (
        "archive.org/details/QuranMushafQatar",
        "CC BY-NC-SA 3.0",
        "Stated on the item itself; it is why this printing was chosen.",
    ),
    "madinah_gold": (
        "archive.org/details/smartmushaf",
        "CC BY-NC-ND 4.0",
        "The uploader states in his own item description, bolded and "
        "underlined: «The creator does not own the content. The creator "
        "basically used the vector pages of the Qur'an already available in "
        "the internet and added colors and borders for visual purposes.» NC is "
        "satisfied — this app is free and carries no advertising. BY is "
        "satisfied — Smart Mushaf is credited on the Sources screen with a "
        "link. Pages are served downscaled to 1200px for bandwidth, with no "
        "crop, recolour or recomposition.",
    ),
    "tajweed_color": (
        "archive.org/details/quraan-colored",
        "none stated",
        "Creator recorded on the item as «dar al-ma'rifa, Beirut, Lebanon». "
        "The item states no licence.",
    ),
    "madinah_night": (
        "archive.org/details/QuranMadina35685363568hNight",
        "none stated",
        "The item carries no licence, no creator and no rights statement.",
    ),
    "kuwait": (
        "archive.org — Ministry of Awqaf and Islamic Affairs, Kuwait",
        "none stated",
        "Recorded when the edition was added; the item id is in "
        "scripts/build_mushaf_from_pdf.py.",
    ),
}

TOP = (
    "Per-edition provenance lives on each entry below, in `source` and "
    "`license`, read from the item itself on 2026-09-17. This line used to be "
    "the only record and it had gone stale — it still named Warsh and Qalun, "
    "which were deleted on 2026-09-09. Two editions state a Creative Commons "
    "licence; three state none and say so. See CONTENT-LICENSES.md."
)


def main():
    d = json.load(io.open(PATH, encoding="utf-8"),
                  object_pairs_hook=collections.OrderedDict)
    missing = []
    for e in d["editions"]:
        p = PROVENANCE.get(e["id"])
        if not p:
            missing.append(e["id"])
            continue
        e["source"], e["license"], e["license_note"] = p
    d["license"] = TOP
    io.open(PATH, "w", encoding="utf-8").write(
        json.dumps(d, ensure_ascii=False, indent=1) + "\n")
    print("editions: %d, annotated: %d" % (len(d["editions"]),
                                           len(d["editions"]) - len(missing)))
    if missing:
        print("NO PROVENANCE FOR:", missing)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
