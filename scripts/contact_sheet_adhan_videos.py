# -*- coding: utf-8 -*-
"""Pull one frame from every hosted adhan clip into a single contact sheet,
so the labels can be checked against what the clips actually show.

WHY. Previewing the catalogue on emulator-5554 showed an Ottoman-style mosque
in a European-looking city on the row whose size and resolution identify it as
`kaaba` — the clip the app labels «الكعبة المشرفة». A background labelled as
the Ka'bah that is not the Ka'bah is exactly what CLAUDE.md §1.1 forbids, and
it cannot be settled by reading the catalogue: the only way to check is to
look at the frames.

`ffmpeg` is on the machine already (trap #14); `curl` does the fetching
(traps #12/#19).

    py -3 scripts/contact_sheet_adhan_videos.py
"""

import io
import os
import re
import subprocess

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CATALOG = os.path.join(ROOT, "rafeeq_app", "lib", "features", "adhan", "data",
                       "adhan_video_catalog.dart")
BASE = "https://pub-39dbef68a1a845d5ba669b43a59516b9.r2.dev/adhan/video"
FFMPEG = r"C:\Program Files\ShareX\ffmpeg.exe"
OUT = os.path.join(ROOT, "dist", "adhan_frames")

# The three the catalogue dropped are still checked: they are still on the
# bucket, and if one of them is the only real Ka'bah clip that changes what
# the fix should be.
EXTRA = ["haram_makkah", "madina_nabawi", "mosque_ottoman"]


def ids():
    src = io.open(CATALOG, encoding="utf-8").read()
    found = re.findall(r"id: '([a-z0-9_]+)'", src)
    return found + [e for e in EXTRA if e not in found]


def main():
    os.makedirs(OUT, exist_ok=True)
    for vid in ids():
        mp4 = os.path.join(OUT, "%s.mp4" % vid)
        if not os.path.exists(mp4):
            subprocess.run(["curl", "-sS", "--fail",
                            "%s/%s.mp4" % (BASE, vid), "-o", mp4],
                           capture_output=True)
        for label, at in (("a", "00:00:01"), ("b", "00:00:50%")):
            png = os.path.join(OUT, "%s_%s.png" % (vid, label))
            if label == "b":
                # Halfway through, so a clip whose opening frame is a dark
                # fade still shows what it is.
                at = "00:00:05"
            subprocess.run([FFMPEG, "-y", "-hide_banner", "-loglevel", "error",
                            "-ss", at, "-i", mp4, "-frames:v", "1",
                            "-vf", "scale=480:-1", png], capture_output=True)
        print("%-18s frames written" % vid)
    print("\nframes in %s — LOOK AT THEM" % OUT)


if __name__ == "__main__":
    main()
