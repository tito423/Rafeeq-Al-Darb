# -*- coding: utf-8 -*-
"""Build the «في مثل هذا اليوم الهجري» dataset from Arabic Wikipedia.

WHY A SECOND DATASET
--------------------
The Home header shows two dates and, until now, both opened the same sheet —
which showed Wikimedia's `onthisday` feed. That feed is keyed by the GREGORIAN
month and day, so «١٧ رمضان» never had anything of its own to say:

    «انا عايز لما اضغط ع التاريخ الهجري يعرض تاريخ اليوم واهم الاحداث اللي
     حصلت فيه قبل كدة بشكل جميل»

This is that list, and it is a real one. Arabic Wikipedia carries a page per
Hijri day — «17 رمضان», «12 ربيع الأول» — each with an `== أحداث ==` section
whose lines are dated by HIJRI year:

    * [[2 هـ]] - وقوع غزوة بدر الكبرى …
    * [[40 هـ]] - عبد الرحمن بن ملجم يحاول اغتيال الخليفة علي بن أبي طالب …

English Wikipedia has no such pages at all (`17_Ramadan` → 404, checked), so
this dataset exists only in Arabic. That is a limit of the source, not a choice
— the sheet says so in the reader's own language rather than showing Arabic
prose to someone who cannot read it.

The text is CC BY-SA, like the Gregorian feed the app already credits.

Trap #38: Wikimedia answers 429 to a User-Agent with no contact in it.
Trap #10: every report goes to a UTF-8 file, never to the cp1256 console.

    py -3 scripts/fetch_on_this_day_hijri.py
"""
import gzip
import io
import json
import os
import re
import subprocess
import sys
import time
import urllib.parse

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "rafeeq_app", "assets", "data", "on_this_day_hijri_ar.json")
REPORT = os.path.join(ROOT, "scripts", "on_this_day_hijri_out.txt")

UA = ("RafeeqAlDarb/3.27 (https://github.com/tito423/Rafeeq-Al-Darb) curl/8")

# The twelve months as Arabic Wikipedia titles them, and the length each month
# can reach. A Hijri month is 29 or 30 days; the pages exist for both, and a
# missing one is simply skipped rather than invented.
MONTHS = [
    "محرم", "صفر", "ربيع الأول", "ربيع الآخر", "جمادى الأولى", "جمادى الآخرة",
    "رجب", "شعبان", "رمضان", "شوال", "ذو القعدة", "ذو الحجة",
]

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")


def wikitext(title):
    url = ("https://ar.wikipedia.org/w/api.php?action=parse&page=%s"
           "&prop=wikitext&format=json&formatversion=2"
           % urllib.parse.quote(title))
    for attempt in range(4):
        r = subprocess.run(["curl", "-sS", "--fail", "-A", UA, url],
                           capture_output=True)
        if r.returncode == 0:
            try:
                d = json.loads(r.stdout.decode("utf-8"))
            except ValueError:
                d = {}
            if "parse" in d:
                return d["parse"].get("wikitext", "")
            return None          # a real "no such page", not a network blip
        time.sleep(1.5 * (attempt + 1))
    return None


_REF = re.compile(r"<ref[^>]*?(/>|>.*?</ref>)", re.S)
_COMMENT = re.compile(r"<!--.*?-->", re.S)
_TAG = re.compile(r"<[^>]+>")
_TEMPLATE = re.compile(r"\{\{[^{}]*\}\}")
_LINK_PIPED = re.compile(r"\[\[[^\]|]*\|([^\]]*)\]\]")
_LINK_PLAIN = re.compile(r"\[\[([^\]]*)\]\]")
_EXT_LINK = re.compile(r"\[https?://[^\s\]]+ ([^\]]*)\]")
_BOLD_IT = re.compile(r"'{2,5}")
_WS = re.compile(r"\s+")


def clean(s):
    """Wikitext fragment -> the sentence a reader sees. Nothing rewritten."""
    s = _REF.sub("", s)
    s = _COMMENT.sub("", s)
    for _ in range(3):                      # nested templates
        s = _TEMPLATE.sub("", s)
    s = _EXT_LINK.sub(r"\1", s)
    s = _LINK_PIPED.sub(r"\1", s)
    s = _LINK_PLAIN.sub(r"\1", s)
    s = _TAG.sub("", s)
    s = _BOLD_IT.sub("", s)
    s = s.replace("&nbsp;", " ")
    # A citation template can be left OPEN at the end of the line and closed
    # several lines further down — «تدشين مصحف البحرين برعاية حكومتها.{{استشهاد
    # بويب» is what reached the app before this. The paired-brace pattern
    # above cannot see it, because we only ever hold one line. Anything from an
    # unmatched «{{» to the end of the line is that tail, and it is a reference,
    # never the sentence.
    cut = s.find("{{")
    if cut != -1:
        s = s[:cut]
    return _WS.sub(" ", s).strip(" -–—:•").strip()


