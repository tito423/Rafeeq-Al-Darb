"""Every image the app hotlinks must still resolve.

WHY THIS EXISTS. Thirteen card backgrounds are fetched from
`images.unsplash.com` at runtime — the Azkar grid and the New Muslim guide.
On 2026-09-18 **two of them were 404**, and had been for long enough that
nobody noticed:

    AzkarCategory.mosque     photo-1591604129939-f1efa4d99f7e   404
    AzkarCategory.narrated   photo-1585036156171-384164a8c956   404

The failure is silent by design — `CachedNetworkImage` falls back to the
card's gradient, so «أذكار المسجد» simply renders as a flat orange card while
its neighbours carry photographs. It is in a screenshot taken during this
session's screen sweep, and it was read as a styling choice rather than as a
dead link. `flutter analyze` and 358 tests had no opinion about it, because
there is nothing wrong with the code.

That is CLAUDE.md §1.1 in its quietest form: an entry in a catalogue whose
content does not resolve. Run this after touching any `*_backgrounds.dart`,
and before a release.

    py -3 scripts/check_remote_images.py

Exits non-zero if anything fails, and prints every URL it checked so the
result is a measurement rather than a claim.
"""

from __future__ import annotations

import io
import os
import re
import subprocess
import sys

# Windows console is cp1256 and cannot print Arabic (trap #10) — this script
# prints URLs and status codes only, which are ASCII.

UA = (
    "RafeeqAlDarb/3.34 (https://github.com/tito423/Rafeeq-Al-Darb) curl/8"
)

# Wikimedia refuses a User-Agent with no contact in it (trap #38), and R2's
# public endpoint answers a bare request with 403 (trap #19). One honest UA
# with a contact URL satisfies both.

URL_RE = re.compile(r"'(https://[^']+\.(?:jpg|jpeg|png|webp)(?:\?[^']*)?)'")
HOST_RE = re.compile(r"'(https://images\.unsplash\.com/[^']+)'")

ROOT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                    "rafeeq_app", "lib")


def collect() -> list[tuple[str, str]]:
    """(source file, url) for every hotlinked image in lib/."""
    found: list[tuple[str, str]] = []
    for base, _dirs, files in os.walk(ROOT):
        for name in files:
            if not name.endswith(".dart"):
                continue
            path = os.path.join(base, name)
            text = io.open(path, encoding="utf-8").read()
            for pattern in (URL_RE, HOST_RE):
                for url in pattern.findall(text):
                    rel = os.path.relpath(path, ROOT).replace("\\", "/")
                    if (rel, url) not in found:
                        found.append((rel, url))
    return found


def check(url: str) -> str:
    """The HTTP status of a 1 KB range request, or an error string."""
    try:
        run = subprocess.run(
            ["curl", "-sS", "-o", os.devnull, "-w", "%{http_code}",
             "-r", "0-1023", "-A", UA, url],
            capture_output=True, text=True, timeout=60,
        )
    except subprocess.TimeoutExpired:
        return "timeout"
    return run.stdout.strip() or "no-status"


def main() -> int:
    targets = collect()
    if not targets:
        print("no hotlinked images found — did the layout change?")
        return 1

    failures = []
    for rel, url in targets:
        status = check(url)
        ok = status.startswith(("200", "206"))
        print("%-4s %-46s %s" % (status, rel, url[:96]))
        if not ok:
            failures.append((rel, url, status))

    print("\nchecked %d, failures %d" % (len(targets), len(failures)))
    for rel, url, status in failures:
        print("  FAIL %s  %s  %s" % (status, rel, url))
    if failures:
        print("\nA dead background does not crash anything — the card just "
              "renders its gradient and looks like a design choice. Replace "
              "the URL, and LOOK at the replacement before cataloguing it.")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
