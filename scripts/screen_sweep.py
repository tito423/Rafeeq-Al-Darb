"""Stage C sweep (docs/history/ADAPTIVE_PLAN.md): every main tab at every screen class,
upright and sideways, on the emulator, via `wm size` / `wm density`.

Tab positions come from app_shell.dart's layout rule (see tab_pos); the
tab bar moves to a side rail on wide screens.

    py -3 scripts/screen_sweep.py [out_dir]

Writes one contact sheet per (config, orientation) and restores the
emulator's own size and density at the end.
"""
import os
import re
import subprocess
import sys
import time

from PIL import Image, ImageDraw

ADB = [r"E:\DevEnv\Android\Sdk\platform-tools\adb.exe", "-s", "emulator-5554"]
PKG = "com.tito.rafeeq_aldarb"
CONFIGS = [  # name, size, density (docs/history/ADAPTIVE_PLAN.md stage C)
    ("phone", "1080x2400", 420),
    ("xiaomi", "1220x2712", 480),
    ("tablet", "1600x2560", 320),
    ("smart", "1080x1920", 240),
    ("tv", "1920x1080", 320),
]
TABS = ["الرئيسية", "القرآن", "الصلاة", "الأذكار", "المسبحة", "المكتبة", "المزيد"]


def adb(*args, binary=False):
    r = subprocess.run(ADB + list(args), capture_output=True)
    return r.stdout if binary else r.stdout.decode("utf-8", "replace")


def tab_pos(i, w, h, dens):
    """Where tab [i] is, from app_shell.dart's own rule (uiautomator cannot
    dump this app's home: the ticking clock never lets it go idle).
    Sideways (wider than tall, or >= 840 dp wide): a 64 dp rail on the
    right (RTL), seven equal shares of at most 7 x 88 dp, centred. Upright:
    the bottom bar, seven equal columns, centre 72 dp above the bottom
    (measured on the emulator: 2210 of 2400 px at 420 dpi)."""
    dp = dens / 160
    if w > h or w / dp >= 840:
        top, bottom = 24 * dp, 24 * dp
        avail = h - top - bottom
        col = min(avail, 7 * 88 * dp)
        y = top + (avail - col) / 2 + (i + 0.5) * col / 7
        return int(w - 32 * dp), int(y)
    return int(w - (i + 0.5) * w / 7), int(h - 72 * dp)


def shot(path):
    with open(path, "wb") as f:
        f.write(adb("exec-out", "screencap", "-p", binary=True))


def sheet(paths, labels, out, title):
    ims = [Image.open(p) for p in paths]
    w = 360
    thumbs = [im.resize((w, int(im.height * w / im.width))) for im in ims]
    h = max(t.height for t in thumbs)
    cols = 4 if thumbs[0].width < thumbs[0].height else 3
    rows = (len(thumbs) + cols - 1) // cols
    S = Image.new("RGB", (cols * (w + 8), rows * (h + 30) + 30), "white")
    d = ImageDraw.Draw(S)
    d.text((6, 6), title, fill="black")
    for i, (t, lab) in enumerate(zip(thumbs, labels)):
        x, y = (i % cols) * (w + 8), 30 + (i // cols) * (h + 30)
        S.paste(t, (x, y + 22))
        d.text((x + 4, y + 4), lab, fill="red")
    S.save(out)


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else "sweep"
    os.makedirs(out, exist_ok=True)
    adb("shell", "settings", "put", "system", "accelerometer_rotation", "0")
    missing = []
    try:
        only = os.environ.get("SWEEP_ONLY")
        for name, size, dens in CONFIGS:
            if only and name != only:
                continue
            adb("shell", "wm", "size", size)
            adb("shell", "wm", "density", str(dens))
            for rot in (0, 1):
                adb("shell", "am", "force-stop", PKG)
                time.sleep(1)
                adb("shell", "monkey", "-p", PKG, "-c", "android.intent.category.LAUNCHER", "1")
                time.sleep(18)  # the splash runs ~12 s
                # Rotated AFTER the launch: `settings user_rotation` never
                # rotated this emulator, and a `cmd window user-rotation lock`
                # set before force-stop was undone by the restart
                # (ROTATION_90 -> ROTATION_0, accelerometer_rotation back to 1).
                adb("shell", "cmd", "window", "user-rotation", "lock", str(rot))
                time.sleep(4)
                paths, labels = [], []
                probe = os.path.join(out, "probe.png")
                shot(probe)
                w, h = Image.open(probe).size
                print(name, rot, "screen", w, h, flush=True)
                for i in [0, 2, 3, 4, 5, 6, 1]:  # Quran last: its reader hides the tab bar
                    tab = TABS[i]
                    pos = tab_pos(i, w, h, dens)
                    adb("shell", "input", "tap", str(pos[0]), str(pos[1]))
                    time.sleep(3)
                    p = os.path.join(out, f"{name}_r{rot}_{i}.png")
                    shot(p)
                    paths.append(p)
                    labels.append(f"tab{i}")
                if paths:
                    sheet(paths, labels, os.path.join(out, f"SHEET_{name}_r{rot}.png"),
                          f"{name} {size}@{dens} rot{rot}")
                print(name, rot, len(paths), "shots", flush=True)
    finally:
        adb("shell", "wm", "size", "reset")
        adb("shell", "wm", "density", "reset")
        adb("shell", "cmd", "window", "user-rotation", "lock", "0")
    print("missing:", missing)


if __name__ == "__main__":
    main()
