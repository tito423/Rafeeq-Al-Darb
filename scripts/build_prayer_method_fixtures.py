# -*- coding: utf-8 -*-
"""Fetch AlAdhan's published prayer-time methods and a reference timings grid.

WHY THIS EXISTS
The app calculates prayer times **offline**, with the `adhan` Dart package, so
every calculation method it offers is a set of angles this repo has to state
itself. CLAUDE.md §1.1 forbids inventing those numbers, and §1.5 asks for a
measurement rather than a claim. So:

  1. `https://api.aladhan.com/v1/methods` publishes every method's real
     parameters (Fajr/Isha angle, or an Isha interval in minutes) beside the
     organisation that set them. That is the source
     `lib/features/adhan/data/prayer_calculation_methods.dart` is written
     from, and the one credited on the Sources screen.
  2. `https://api.aladhan.com/v1/timings/...&timezonestring=UTC` then gives a
     reference answer per (method, city, date) — in UTC, so it can be compared
     with `PrayerTimes.utc(...)` straight across, with no timezone guessing.

The grid is committed as a test fixture and
`rafeeq_app/test/calculation_methods_test.dart` asserts the app's own numbers
against it. A method whose angles are wrong, or whose Isha is an interval the
catalogue wrote as an angle, fails that test loudly instead of silently
shipping the wrong Isha to whoever picked it.

CURL, NOT urllib
An earlier version of this script used `urllib` and took **43 seconds per
request** against this API — 57 rows in 41 minutes — while `curl` to the same
URL returned in 0.5 s, measured three times in a row. CLAUDE.md trap #12
already says to use `curl` for HTTPS on this machine; this is the same trap
with a new host. Rows are appended to a `.jsonl` as they arrive and the run
resumes, so a stall costs nothing but the rows it had not reached.

    py -3 scripts/build_prayer_method_fixtures.py

Writes:
    rafeeq_app/test/fixtures/prayer_methods.json    (the published catalogue)
    rafeeq_app/test/fixtures/prayer_timings.json    (the reference grid)
    prayer_fixture_progress.jsonl                   (resume log, gitignored)
"""

import io
import json
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "rafeeq_app", "test", "fixtures")
PROGRESS = os.path.join(ROOT, "prayer_fixture_progress.jsonl")
API = "https://api.aladhan.com/v1"

# Four cities that between them exercise every branch: an ordinary
# mid-latitude city, the one Umm al-Qura is set for, the southern
# hemisphere, and a latitude high enough that the high-latitude rule bites.
CITIES = [
    ("cairo", 30.0444, 31.2357),
    ("makkah", 21.4225, 39.8262),
    ("jakarta", -6.2088, 106.8456),
    ("london", 51.5074, -0.1278),
]

# One date near an equinox and one at the June solstice — the moonsighting
# method's seasonal adjustment differs between them, so a single date would
# not prove it.
DATES = ["15-03-2026", "21-06-2026"]

# Both Asr schools. AlAdhan calls them `school=0` (STANDARD — Maliki,
# Shafi'i, Hanbali: one shadow-length) and `school=1` (HANAFI — two). The app
# offers both and the difference is up to an hour, so both are checked.
SCHOOLS = [(0, "STANDARD"), (1, "HANAFI")]

# The ids the app actually offers, read straight out of the Dart catalogue so
# the two can never drift apart.
CATALOGUE = os.path.join(ROOT, "rafeeq_app", "lib", "features", "adhan",
                         "data", "prayer_calculation_methods.dart")


def offered_ids():
    src = io.open(CATALOGUE, encoding="utf-8").read()
    return sorted(int(m) for m in re.findall(r"^\s*id:\s*(\d+),", src,
                                             re.MULTILINE))


