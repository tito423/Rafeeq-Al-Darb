"""Delete the six book objects that left the catalogue on 2026-09-17.

Three of them were the *same* Shamela book uploaded twice under two ids — the
copies were fetched and compared page by page (411/411, 81/81, 224/224
byte-identical, TOC included) before either was touched, and the id kept is the
one carrying a translated `descKey`.

The other three were al-Albani's takhrij volumes catalogued under the classical
author's name, which is the only reason the v3.29.0 purge left them behind when
it removed every other book of his.

Each object is HEAD-checked first, so the run reports the real byte count it
deleted rather than a claim, and then re-checked: a delete that did not take is
a failure, not a success message.
"""

import io
import sys

from botocore.exceptions import ClientError

from r2_common import BUCKET, r2_client

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")

# (key, why)
TARGETS = [
    (
        "books/text/al_adhkar_lil_nawawi.json",
        "duplicate of al_adhkar_nawawi (Shamela 1956) — 411/411 identical",
    ),
    (
        "books/text/al_arbaun_al_nawawiyyah.json",
        "duplicate of al_arbaun_an_nawawiyyah (Shamela 12836) — 81/81 identical",
    ),
    (
        "books/text/al_tibyan_fi_adab_hamalat_al_quran.json",
        "duplicate of at_tibyan_hamalat_al_quran (Shamela 1969) — 224/224 identical",
    ),
    (
        "books/text/tahqiq_riyad_al_salihin_lil_albani.json",
        "al-Albani's comments on Riyad as-Salihin (Shamela 512), 98 of 639 pages",
    ),
    (
        "books/text/tahqiq_al_iman.json",
        "al-Albani's takhrij of al-Iman (Shamela 264) — none of Ibn Taymiyyah's text",
    ),
    (
        "books/text/takhrij_al_kalim_al_tayyib.json",
        "al-Albani's edition of al-Kalim at-Tayyib (Shamela 327)",
    ),
    # Found after the first six, by opening the library on the emulator.
    (
        "books/text/tahqiq_al_ihtijaj_bil_qadar.json",
        "al-Albani's takhrij of al-Ihtijaj bil-Qadar — 27 of 111 pages, no "
        "title twin in the catalogue, so only reading it found it",
    ),
    (
        "books/text/al_taqrib_wal_taysir.json",
        "duplicate of at_taqrib_wat_taysir (Shamela 5586) — 100/100 identical; "
        "the two entries differed only by the tail «في أصول الحديث»",
    ),
]


def size_of(s3, key):
    try:
        return s3.head_object(Bucket=BUCKET, Key=key)["ContentLength"]
    except ClientError as exc:
        if exc.response["Error"]["Code"] in ("404", "NoSuchKey"):
            return None
        raise


def main():
    s3 = r2_client()
    freed = 0
    failures = []
    for key, why in TARGETS:
        before = size_of(s3, key)
        if before is None:
            print(f"{key:60s} absent already   ({why})")
            continue
        s3.delete_object(Bucket=BUCKET, Key=key)
        after = size_of(s3, key)
        if after is not None:
            failures.append(key)
            print(f"{key:60s} STILL THERE ({after} bytes)")
            continue
        freed += before
        print(f"{key:60s} deleted {before:>8,} bytes   ({why})")
    print()
    print(f"freed {freed:,} bytes across {len(TARGETS)} objects")
    if failures:
        print("FAILED:", failures)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
