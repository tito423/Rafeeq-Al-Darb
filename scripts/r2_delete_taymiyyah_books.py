"""Delete the 61 book objects that left the catalogue on 2026-09-17.

«فيه حوار جامد سالت فيه احد الشيوخ … فاحذفهم كلهم» — the owner asked for
seven names out of the app. Six of them turned out to own nothing in the
library; Ibn Taymiyyah owned 60 of its 248 entries, and Ibn al-Qayyim's
«أسماء مؤلفات شيخ الإسلام ابن تيمية» is an index of those 60, so it went with
them. He was shown the count before deciding.

Order matters and it is the opposite of the intuitive one. The catalogue is
edited and committed FIRST, and only then are the objects deleted — a
half-finished run then leaves files nobody points at, which is invisible,
instead of pointers to files that are gone, which is a book card that opens
onto an error.

Each object is HEAD-checked before and after, exactly as
`r2_delete_duplicate_books.py` does: the run reports the bytes it actually
freed, and a delete that did not take is a failure rather than a message.
"""

import io
import json
import os
import sys

from botocore.exceptions import ClientError

from r2_common import BUCKET, r2_client

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")

IDS_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                        "removed_taymiyyah_ids.json")


def size_of(s3, key):
    try:
        return s3.head_object(Bucket=BUCKET, Key=key)["ContentLength"]
    except ClientError as exc:
        if exc.response["Error"]["Code"] in ("404", "NoSuchKey"):
            return None
        raise


def main():
    ids = json.load(open(IDS_FILE, encoding="utf-8"))
    print("%d ids to delete" % len(ids))

    # Refuse if any of them is still in the catalogue: deleting the bytes out
    # from under a live entry is the failure this ordering exists to avoid.
    cat = open(os.path.join(os.path.dirname(os.path.abspath(__file__)),
                            "..", "rafeeq_app", "lib", "features", "library",
                            "data", "book_catalog.dart"),
               encoding="utf-8").read()
    still = [i for i in ids if "id: '%s'" % i in cat]
    if still:
        sys.exit("REFUSED: still in book_catalog.dart: %s" % still)

    s3 = r2_client()
    freed, gone, failures = 0, 0, []
    for book_id in ids:
        key = "books/text/%s.json" % book_id
        before = size_of(s3, key)
        if before is None:
            print("%-60s absent already" % key)
            continue
        s3.delete_object(Bucket=BUCKET, Key=key)
        after = size_of(s3, key)
        if after is not None:
            failures.append(key)
            print("%-60s STILL THERE (%d bytes)" % (key, after))
            continue
        freed += before
        gone += 1
        print("%-60s deleted %8d bytes" % (key, before))

    print()
    print("deleted %d of %d objects, freed %s bytes"
          % (gone, len(ids), format(freed, ",")))
    if failures:
        print("FAILED:", failures)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
