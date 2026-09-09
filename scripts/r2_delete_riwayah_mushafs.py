"""Delete the Warsh and Qalun page sets from R2.

The owner's instruction was «احذف مصاحف الروايات» — they are riwayat, not
printings, and he wants ten printings. A previous session removed both editions
from `editions.json` but left their page images on the bucket: 1,208 objects,
270 MB, 17% of the bucket, referenced by nothing.

Checked before running: no file under `rafeeq_app/lib`, `assets/data` or
`assets/translations` mentions either edition. The only `warsh` / `qaloon`
matches in the repo are audio reciter identifiers
(`ar.aliabdurrahmanalhuthaifyqaloon`, `omar_warsh`, and `anwarshahat` matching
on a substring), which have nothing to do with these page sets.

Recoverable if ever wanted: both are on archive.org (`Warsh-HD`,
`mushaf-qalun`) and `scripts/build_mushaf_from_pdf.py` rebuilds a page set from
a scan. That is why this is a reasonable thing to do rather than an
irreversible loss.

    py -3 scripts/r2_delete_riwayah_mushafs.py --list     # audit only
    py -3 scripts/r2_delete_riwayah_mushafs.py --delete
"""

import argparse
import io
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from r2_common import BUCKET, r2_client                      # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PREFIXES = ("mushaf/warsh/", "mushaf/qaloon/")


def inventory(s3):
    found = {}
    for prefix in PREFIXES:
        keys = []
        for page in s3.get_paginator("list_objects_v2").paginate(
                Bucket=BUCKET, Prefix=prefix):
            for o in page.get("Contents", []):
                keys.append((o["Key"], o["Size"]))
        found[prefix] = keys
    return found


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--list", action="store_true")
    ap.add_argument("--delete", action="store_true")
    a = ap.parse_args()

    s3 = r2_client()
    found = inventory(s3)
    total = sum(sz for keys in found.values() for _, sz in keys)
    count = sum(len(keys) for keys in found.values())
    for prefix, keys in found.items():
        print("%-18s %4d objects  %7.1f MB"
              % (prefix, len(keys), sum(sz for _, sz in keys) / 1e6))
    print("total: %d objects, %.1f MB" % (count, total / 1e6))

    manifest = os.path.join(ROOT, "scripts", "r2_deleted_riwayah_manifest.json")
    io.open(manifest, "w", encoding="utf-8").write(json.dumps(
        {p: [k for k, _ in keys] for p, keys in found.items()},
        ensure_ascii=False, indent=1))
    print("manifest of exactly what is there -> %s" % manifest)

    if not a.delete:
        print("\nnothing deleted (pass --delete)")
        return

    for prefix, keys in found.items():
        batch = [{"Key": k} for k, _ in keys]
        for i in range(0, len(batch), 1000):
            s3.delete_objects(Bucket=BUCKET,
                              Delete={"Objects": batch[i:i + 1000]})
        print("deleted %d objects under %s" % (len(batch), prefix))

    left = inventory(s3)
    remaining = sum(len(v) for v in left.values())
    print("remaining under those prefixes: %d" % remaining)
    sys.exit(0 if remaining == 0 else 1)


if __name__ == "__main__":
    main()
