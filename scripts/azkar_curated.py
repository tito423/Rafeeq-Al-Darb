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
import re
import sys

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")


def digest(s):
    return hashlib.sha256(s.encode("utf-8")).hexdigest()[:12]


def slice_span(text, frm, to, what):
    # Both anchors the same phrase means «this phrase, and nothing else» — a
    # takhrij that is just a book's name. Without this, a phrase that occurs
    # TWICE in the narration made the slice swallow everything between the two
    # occurrences: «صحيح مسلم» appears at the head of hadith ٣٨٨ and again near
    # its end, and the takhrij line came back as the whole hadith.
    if frm == to:
        a = text.find(frm)
        if a < 0:
            raise ValueError("%s: phrase not found: %r" % (what, frm))
        return text[a:a + len(frm)].strip()
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


def unquote(t):
    """Drop the edition's ASCII quote marks - Shamela's typesetting around a
    book title or a quoted saying, never a word of the text - and the spacing
    they leave: «صحيح مسلم " و " موطأ» -> «صحيح مسلم وموطأ», «التقوى "، قال»
    -> «التقوى، قال». Applied AFTER the sha, so the pointer check still runs
    on the source exactly as cut."""
    t = " ".join(t.replace('"', " ").split())
    t = re.sub(r" ([،,.:؛])", r"\1", t)
    return re.sub(r"(^| )و (?=\S)", r"\1و", t)


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
                # «وروينا فيه»: an-Nawawi names the book once and then says
                # «in it» for the next item. `ref_item` points the source line
                # at the item that names it, still cut verbatim.
                ref_it = s["items"][e.get("ref_item", e["item"])]
                note = slice_span(ref_it["text"], e["ref_from"], e["ref_to"],
                                  where + " [ref]")
                # The edition's ASCII quote marks around a book title are its
                # typography, not an-Nawawi's words, and a cut through them
                # left one dangling («سنن أبي داود " بإسناد»). Dropped from the
                # SOURCE LINE only; the dhikr's own text is never touched.
                note = unquote(note)
            except ValueError as exc:
                errors.append(str(exc))
                continue
        # an-Nawawi keeps morning and evening in ONE bab, «باب ما يُقال عند
        # الصباح وعند المساء». The owner asked on 2026-09-17 for two lists, so
        # an entry may say WHEN it is said and the chapter splits in two. A
        # «both» entry lands in both, because the narration itself says «حين
        # يصبح وحين يمسي» — that is the book instructing, not a duplication we
        # invented. The half-titles are his own words, cut at his own «و».
        when = e.get("when")
        variants = (["morning", "evening"] if when == "both"
                    else [when] if when else [None])
        for variant in variants:
            key = (e["section"], variant)
            if key not in sections:
                title = s["title"]
                if variant == "morning":
                    title = "بابُ ما يُقال عند الصَّباحِ"
                elif variant == "evening":
                    title = "بابُ ما يُقال عندَ المساءِ"
                sections[key] = {"title": title, "page": s["page"],
                                 "variant": variant, "items": []}
                order.append(key)
            sections[key]["items"].append(
                {"body": unquote(body), "footnote": note, "page": it["page"],
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
