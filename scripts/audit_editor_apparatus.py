"""How much of a modern muhaqqiq's own work is inside the books we host?

WHY THIS IS THE QUESTION THAT MATTERS
-------------------------------------
Checked on 2026-09-17 by reading shamela.ws itself: it publishes **no
robots.txt** (404), **no terms of service, no rights page and no licence page**
(all 404), and its «حول المشروع» says the project «لا يتلقى مقابل من المؤلفين
نظير نشر كتبهم» — it does not claim to have acquired anyone's rights, and it
grants none to anybody else. So «the book is on Shamela» settles nothing about
redistribution, which is what this app does when it rehosts a text on its own
bucket and ships it in an APK.

What the app actually redistributes is a stream of paragraphs. an-Nawawi's
words are free; nothing anybody does to a 676 AH text makes it theirs. What
*is* a modern editor's own protected work is his apparatus: the footnotes, the
takhrij, the introduction, the isnad criticism, the indexes.

So the measurable question — and the only one that changes the risk — is:
**do the files we host contain the editor's apparatus, or only the author's
text?** al-Adhkar was proved to contain it (عبد القادر الأرنؤوط's footnotes ride
in the ordinary body stream). Nobody has ever asked it of the other 248.

This asks it of every book, from OUR bucket, so Shamela is not touched at all.

WHAT IT MEASURES, per book
--------------------------
  * whether the book's own editionCard names a muhaqqiq, and his death year
  * how many paragraphs carry the apparatus signature, and what share of the
    book's characters they are

The signature is the one the azkar extractor had to learn the hard way: the
decisive mark is a paragraph CLOSING with «(*)», not one opening with «(١)» —
requiring the opening let a footnote through that began with «=», the
continuation marker, carrying 750 words of isnad criticism.

Nothing is deleted or changed here. This only counts and reports.
"""

import argparse
import concurrent.futures
import gzip
import io
import json
import re
import sys
import urllib.request

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")

BASE = "https://pub-39dbef68a1a845d5ba669b43a59516b9.r2.dev"
# R2's public endpoint answers a bare urllib request with 403 (trap #19).
UA = "RafeeqAlDarb/3.30 (https://github.com/tito423/Rafeeq-Al-Darb) curl/8"
CATALOG = (r"E:\My Projects\Rafiq-Al-Darb\rafeeq_app\lib\features\library"
           r"\data\book_catalog.dart")

AR = "٠١٢٣٤٥٦٧٨٩"
FOOT_OPEN = re.compile(r"^\(\s*[" + AR + r"]+\s*\)")
FOOT_TAIL = re.compile(r"رواه .{0,40}رقم \(|في المسند \d|/ \d+ من حديث")
EDITOR_VOICE = re.compile(
    r"يعني النووي|يعني المصنف|قال المحقق|قال المحققون|تحفة الأبرار|"
    r"المصنف رحمه الله|قال معد الكتاب|قلت \(المحقق\)"
)
# A card line is «<label>: <value>». The label names an editor when it
# contains one of these roots. Built from a scan of every built book's card
# (scratchpad/scan_edition_cards.py), which found 36 distinct labels in use —
# «تعليق وتحقيق», «حققه وخرج أحاديثه», «دراسة وتحقيق», «قدم له وحققه وعلق
# عليه», «جمعه ورتبه ووثق نصوصه وحققه» — where the old fixed alternation knew
# eleven. «جامع العلوم والحكم» credits a LIVING editor under «تعليق وتحقيق:»
# and was read as having no editor at all.
#
# None of the non-editor labels a card uses — الكتاب، المؤلف، الناشر، الطبعة،
# عدد الصفحات، عدد الأجزاء، الموضوع — contains any of these.
EDITOR_ROOTS = (
    "تحقيق", "المحقق", "حقق", "تعليق", "علق", "دراسة", "درسها",
    "ضبط", "خرج", "اعتنى", "عني", "عُنِيَ", "راجع", "قدم", "تقديم",
    "شرح", "إخراج", "أشرف", "جمعه", "رتبه", "فهرسه", "تعليقات",
)
CARD_LINE = re.compile(r"^\s*([^:]{1,60}?)\s*:\s*(.+)$")


def is_editor_label(label):
    return any(root in label for root in EDITOR_ROOTS)
DEATH = re.compile(r"\[\s*ت\s*([" + AR + r"0-9]+)\s*هـ?\s*\]")
AR2EN = str.maketrans(AR, "0123456789")

# Hijri 1396 ≈ 1976 CE, i.e. 50 years before today under the rule this project
# works to (author's death + 50). An editor who died at or after it is modern.
MODERN_FROM = 1396


def fetch(path):
    req = urllib.request.Request(BASE + path, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=180) as r:
        raw = r.read()
    if raw[:2] == b"\x1f\x8b":       # gzip with no Content-Encoding (trap #6)
        raw = gzip.decompress(raw)
    return json.loads(raw.decode("utf-8"))


def apparatus(doc):
    """(paragraphs, apparatus paragraphs, chars, apparatus chars, samples)"""
    n = na = c = ca = 0
    samples = []
    for page in doc.get("pages", []):
        for para in page.get("paras", []):
            t = (para.get("t") or "").strip()
            if not t:
                continue
            n += 1
            c += len(t)
            hit = None
            if "(*)" in t:
                hit = "(*)"
            elif t.startswith("="):
                hit = "="
            elif FOOT_OPEN.match(t) and FOOT_TAIL.search(t):
                hit = "(N)+takhrij"
            elif EDITOR_VOICE.search(t):
                hit = "editor voice"
            if hit:
                na += 1
                ca += len(t)
                if len(samples) < 2:
                    samples.append("[%s p%s] %s" % (hit, page.get("p"), t[:160]))
    return n, na, c, ca, samples


