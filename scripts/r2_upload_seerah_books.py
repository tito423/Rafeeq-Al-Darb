"""Upload the Seerah-section book texts to R2 and report their real sizes.

`build_book_text.py` already writes each book gzipped (the standing policy —
see `gzip_and_reupload_all_books.py`), and the client sniffs the `1f 8b` magic
bytes rather than trusting a header, so these go up byte-for-byte as they are.

The size this prints is what must go into `book_catalog.dart`'s
`TextEdition.sizeBytes`. It is the size of the object the app actually
downloads — measured with `head_object` after the upload, never estimated.
Every library card once claimed «1.0 MB» because a widget had that string
written into it; this script exists so that cannot happen again.

    py -3 scripts/r2_upload_seerah_books.py <id> [<id> ...]
    py -3 scripts/r2_upload_seerah_books.py            # all listed below
"""

import io
import json
import os
import sys

from r2_common import BUCKET, r2_client

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BUILD = os.path.join(ROOT, "scripts", "book_text_build")

# The twelve the owner asked for, minus al-Shamail (already in the catalogue
# from an earlier session under a different Shamela edition).
IDS = [
    "ar_raheeq_al_makhtum",
    "seerat_ibn_hisham",
    "zad_al_maad",
    "sahih_as_seerah_albani",
    "uyun_al_athar",
    "nur_al_yaqin",
    "as_seerah_nadwi",
    "fiqh_as_seerah_ghazali",
    "as_seerah_ibn_kathir",
    "rijal_hawl_ar_rasul",
    "la_tahzan",
]


def main():
    want = sys.argv[1:] or IDS
    s3 = r2_client()
    results, missing = {}, []

    for book_id in want:
        path = os.path.join(BUILD, book_id + ".json")
        if not os.path.isfile(path):
            missing.append(book_id)
            continue

        with open(path, "rb") as f:
            head = f.read(2)
        if head != b"\x1f\x8b":
            print(f"  !! {book_id} is not gzipped -- refusing to upload")
            missing.append(book_id)
            continue

        local = os.path.getsize(path)
        key = f"books/text/{book_id}.json"
        with open(path, "rb") as f:
            s3.upload_fileobj(
                f, BUCKET, key, ExtraArgs={"ContentType": "application/json"}
            )
        remote = s3.head_object(Bucket=BUCKET, Key=key)["ContentLength"]
        ok = remote == local
        print(f"{book_id:<26} {remote:>9} bytes  {'OK' if ok else 'MISMATCH'}")
        if ok:
            results[book_id] = remote
        else:
            missing.append(book_id)

    out = os.path.join(ROOT, "scripts", "seerah_sizes.json")
    with io.open(out, "w", encoding="utf-8") as f:
        json.dump(results, f, ensure_ascii=False, indent=1)
    print(f"\n{len(results)} uploaded, sizes -> {out}")
    if missing:
        print("NOT uploaded: " + ", ".join(missing))
        sys.exit(1)


if __name__ == "__main__":
    main()
