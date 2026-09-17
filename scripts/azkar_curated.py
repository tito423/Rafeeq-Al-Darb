"""Turn the hand-picked pointers into the rows the app's azkar tables hold.

Reads `_azkar_adhkar.json` (the extractor's output) and `azkar_curated.json`
(the pointers), slices each supplication out of an-Nawawi's own text, and
writes the sections and items.

Nothing here retypes Arabic. A pointer names a section, an item and two short
phrases; the phrases locate the span and the SOURCE supplies the characters.
`--freeze` stamps each entry with the sha of what it produced, and every later
run checks it — so if the book is ever re-fetched and a paragraph shifts, the
build stops instead of quietly shipping a different dua under the same title.
"""

import argparse
import hashlib
import io
import json
import sys

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")


def digest(s):
    return hashlib.sha256(s.encode("utf-8")).hexdigest()[:12]


def slice_span(text, frm, to, what):
    a = text.find(frm)
    if a < 0:
        raise ValueError("%s: opening phrase not found: %r" % (what, frm))
    b = text.find(to, a + len(frm))
    if b < 0:
        # A one-word span whose end is inside the opening phrase is legitimate
        # («أبْلِي» … «وأخْلِقِي» are adjacent), so try from the start too.
        b = text.find(to, a)
        if b < 0:
            raise ValueError("%s: closing phrase not found: %r" % (what, to))
    return text[a:b + len(to)].strip()


def build(cut, cur):
    sections, order = {}, []
    errors = []
    for n, e in enumerate(cur["entries"]):
        s = cut["sections"][e["section"]]
        it = s["items"][e["item"]]
        where = "entry %d (section %d «%s», item %d)" % (
            n, e["section"], s["title"], e["item"])
        try:
            body = slice_span(it["text"], e["from"], e["to"], where)
        except ValueError as exc:
            errors.append(str(exc))
            continue
        if "sha" in e and digest(body) != e["sha"]:
            errors.append("%s: sha changed — the source moved under this "
                          "pointer. Expected %s, got %s: %s"
                          % (where, e["sha"], digest(body), body[:80]))
            continue
        e["sha"] = digest(body)
        note = ""
        if e.get("ref_from"):
            try:
                note = slice_span(it["text"], e["ref_from"], e["ref_to"],
                                  where + " [ref]")
            except ValueError as exc:
                errors.append(str(exc))
                continue
        key = e["section"]
        if key not in sections:
            sections[key] = {"title": s["title"], "page": s["page"], "items": []}
            order.append(key)
        sections[key]["items"].append(
            {"body": body, "footnote": note, "page": it["page"],
             "no": it["no"], "sha": e["sha"]})
    return [sections[k] for k in order], errors


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--cut", default="_azkar_adhkar.json")
    ap.add_argument("--curated", default="azkar_curated.json")
    ap.add_argument("--out", default="_azkar_curated_out.json")
    ap.add_argument("--report", default="_azkar_curated_report.txt")
    ap.add_argument("--freeze", action="store_true",
                    help="write the computed shas back into the curation file")
    args = ap.parse_args()

    cut = json.load(open(args.cut, encoding="utf-8"))
    cur = json.load(open(args.curated, encoding="utf-8"))
    sections, errors = build(cut, cur)

    with io.open(args.report, "w", encoding="utf-8") as r:
        r.write("sections: %d   items: %d   errors: %d\n"
                % (len(sections), sum(len(s["items"]) for s in sections),
                   len(errors)))
        for e in errors:
            r.write("  ERROR  %s\n" % e)
        for s in sections:
            r.write("\n======== «%s»  (p%s) ========\n" % (s["title"], s["page"]))
            for it in s["items"]:
                r.write("  [%s p%s] %s\n" % (it["no"], it["page"], it["body"]))
                if it["footnote"]:
                    r.write("        ← %s\n" % it["footnote"])

    json.dump({"sections": sections}, io.open(args.out, "w", encoding="utf-8"),
              ensure_ascii=False, indent=1)
    if args.freeze and not errors:
        json.dump(cur, io.open(args.curated, "w", encoding="utf-8"),
                  ensure_ascii=False, indent=1)
        print("shas frozen into", args.curated)

    print("sections %d, items %d, errors %d -> %s"
          % (len(sections), sum(len(s["items"]) for s in sections),
             len(errors), args.report))
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