def editor_of(card):
    lines, years = [], []
    for line in (card or "").split("\n"):
        m = CARD_LINE.match(line.strip())
        if m and is_editor_label(m.group(1)):
            lines.append(line.strip())
            years += [int(d.translate(AR2EN)) for d in DEATH.findall(line)]
    return lines, (max(years) if years else None)


def one(item):
    path, bid = item
    try:
        doc = fetch(path)
    except Exception as exc:                       # noqa: BLE001 - reported
        return {"id": bid, "error": str(exc)[:80]}
    card = (doc.get("meta") or {}).get("editionCard", "")
    lines, year = editor_of(card)
    n, na, c, ca, samples = apparatus(doc)
    return {"id": bid, "editor_lines": lines, "editor_year": year,
            "paras": n, "app_paras": na, "chars": c, "app_chars": ca,
            "samples": samples,
            "title": (doc.get("meta") or {}).get("titleAr", "")}


def verdict(r):
    """What this book is, on the evidence — never a legal conclusion."""
    if r.get("error"):
        return "UNREACHABLE"
    if not r["editor_lines"]:
        # Apparatus FIRST. This used to return NO_EDITOR_NAMED here, so a book
        # whose editor the card did not name in a form the regex knew, and
        # which carries apparatus anyway, landed in the one bucket nobody
        # re-reads. al-Adhkar is precisely that book: the apparatus rode in
        # the body stream and the edition card was not what gave it away.
        if r["app_paras"]:
            return "APPARATUS_BUT_NO_EDITOR_NAMED"
        return "NO_EDITOR_NAMED"
    if r["editor_year"] and r["editor_year"] < MODERN_FROM:
        return "EDITOR_LONG_DEAD"
    if r["app_paras"] == 0:
        return "MODERN_EDITOR_NO_APPARATUS"
    return "MODERN_EDITOR_APPARATUS_PRESENT"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--report", default="_editor_apparatus_report.txt")
    ap.add_argument("--json", default="_editor_apparatus.json")
    ap.add_argument("--workers", type=int, default=8)
    args = ap.parse_args()

    src = open(CATALOG, encoding="utf-8").read()
    books = re.findall(r"contentBaseUrl\}(/books/text/([A-Za-z0-9_]+)\.json)", src)
    print("catalogued books:", len(books))

    with concurrent.futures.ThreadPoolExecutor(max_workers=args.workers) as ex:
        rows = list(ex.map(one, books))
    for r in rows:
        r["verdict"] = verdict(r)

    buckets = {}
    for r in rows:
        buckets.setdefault(r["verdict"], []).append(r)

    with io.open(args.report, "w", encoding="utf-8") as f:
        f.write("books audited: %d   (fetched from this project's own bucket, "
                "not from shamela.ws)\n\n" % len(rows))
        f.write("shamela.ws on 2026-09-17: robots.txt 404, /page/terms 404, "
                "/page/rights 404, /page/license 404.\n")
        f.write("Its «حول المشروع» states it is free and non-profit and «لا "
                "يتلقى مقابل من المؤلفين نظير نشر كتبهم».\n")
        f.write("So it states no prohibition on reading, and grants no "
                "permission to redistribute. Neither fact is a legal opinion; "
                "both are what the site says today.\n\n")
        for name in ("MODERN_EDITOR_APPARATUS_PRESENT",
                     "APPARATUS_BUT_NO_EDITOR_NAMED",
                     "MODERN_EDITOR_NO_APPARATUS",
                     "EDITOR_LONG_DEAD", "NO_EDITOR_NAMED", "UNREACHABLE"):
            group = buckets.get(name, [])
            f.write("%-34s %3d\n" % (name, len(group)))
        f.write("\n" + "=" * 78 + "\n")
        for name in ("MODERN_EDITOR_APPARATUS_PRESENT",
                     "APPARATUS_BUT_NO_EDITOR_NAMED",
                     "MODERN_EDITOR_NO_APPARATUS",
                     "EDITOR_LONG_DEAD", "NO_EDITOR_NAMED", "UNREACHABLE"):
            group = buckets.get(name, [])
            if not group:
                continue
            f.write("\n\n######## %s — %d books ########\n" % (name, len(group)))
            group.sort(key=lambda r: -(r.get("app_chars") or 0))
            for r in group:
                if r.get("error"):
                    f.write("  %-46s ERROR %s\n" % (r["id"], r["error"]))
                    continue
                pct = 100.0 * r["app_chars"] / r["chars"] if r["chars"] else 0
                f.write("\n  %-46s %5d/%-5d paras are apparatus  (%5.1f%% of "
                        "the text)\n" % (r["id"], r["app_paras"], r["paras"], pct))
                f.write("      «%s»\n" % r["title"])
                for line in r["editor_lines"]:
                    f.write("      %s\n" % line)
                for s in r["samples"]:
                    f.write("      → %s\n" % s)

    json.dump(rows, io.open(args.json, "w", encoding="utf-8"),
              ensure_ascii=False, indent=1)
    for name in ("MODERN_EDITOR_APPARATUS_PRESENT", "MODERN_EDITOR_NO_APPARATUS",
                 "EDITOR_LONG_DEAD", "NO_EDITOR_NAMED", "UNREACHABLE"):
        print("%-34s %3d" % (name, len(buckets.get(name, []))))
    print("->", args.report)


if __name__ == "__main__":
    main()
