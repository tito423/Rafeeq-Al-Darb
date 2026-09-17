"""Rebuild `azkar_sections` and `azkar_items` from an-Nawawi's al-Adhkar.

WHY. The azkar feature was built on «حصن المسلم» by سعيد بن علي بن وهف القحطاني
(d. 1439 AH / 2018) — his name is inside the bundled database itself, in
`azkar_items` row 2's footnote. The supplications are prophetic and free; the
SELECTION, the arrangement, the chapter titles and the takhrij are his.

UAE Federal Decree-Law 38/2021 names this case in so many words. Article 3
excludes a public-domain work from protection, and the sentence immediately
after it says: «ومع ذلك تتمتع مجموعات ما ورد في البنود (2)، (3)، (4) من هذه
المادة بالحماية إذا تميز جمعها أو ترتيبها أو أي مجهود فيها بالابتكار». A
collection of free duas is protected when its gathering is innovative. That is
حصن المسلم exactly.

WHAT REPLACES IT. an-Nawawi (d. 676 AH), «الأذكار», hand-picked by the owner's
instruction («انتقي أنا بالإيد») after an automatic extractor was built and
rejected — al-Adhkar's quotation marks are not a dua boundary, so a machine
would have shipped a book title as a supplication.

IDS. `azkar_items.id` is explicit, never auto-assigned, because
`ruqyah_catalog.dart` addresses five rows by id. 1001–1005 are the ruqyah duas;
everything else is numbered from 1 in curation order. A rebuild that renumbered
them would point that screen at whatever landed on the row — «a mis-typed id
shows up as a missing dua, not a wrong one» stops being true the moment the
table is rebuilt.

Run with --write to touch the database; without it, it only reports.
"""

import argparse
import io
import json
import os
import sqlite3
import sys

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")

DB = (r"E:\My Projects\Rafiq-Al-Darb\rafeeq_app\assets\data"
      r"\quran_sciences.db")
CURATED_OUT = "_azkar_curated_out.json"
CURATED = "azkar_curated.json"

SOURCE_NOTE = (
    "الأذكار للإمام النووي (ت ٦٧٦هـ) — المكتبة الشاملة، اختيار يدوي؛ "
    "حواشي المحقق غير مضمَّنة"
)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--write", action="store_true")
    args = ap.parse_args()

    out = json.load(io.open(CURATED_OUT, encoding="utf-8"))
    cur = json.load(io.open(CURATED, encoding="utf-8"))
    # sha -> explicit id, for the entries that demand one.
    pinned = {e["sha"]: e["id"] for e in cur["entries"] if e.get("id")}

    con = sqlite3.connect(DB)
    before_s = con.execute("SELECT COUNT(*) FROM azkar_sections").fetchone()[0]
    before_i = con.execute("SELECT COUNT(*) FROM azkar_items").fetchone()[0]

    rows_s, rows_i = [], []
    next_id = 1
    for si, sec in enumerate(out["sections"], start=1):
        rows_s.append((si, sec["title"]))
        for it in sec["items"]:
            iid = pinned.get(it["sha"])
            if iid is None:
                while next_id in pinned.values():
                    next_id += 1
                iid = next_id
                next_id += 1
            note = it["footnote"] or ""
            rows_i.append((iid, si, it["body"], note))

    ids = [r[0] for r in rows_i]
    assert len(ids) == len(set(ids)), "duplicate item id"
    for want in pinned.values():
        assert want in ids, "pinned id %s did not survive" % want

    print("sections %d -> %d" % (before_s, len(rows_s)))
    print("items    %d -> %d" % (before_i, len(rows_i)))
    print("pinned ruqyah ids: %s" % sorted(pinned.values()))
    if not args.write:
        print("\n(dry run — pass --write to apply)")
        return 0

    with con:
        con.execute("DELETE FROM azkar_items")
        con.execute("DELETE FROM azkar_sections")
        con.execute("DELETE FROM sqlite_sequence WHERE name LIKE 'azkar%'")
        con.executemany("INSERT INTO azkar_sections(id,title) VALUES(?,?)",
                        rows_s)
        con.executemany(
            "INSERT INTO azkar_items(id,section_id,body,footnote) "
            "VALUES(?,?,?,?)", rows_i)
        # The old table carried al-Qahtani's name in row 2's footnote. The new
        # one says where it came from in the same place, on row 1.
        con.execute("UPDATE azkar_items SET footnote = ? WHERE id = ?",
                    (rows_i[0][3] or SOURCE_NOTE, rows_i[0][0]))
    print("\nwritten to %s (%s bytes)" % (DB, os.path.getsize(DB)))
    left = con.execute(
        "SELECT COUNT(*) FROM azkar_items WHERE footnote LIKE '%القحطاني%' "
        "OR body LIKE '%القحطاني%'").fetchone()[0]
    print("rows still naming al-Qahtani: %d" % left)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
