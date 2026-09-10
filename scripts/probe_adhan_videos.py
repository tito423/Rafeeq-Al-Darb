# -*- coding: utf-8 -*-
"""Measure every hosted adhan background clip: resolution, bitrate, size.

The owner's report was «الفيديو بتاع الأذان لما بيشتغل بتبقى جودته سيئة جدًا»,
and CLAUDE.md §1.3/§1.4 both say the same thing about that: measure the real
files before changing anything. `adhan_video_catalog.dart`'s own comment says
its sizes are «the real byte counts of the hosted **_tiny** mp4s», which is
the first hint that what is on the bucket is not what was downloaded from
Pixabay.

`ffmpeg` is already on this machine (trap #14) and `curl` does the fetching
(trap #12/#19 — the bucket 403s a bare urllib request).

    py -3 scripts/probe_adhan_videos.py
"""

import io
import json
import os
import re
import subprocess

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CATALOG = os.path.join(ROOT, "rafeeq_app", "lib", "features", "adhan", "data",
                       "adhan_video_catalog.dart")
BASE = "https://pub-39dbef68a1a845d5ba669b43a59516b9.r2.dev/adhan/video"
FFMPEG = r"C:\Program Files\ShareX\ffmpeg.exe"
TMP = os.environ.get("TEMP", ".")


def ids():
    src = io.open(CATALOG, encoding="utf-8").read()
    return re.findall(r"id: '([a-z0-9_]+)'", src)


def remote_size(url):
    out = subprocess.run(["curl", "-sSI", "--fail", url], capture_output=True)
    for line in out.stdout.decode("utf-8", "replace").splitlines():
        if line.lower().startswith("content-length:"):
            return int(line.split(":", 1)[1].strip())
    return 0


def probe(vid):
    url = "%s/%s.mp4" % (BASE, vid)
    size = remote_size(url)
    path = os.path.join(TMP, "probe_%s.mp4" % vid)
    # The whole file, not a range: an mp4 whose `moov` atom is at the end
    # cannot be parsed from a prefix, and reporting "unknown" for those would
    # be exactly the kind of half-measurement this project does not accept.
    subprocess.run(["curl", "-sS", "--fail", url, "-o", path],
                   capture_output=True)
    out = subprocess.run([FFMPEG, "-hide_banner", "-i", path],
                         capture_output=True)
    txt = out.stderr.decode("utf-8", "replace")
    m = re.search(r"Video: (\w+).*?, (\d+)x(\d+).*?(?:, ([\d.]+) kb/s)?, "
                  r"([\d.]+) fps", txt, re.S)
    d = re.search(r"Duration: (\d+):(\d+):([\d.]+)", txt)
    seconds = 0.0
    if d:
        seconds = int(d.group(1)) * 3600 + int(d.group(2)) * 60 + float(d.group(3))
    row = {
        "id": vid,
        "bytes": size,
        "seconds": round(seconds, 2),
        "codec": m.group(1) if m else "?",
        "width": int(m.group(2)) if m else 0,
        "height": int(m.group(3)) if m else 0,
        "fps": float(m.group(5)) if m else 0.0,
        "kbps": round(size * 8 / seconds / 1000) if seconds else 0,
    }
    os.remove(path)
    return row


def main():
    rows = [probe(v) for v in ids()]
    out = os.path.join(ROOT, "adhan_video_probe.json")
    with io.open(out, "w", encoding="utf-8", newline="\n") as f:
        json.dump(rows, f, ensure_ascii=False, indent=2)
        f.write("\n")

    print("%-18s %10s %7s %11s %6s %8s" %
          ("id", "bytes", "sec", "size", "fps", "kbps"))
    for r in rows:
        flag = "  <-- SD" if r["height"] and r["height"] < 720 else ""
        print("%-18s %10d %7.1f %5dx%-5d %6.2f %8d%s"
              % (r["id"], r["bytes"], r["seconds"], r["width"], r["height"],
                 r["fps"], r["kbps"], flag))
    print("\nwrote %s" % out)


if __name__ == "__main__":
    main()