# The year is matched AFTER the line has been cleaned of wiki markup, not
# before. Reading the real pages is what settled that: the year link is plain
# on some lines and PIPED on others — «[[2 هـ]] - وقوع غزوة بدر» beside
# «[[1021 هـ|1021هـ]] - بداية تحرير السجلات» — and a pattern written for the
# first form left the year inside the sentence and the year column empty on
# twelve of the eighteen lines of «12 ربيع الأول». Cleaning first makes both
# forms the same string.
#
# ق.هـ (before the Hijra) is kept as a negative year and labelled as such.
_YEAR = re.compile(r"^(\d{1,4})\s*(ق\.?\s*هـ|هـ|هجرية)?\s*[-–—:]\s*(.+)$")
_ONLY_YEAR = re.compile(r"^(\d{1,4})\s*(ق\.?\s*هـ|هـ|هجرية)?\s*$")


def parse_events(text):
    """The `== أحداث ==` section, as [(year, sentence)] in the page's order."""
    if not text:
        return []
    # The section runs from its own heading to the next heading of any level.
    m = re.search(r"^==+\s*أحداث\s*==+\s*$(.*?)(?=^==|\Z)", text, re.M | re.S)
    if not m:
        return []
    out = []
    pending_year = None
    for raw in m.group(1).splitlines():
        line = raw.rstrip()
        if not line.startswith("*"):
            continue
        stars = len(line) - len(line.lstrip("*"))
        body = line.lstrip("*").strip()
        if stars >= 2:
            # A sub-bullet belongs to the year of the line above it, which is
            # how Wikipedia writes two events in the same year.
            sentence = clean(body)
            if sentence:
                out.append((pending_year, sentence))
            continue
        cleaned = clean(body)
        # A top-level line that is ONLY a year heads a group of sub-bullets:
        #
        #     * [[1429 هـ]]
        #     ** الحدث الأول
        #     ** الحدث الثاني
        #
        # It has no dash, so the year pattern does not match it, and the first
        # cut of this parser therefore emitted the bare year AS AN EVENT and
        # cleared `pending_year` — which dropped the two real events under it.
        # 343 rows of the built file were a bare «1429 هـ» and nothing else
        # before this branch existed.
        only_year = _ONLY_YEAR.match(cleaned)
        if only_year:
            year = int(only_year.group(1))
            if only_year.group(2) and only_year.group(2).startswith("ق"):
                year = -year
            pending_year = year
            continue

        hit = _YEAR.match(cleaned)
        if hit:
            year = int(hit.group(1))
            if hit.group(2) and hit.group(2).startswith("ق"):
                year = -year        # قبل الهجرة, kept negative and labelled
            sentence = hit.group(3).strip()
            pending_year = year
            if sentence:
                out.append((year, sentence))
        else:
            sentence = clean(body)
            pending_year = None
            if sentence:
                out.append((None, sentence))
    return out


def main():
    days = {}
    report = io.open(REPORT, "w", encoding="utf-8")
    total = 0
    missing = []
    for mi, month in enumerate(MONTHS, start=1):
        for day in range(1, 31):
            title = "%d %s" % (day, month)
            text = wikitext(title)
            if text is None:
                missing.append(title)
                continue
            events = parse_events(text)
            if not events:
                report.write("no events: %s\n" % title)
                continue
            key = "%02d-%02d" % (mi, day)
            days[key] = [{"y": y, "t": t} for y, t in events]
            total += len(events)
            report.write("%s  %-22s %3d events\n" % (key, title, len(events)))
            report.flush()
            time.sleep(0.12)

    doc = {
        "schema": 1,
        "calendar": "hijri",
        "lang": "ar",
        "source": "ar.wikipedia.org — صفحات الأيام الهجرية (CC BY-SA)",
        "days": days,
    }
    raw = json.dumps(doc, ensure_ascii=False).encode("utf-8")
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with gzip.open(OUT, "wb") as f:
        f.write(raw)

    report.write("\ndays with events: %d of 360\n" % len(days))
    report.write("events: %d\n" % total)
    report.write("pages that do not exist: %d\n" % len(missing))
    for t in missing:
        report.write("  %s\n" % t)
    report.write("wrote %s  (%d bytes gzip, %d raw)\n"
                 % (OUT, os.path.getsize(OUT), len(raw)))
    report.close()
    print("days=%d events=%d missing=%d -> %s"
          % (len(days), total, len(missing), REPORT))


if __name__ == "__main__":
    main()
