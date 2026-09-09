# -*- coding: utf-8 -*-
"""Compute the real contrast of every tone in `core/theme/hero_surface.dart`.

CLAUDE.md trap #15: a translucent tone over a gradient composites to neither
of the two colours you can see, and three mushaf themes shipped at 2.3–2.6 : 1
because someone judged that pairing by eye. So every foreground in the hero
palette is checked here against the ground it actually lands on — including
the ground *under a scrim*, which is where the countdown pill's text sits.

    py -3 scripts/check_hero_contrast.py

Exits non-zero if anything is under 4.5 : 1, and writes
`hero_contrast.txt` (UTF-8, but everything printed is ASCII — the console
here is cp1256).
"""

import io
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "hero_contrast.txt")

FLOOR = 4.5

DARK = {
    "gradient": [0xFF0B0F1A, 0xFF102A3A, 0xFF1B1533],
    "scrim": 0x14FFFFFF,
    "fg": {
        "onSurface": 0xFFFFFFFF,
        "onSurfaceMuted": 0xFFB9C6C3,
        "onSurfaceFaint": 0xFF93A5A1,
    },
}

LIGHT = {
    "gradient": [0xFFFAFDFC, 0xFFDFEFEA, 0xFFE9E5F5],
    "scrim": 0x140E7C6B,
    "fg": {
        "onSurface": 0xFF10231D,
        "onSurfaceMuted": 0xFF3A4B45,
        "onSurfaceFaint": 0xFF4E605A,
    },
}

# The six per-prayer chip fills, and the text tone each becomes on each
# ground. The right-hand values are the ones baked into
# `HeroSurface._darkAccents` / `_lightAccents`; this script exists to prove
# they still clear the floor, so the two must be edited together.
PRAYER = {
    "fajr": 0xFF7C4DFF,
    "sunrise": 0xFF8D6E63,
    "dhuhr": 0xFF2F80A9,
    "asr": 0xFF2E9D6F,
    "maghrib": 0xFFD4AF37,
    "isha": 0xFF15C7B0,
}

ACCENTS = {
    "dark": {
        "fajr": 0xFFAE91FF,
        "sunrise": 0xFFB49F98,
        "dhuhr": 0xFF74AAC5,
        "asr": 0xFF5CB38F,
        "maghrib": 0xFFD4AF37,
        "isha": 0xFF15C7B0,
    },
    "light": {
        "fajr": 0xFF6742D4,
        "sunrise": 0xFF715B51,
        "dhuhr": 0xFF256684,
        "asr": 0xFF206C4D,
        "maghrib": 0xFF6D6023,
        "isha": 0xFF0D6C5F,
    },
}


def rgb(argb):
    return ((argb >> 16) & 0xFF, (argb >> 8) & 0xFF, argb & 0xFF)


def alpha(argb):
    return ((argb >> 24) & 0xFF) / 255.0


def lerp(a, b, t):
    ar, ag, ab = rgb(a)
    br, bg, bb = rgb(b)
    return (0xFF000000
            | int(round(ar + (br - ar) * t)) << 16
            | int(round(ag + (bg - ag) * t)) << 8
            | int(round(ab + (bb - ab) * t)))


def over(fg, bg):
    """`fg` composited onto opaque `bg`."""
    a = alpha(fg)
    fr, fg_, fb = rgb(fg)
    br, bg_, bb = rgb(bg)
    return (0xFF000000
            | int(round(fr * a + br * (1 - a))) << 16
            | int(round(fg_ * a + bg_ * (1 - a))) << 8
            | int(round(fb * a + bb * (1 - a))))


def luminance(argb):
    def channel(v):
        v = v / 255.0
        return v / 12.92 if v <= 0.03928 else ((v + 0.055) / 1.055) ** 2.4
    r, g, b = rgb(argb)
    return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b)


def ratio(a, b):
    la, lb = luminance(a), luminance(b)
    hi, lo = max(la, lb), min(la, lb)
    return (hi + 0.05) / (lo + 0.05)


def main():
    out = io.open(OUT, "w", encoding="utf-8")
    failures = []

    for name, spec in (("dark", DARK), ("light", LIGHT)):
        out.write(u"=== %s ===\n" % name)
        # Every gradient stop, and every stop under the scrim: a foreground
        # has to clear the floor on the worst of them, not on the average.
        grounds = [("stop%d" % i, c) for i, c in enumerate(spec["gradient"])]
        grounds += [("stop%d+scrim" % i, over(spec["scrim"], c))
                    for i, c in enumerate(spec["gradient"])]

        for fg_name, fg in sorted(spec["fg"].items()):
            worst = min(ratio(fg, g) for _n, g in grounds)
            where = min(grounds, key=lambda g: ratio(fg, g[1]))[0]
            flag = "OK " if worst >= FLOOR else "FAIL"
            out.write(u"  %s %-16s %5.2f : 1  (worst on %s)\n"
                      % (flag, fg_name, worst, where))
            if worst < FLOOR:
                failures.append("%s/%s %.2f" % (name, fg_name, worst))

        for prayer in sorted(PRAYER):
            accent = ACCENTS[name][prayer]
            worst = min(ratio(accent, g) for _n, g in grounds)
            where = min(grounds, key=lambda g: ratio(accent, g[1]))[0]
            flag = "OK " if worst >= FLOOR else "FAIL"
            out.write(u"  %s accent:%-9s %5.2f : 1  (#%06X, worst on %s)\n"
                      % (flag, prayer, worst, accent & 0xFFFFFF, where))
            if worst < FLOOR:
                failures.append("%s/accent:%s %.2f" % (name, prayer, worst))
        out.write(u"\n")

    out.close()
    sys.stdout.write("wrote hero_contrast.txt\n")
    if failures:
        sys.stdout.write("BELOW %.1f:1 -> %s\n" % (FLOOR, ", ".join(failures)))
        sys.exit(1)
    sys.stdout.write("every tone clears %.1f:1\n" % FLOOR)


if __name__ == "__main__":
    main()