def get(url):
    """One GET, through curl. Raises on anything that is not valid JSON."""
    res = subprocess.run(
        ["curl", "-sS", "--fail", "--max-time", "30", url],
        capture_output=True)
    if res.returncode != 0:
        raise RuntimeError("curl %d on %s: %s"
                           % (res.returncode, url,
                              res.stderr.decode("utf-8", "replace")[:200]))
    return json.loads(res.stdout.decode("utf-8"))


def log(msg):
    """Windows console is cp1256 and cannot print Arabic (CLAUDE.md #10) —
    everything printed here is ASCII on purpose."""
    sys.stdout.write(msg + "\n")
    sys.stdout.flush()


def main():
    if not os.path.isdir(OUT):
        os.makedirs(OUT)

    methods = get("%s/methods" % API)["data"]
    catalogue = {}
    for key, m in methods.items():
        mid = m.get("id")
        # 99 is AlAdhan's "CUSTOM" placeholder — it has no parameters and is
        # not a method anyone can pick.
        if mid is None or mid == 99:
            continue
        catalogue[str(mid)] = {
            "key": key,
            "name": m.get("name"),
            "params": m.get("params") or {},
        }
    with io.open(os.path.join(OUT, "prayer_methods.json"), "w",
                 encoding="utf-8", newline="\n") as f:
        json.dump(catalogue, f, ensure_ascii=False, indent=1, sort_keys=True)
        f.write(u"\n")
    log("methods published: %d" % len(catalogue))

    ids = offered_ids()
    log("methods the app offers: %d -> %s" % (len(ids), ids))

    done = {}
    if os.path.exists(PROGRESS):
        for line in io.open(PROGRESS, encoding="utf-8"):
            line = line.strip()
            if not line:
                continue
            row = json.loads(line)
            done[(row["method"], row["city"], row["date"],
                  1 if row.get("school") == "HANAFI" else 0)] = row
        log("resuming with %d rows already fetched" % len(done))

    wanted = [(mid, city, lat, lon, date, school)
              for school, _name in SCHOOLS
              for date in DATES for city, lat, lon in CITIES for mid in ids]
    todo = [w for w in wanted if (w[0], w[1], w[4], w[5]) not in done]
    log("to fetch: %d of %d" % (len(todo), len(wanted)))

    progress = io.open(PROGRESS, "a", encoding="utf-8", newline="\n")
    for n, (mid, city, lat, lon, date, school) in enumerate(todo, 1):
        url = ("%s/timings/%s?latitude=%s&longitude=%s&method=%d&school=%d"
               "&timezonestring=UTC" % (API, date, lat, lon, mid, school))
        data = get(url)["data"]
        t = data["timings"]
        row = {
            "method": mid,
            "city": city,
            "latitude": lat,
            "longitude": lon,
            "date": date,
            "fajr": t["Fajr"],
            "sunrise": t["Sunrise"],
            "dhuhr": t["Dhuhr"],
            "asr": t["Asr"],
            "maghrib": t["Maghrib"],
            "isha": t["Isha"],
            # AlAdhan's own high-latitude rule and Asr school, so the test can
            # set the package to match rather than guess.
            "latitudeAdjustmentMethod":
                data["meta"].get("latitudeAdjustmentMethod"),
            "school": data["meta"].get("school"),
        }
        done[(mid, city, date, school)] = row
        progress.write(json.dumps(row, ensure_ascii=False) + u"\n")
        progress.flush()
        if n % 10 == 0 or n == len(todo):
            log("  %d / %d" % (n, len(todo)))
    progress.close()

    grid = [done[(mid, city, date, school)]
            for school, _name in SCHOOLS
            for date in DATES for city, _lat, _lon in CITIES for mid in ids]
    with io.open(os.path.join(OUT, "prayer_timings.json"), "w",
                 encoding="utf-8", newline="\n") as f:
        json.dump(grid, f, ensure_ascii=False, indent=1)
        f.write(u"\n")
    log("timings rows: %d" % len(grid))


if __name__ == "__main__":
    main()
