"""Show one of an-Nawawi's abwab with every quotable span numbered.

This is the reading tool for the hand-curation the owner asked for
(2026-09-17): «انتقي أنا بالإيد». An automatic dua extractor was built first
and rejected, because al-Adhkar's quotation marks are not a boundary — «٣٧ -
وروينا في " صحيح البخاري " عن حذيفةَ …» puts the BOOK's name in quotes and part
of the supplication outside them. So a human reads the bab and picks the span.

What this prints, per narration, is every run of text an-Nawawi set inside
quotation marks, each with the character offsets it occupies in the item. The
curation file records those offsets, never the Arabic itself — the text is
sliced out of the extractor's own output at build time, which is how the quotes
corpus avoided losing a diacritic in transcription, and a checksum makes a
silent drift impossible.

    py -3 azkar_pick.py --section 1
    py -3 azkar_pick.py --find "استيقظ"
"""

import argparse
import hashlib
import io
import json
import re
import sys

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")

CUT = "_azkar_adhkar.json"
# an-Nawawi's editions use both «" … "» and «( … )» for quoted speech; the
# Shamela build of this printing uses the straight double quote almost
# everywhere and parentheses in the early abwab.
SPANS = re.compile(r'"([^"]{8,})"|\(([^)]{8,})\)')


def digest(s):
    return hashlib.sha256(s.encode("utf-8")).hexdigest()[:12]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--cut", default=CUT)
    ap.add_argument("--section", type=int)
    ap.add_argument("--find")
    ap.add_argument("--out")
    ap.add_argument("--item", type=int,
                    help="with --from/--to: resolve a span to offsets")
    ap.add_argument("--from", dest="frm",
                    help="a short phrase where the dua STARTS, as printed")
    ap.add_argument("--to",
                    help="a short phrase where the dua ENDS, as printed")
    args = ap.parse_args()

    doc = json.load(open(args.cut, encoding="utf-8"))
    secs = doc["sections"]

    if args.find:
        for i, s in enumerate(secs):
            if args.find in s["title"]:
                print("%3d  p%-5s %2d items  %s"
                      % (i, s["page"], len(s["items"]), s["title"]))
        return

    s = secs[args.section]

    if args.item is not None and args.frm and args.to:
        # The two phrases are a READING aid and are never shipped: they only
        # locate the span, and the text that ends up in the database is sliced
        # out of the extractor's own output. A phrase that does not match is a
        # loud failure, which is the point — it cannot half-match and ship a
        # clipped supplication.
        t = s["items"][args.item]["text"]
        a = t.find(args.frm)
        b = t.find(args.to, a + len(args.frm) if a >= 0 else 0)
        if a < 0:
            print("FROM not found in item %d" % args.item)
            return
        if b < 0:
            print("TO not found after FROM in item %d" % args.item)
            return
        b += len(args.to)
        print('    {"section": %d, "item": %d, "span": [%d, %d], "sha": "%s"},'
              % (args.section, args.item, a, b, digest(t[a:b])))
        print("    // %s" % t[a:b])
        return

    out = io.open(args.out, "w", encoding="utf-8") if args.out else sys.stdout
    out.write("SECTION %d  p%s  «%s»\n" % (args.section, s["page"], s["title"]))
    out.write("=" * 78 + "\n")
    for j, it in enumerate(s["items"]):
        out.write("\n-- item %d  (no=%s, p%s, %d chars)\n"
                  % (j, it["no"], it["page"], len(it["text"])))
        out.write("   FULL: %s\n" % it["text"])
        for m in SPANS.finditer(it["text"]):
            g = m.group(1) if m.group(1) is not None else m.group(2)
            a = m.start(1) if m.group(1) is not None else m.start(2)
            out.write("   span [%4d,%4d] sha=%s  %s\n"
                      % (a, a + len(g), digest(g), g))
    if args.out:
        out.close()


if __name__ == "__main__":
    main()
