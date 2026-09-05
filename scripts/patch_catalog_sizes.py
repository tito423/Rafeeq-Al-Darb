"""P3-44 follow-up: after gzip-compressing every book text edition on R2
(gzip_and_reupload_all_books.py), the catalog's `approxSizeBytes` for
each `textEdition` still says the old, larger, uncompressed size — that
number is shown to the reader *before* downloading, so it must reflect
what actually gets downloaded now. Patches every `fileName: '<slug>_
text.json'` block's very next `approxSizeBytes: N` to the real
compressed size — never touches a book's separate *image*-PDF
`approxSizeBytes` (a different field entirely, matched by a different
`fileName`), so this can't accidentally end up sizing a scanned PDF like
a text file.
"""

import json
import re

CATALOG = r"rafeeq_app/lib/features/library/data/book_catalog.dart"
SIZES = r"scripts/compressed_sizes.jsonl"

sizes = {}
with open(SIZES, encoding="utf-8") as f:
    for line in f:
        d = json.loads(line)
        sizes[d["slug"]] = d["after"]

with open(CATALOG, encoding="utf-8") as f:
    content = f.read()

pattern = re.compile(
    # `dart format` wraps `fileName:` onto its own line when the slug is
    # long enough (found the hard way: exactly one real entry,
    # al_furqan_bayn_awliya_al_rahman_wa_awliya_al_shaytan, silently kept
    # its old uncompressed size because the original pattern assumed
    # `fileName: '...'` always fits on one line) — `\s*` between the
    # colon and the quote tolerates both layouts.
    r"(fileName:\s*'(\w+)_text\.json',\s*\n\s*approxSizeBytes: )(\d+)(,)"
)

missing = []


def repl(m):
    slug = m.group(2)
    if slug not in sizes:
        missing.append(slug)
        return m.group(0)
    return f"{m.group(1)}{sizes[slug]}{m.group(4)}"


new_content, n = pattern.subn(repl, content)
with open(CATALOG, "w", encoding="utf-8") as f:
    f.write(new_content)

print(f"patched {n} approxSizeBytes fields")
if missing:
    print("no compressed size found for:", missing)
