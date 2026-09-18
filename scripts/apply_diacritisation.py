"""Write the measured diacritisation of every book into the Dart catalogue.

The number in the app must be the number `measure_diacritisation.py` actually
measured against the hosted text. Typing it by hand is how a catalogue starts
lying (CLAUDE.md 1.1), so this generates it.

    py -3 scripts/measure_diacritisation.py     # measures, writes the JSON
    py -3 scripts/apply_diacritisation.py       # writes it into the Dart

Adds or updates `diacritisedPct: N,` on every `LibraryBook(` entry, keyed by
its `id:`. Idempotent — running it twice changes nothing the second time.

WHY THE APP NEEDS IT. The spoken reader can only be correct on a book whose
text carries its vowels, and the corpus is bimodal: 80 books are above 80%
and 49 are under 5%. The reader is offered per book on this number, so a
reader is never handed a confident mispronunciation of a religious text.
"""

from __future__ import annotations

import io
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CATALOG = os.path.join(ROOT, "rafeeq_app", "lib", "features", "library",
                       "data", "book_catalog.dart")
MEASURED = os.path.join(ROOT, "_diacritisation.json")


def main() -> int:
    if not os.path.exists(MEASURED):
        print("run measure_diacritisation.py first — %s is missing" % MEASURED)
        return 1
    pct = json.load(io.open(MEASURED, encoding="utf-8"))
    src = io.open(CATALOG, encoding="utf-8").read()

    # Key on the whole `id: 'x',` LINE, comma included, and insert the
    # field on the line after it. The first version of this script matched
    # only up to the quote, which swallowed the comma and produced
    #     id: 'bulugh_al_maram'
    #     diacritisedPct: 39,
    #     diacritisedPct: 39,,
    # — a duplicated field and a syntax error, caught by `flutter analyze`
    # before it went anywhere.
    lines = src.split("\n")
    out_lines = []
    written = 0
    skipped = []
    i = 0
    while i < len(lines):
        line = lines[i]
        out_lines.append(line)
        m = re.match(r"(\s*)id:\s*'([a-z0-9_]+)',\s*$", line)
        if m:
            indent, bid = m.group(1), m.group(2)
            # Drop an existing field so the script is idempotent.
            if i + 1 < len(lines) and re.match(
                    r"\s*diacritisedPct:\s*\d+,\s*$", lines[i + 1]):
                i += 1
            if bid in pct and pct[bid] >= 0:
                out_lines.append("%sdiacritisedPct: %d," % (indent, int(round(pct[bid]))))
                written += 1
            else:
                skipped.append(bid)
        i += 1

    io.open(CATALOG, "w", encoding="utf-8", newline="").write("\n".join(out_lines))

    print("wrote diacritisedPct on %d entries" % written)
    for s in skipped:
        print("  skipped (not measured): %s" % s)
    return 0


if __name__ == "__main__":
    sys.exit(main())
