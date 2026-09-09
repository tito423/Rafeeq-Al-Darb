# -*- coding: utf-8 -*-
"""Find a Shamela book's last page id by binary search.

The API errors (or returns nothing usable) for a page past the end, which is
the only signal there is — there is no "how many pages" endpoint. Same method
that measured 23,340 for the Arna'ut Musnad.

`curl`, not `urllib`: trap #12 / the seventh session's note — `urllib` took
43 s per request against a host where `curl` took 0.5 s.

    py -3 scripts/shamela_last_page.py <book_id> [<book_id> ...]
"""

import json
import subprocess
import sys

UA = "Mozilla/5.0 (rafeeq-al-darb content pipeline)"


def page_exists(book_id, pid):
    out = subprocess.run(
        ["curl", "-sS", "-A", UA, "-H", "X-Requested-With: XMLHttpRequest",
         "https://shamela.ws/ajax/pageContent/%s/%s" % (book_id, pid)],
        capture_output=True)
    if out.returncode != 0 or not out.stdout:
        return False
    try:
        doc = json.loads(out.stdout.decode("utf-8", "replace"))
    except Exception:                                          # noqa: BLE001
        return False
    # The page body is `nass`, read off a real response rather than
    # guessed at (CLAUDE.md §1.4). `content`/`body` do not exist.
    return bool(str(doc.get("nass") or "").strip())


def last_page(book_id):
    if not page_exists(book_id, 1):
        return 0
    # Grow until a miss, then bisect. Doubling keeps the probe count at
    # ~2*log2(n) rather than walking a 4,000-page book.
    lo, hi = 1, 2
    while page_exists(book_id, hi):
        lo, hi = hi, hi * 2
        if hi > 1 << 20:
            break
    while lo + 1 < hi:
        mid = (lo + hi) // 2
        if page_exists(book_id, mid):
            lo = mid
        else:
            hi = mid
    return lo


def main():
    for book_id in sys.argv[1:]:
        print("%s: %d pages" % (book_id, last_page(book_id)))


if __name__ == "__main__":
    main()
