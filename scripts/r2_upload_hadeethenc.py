# -*- coding: utf-8 -*-
"""Upload the per-language HadeethEnc packs to R2 and verify each one lands.

Uploads `dist/hadeethenc/<lang>.zip` (built by `build_hadeethenc_packs.py`) to
`hadeethenc/<lang>.zip`, then reads the first bytes of each object back over
the public endpoint and refuses to write the catalogue unless every one
answers with a real zip.

CLAUDE.md §1.1: nothing goes in a catalogue before its content resolves on the
public endpoint. Eight mushaf editions and eleven books were catalogued from
uploads that were never checked from the outside, and both shipped broken.
The check here is a range request that must return the two magic bytes `PK`,
not merely an HTTP 200 — trap #5, `android.quran.com` answers 200 with its
homepage for a missing folder.

The public endpoint 403s a bare `urllib` request (trap #19), so the read-back
uses `curl`, which sends a User-Agent of its own.

Writes `rafeeq_app/assets/data/catalogs/hadeethenc.json` — the catalogue the
app bundles: language, native name, hadith count, category count, and the
**measured** byte size of the object on the bucket.

    py -3 scripts/r2_upload_hadeethenc.py [lang ...]
"""

import io
import json
import os
import subprocess
import sys

from r2_common import BUCKET, r2_client

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DIST = os.path.join(ROOT, "dist", "hadeethenc")
PACKS = os.path.join(ROOT, "hadeethenc_packs.json")
CATALOG = os.path.join(ROOT, "rafeeq_app", "assets", "data", "catalogs",
                       "hadeethenc.json")
PUBLIC = "https://pub-39dbef68a1a845d5ba669b43a59516b9.r2.dev"

# The name a reader of that language reads. Same list, same spellings, as the
# language picker in `settings_screen.dart`.
NATIVE = {
    "ar": "العربية",
    "en": "English",
    "es": "Español",
    "fr": "Français",
    "pt": "Português",
    "ru": "Русский",
    "ur": "اردو",
}


def head_bytes(url, n=2):
    out = subprocess.run(
        ["curl", "-sS", "--fail", "-r", "0-%d" % (n - 1), url],
        capture_output=True)
    if out.returncode != 0:
        return None
    return out.stdout


def remote_size(url):
    out = subprocess.run(
        ["curl", "-sSI", "--fail", url], capture_output=True)
    if out.returncode != 0:
        return None
    for line in out.stdout.decode("utf-8", "replace").splitlines():
        if line.lower().startswith("content-length:"):
            return int(line.split(":", 1)[1].strip())
    return None


def main():
    built = {r["lang"]: r for r in json.load(io.open(PACKS, encoding="utf-8"))}
    wanted = [a for a in sys.argv[1:] if not a.startswith("-")] or \
        sorted(built, key=lambda l: list(NATIVE).index(l))

    s3 = r2_client()
    failures = []
    entries = []

    for lang in wanted:
        path = os.path.join(DIST, "%s.zip" % lang)
        key = "hadeethenc/%s.zip" % lang
        local = os.path.getsize(path)
        with open(path, "rb") as f:
            s3.put_object(Bucket=BUCKET, Key=key, Body=f.read(),
                          ContentType="application/zip")

        url = "%s/%s" % (PUBLIC, key)
        magic = head_bytes(url)
        size = remote_size(url)
        ok = magic == b"PK" and size == local
        print("%-3s %-28s %9d bytes  magic=%r  remote=%s  %s"
              % (lang, key, local, magic, size, "OK" if ok else "FAILED"))
        if not ok:
            failures.append(lang)
            continue

        b = built[lang]
        entries.append({
            "lang": lang,
            "name": NATIVE[lang],
            "hadeeths": b["hadeeths"],
            "categories": b["categories"],
            "bytes": size,
            "db_bytes": b["db_bytes"],
        })

    if failures:
        sys.exit("NOT writing the catalogue: %s failed to verify"
                 % ", ".join(failures))

    os.makedirs(os.path.dirname(CATALOG), exist_ok=True)
    with io.open(CATALOG, "w", encoding="utf-8", newline="\n") as f:
        json.dump({
            "source": {
                "title_ar": "موسوعة الأحاديث النبوية",
                "title_en": "Hadeeth Encyclopedia",
                "url": "https://hadeethenc.com",
            },
            "languages": entries,
        }, f, ensure_ascii=False, indent=2)
        f.write("\n")
    print("wrote %s (%d languages)" % (CATALOG, len(entries)))


if __name__ == "__main__":
    main()
