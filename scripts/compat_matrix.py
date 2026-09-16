"""Run one APK across every Android version and screen size we can reach, and
report what actually happened on each.

«اخترع طريقة تختبره بيها على كل المقاسات والبراندات والاندرويد من ٧ للآخر».

WHAT THIS COVERS AND WHAT IT DOES NOT.

  * **Android versions** — real system images, from 7.0 up to whatever is
    installed. This is the part that used to be guessed at: until 2026-09-16
    the app had only ever run on Android 16.
  * **Screen sizes** — `wm size` / `wm density` on each image, so the same
    build is seen at 320 dp, 360 dp, 411 dp and 800 dp. A layout that clips at
    320 dp clips on a real 320 dp phone; this is not an approximation.
  * **Brands — NOT covered, and it cannot be.** An emulator runs AOSP. It
    cannot tell you what MIUI does to a background service or which vendor
    kills alarms overnight, and pretending otherwise is how «متوافق مع كل
    الأجهزة» gets written about an app nobody tested. For brands there are
    exactly two honest routes, both listed in COMPATIBILITY.md: Firebase Test
    Lab (real Samsung/Xiaomi/Pixel hardware, free tier) and Play Console's
    pre-launch report (real devices, needs the developer account).

WHAT IT CHECKS ON EACH COMBINATION, in order, failing the cell on the first
one that does not hold:

  1. the APK installs at all — on 7.0 and 8.x that is the OLD signing key's
     v1/v2 path, which is the only automated check there is that key rotation
     still works (trap #41)
  2. the process is alive 25 s after launch
  3. `logcat` has no `FATAL EXCEPTION` and no `E/flutter`
  4. every tab opens and the screen is not blank — a screenshot per tab is
     written out, because a green run with a black screen is exactly the kind
     of pass this project has been burned by (§1.3)

    py -3 scripts/compat_matrix.py <apk>            # every AVD, every size
    py -3 scripts/compat_matrix.py <apk> --avd api24 --size 320
"""

import argparse
import os
import re
import subprocess
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "scripts", "compat_out")
PKG = "com.tito.rafeeq_aldarb"
SDK = os.path.join(os.environ.get("LOCALAPPDATA", ""), "Android", "Sdk")
EMULATOR = os.path.join(SDK, "emulator", "emulator.exe")

# width_dp -> (physical px, density). The first three are real phones this app
# is used on or sold to; 800 is a tablet.
SIZES = {
    320: ("480x854", 240),
    360: ("720x1280", 320),
    411: ("1080x2400", 420),
    800: ("1600x2560", 320),
}

# (label, x-fraction of the bar) for the seven destinations, RTL order.
TABS = [
    ("home", 0.93), ("quran", 0.79), ("prayer", 0.64), ("azkar", 0.50),
    ("tasbeeh", 0.36), ("library", 0.21), ("more", 0.07),
]


def sh(args, timeout=180):
    return subprocess.run(args, capture_output=True, text=True,
                          timeout=timeout, errors="replace")


def adb(serial, *args, timeout=180):
    return sh(["adb", "-s", serial] + list(args), timeout=timeout)


def avds():
    r = sh([EMULATOR, "-list-avds"])
    return [a.strip() for a in r.stdout.splitlines() if a.strip()]


def boot(avd, port):
    serial = "emulator-%d" % port
    if "device" in sh(["adb", "-s", serial, "get-state"]).stdout:
        return serial, False
    subprocess.Popen(
        [EMULATOR, "-avd", avd, "-port", str(port), "-no-snapshot", "-no-audio"],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
    )
    for _ in range(120):
        if adb(serial, "shell", "getprop", "sys.boot_completed",
               timeout=30).stdout.strip() == "1":
            time.sleep(4)
            return serial, True
        time.sleep(5)
    raise SystemExit("%s did not boot" % avd)


def blank(png_path):
    """True when the screen really is empty.

    The first version sampled NINE points and called anything with one colour
    among them blank. It flagged the home screen at 320 dp — which was drawing
    its cards perfectly — because those nine points happened to land on white
    card, and it flagged the mushaf because a page of the Qur'an is mostly one
    colour. Three false alarms out of twelve cells is worse than no check: it
    trains you to ignore the column.

    So: shrink the whole screenshot to a 16x28 grid, drop the top and bottom
    rows (status and navigation bars), and call it blank only when 97 % of
    what is left is a single colour.
    """
    try:
        from PIL import Image
    except ImportError:
        return False
    im = Image.open(png_path).convert("RGB").resize((16, 28))
    px = [im.getpixel((x, y)) for x in range(16) for y in range(2, 26)]
    top = max(px.count(c) for c in set(px))
    return top / float(len(px)) > 0.97


def run_one(serial, apk, width, results, version):
    spec, density = SIZES[width]
    adb(serial, "shell", "wm", "size", spec)
    adb(serial, "shell", "wm", "density", str(density))
    time.sleep(2)

    tag = "%s-%ddp" % (version, width)
    shots = os.path.join(OUT, tag)
    os.makedirs(shots, exist_ok=True)

    adb(serial, "shell", "am", "force-stop", PKG)
    adb(serial, "logcat", "-c")
    adb(serial, "shell", "monkey", "-p", PKG, "-c",
        "android.intent.category.LAUNCHER", "1", timeout=120)
    time.sleep(25)

    alive = bool(adb(serial, "shell", "pidof", PKG).stdout.strip())
    log = adb(serial, "logcat", "-d", timeout=120).stdout
    crashes = [l for l in log.splitlines()
               if "FATAL EXCEPTION" in l or re.search(r"\bE/flutter\b", l)]

    px = [int(v) for v in spec.split("x")]
    # WHERE THE BAR ACTUALLY IS. The first cut tapped at 96.5 % of the height
    # and hit Android 7's on-screen navigation bar instead — every tap opened
    # RECENTS, and two cells came back "blank" because the screenshot was the
    # recents screen. The app's bar sits above the system's: 48 dp of nav, and
    # the bar itself is 68 dp (`AppTheme`'s `navigationBarTheme.height`), so
    # its middle is 48 + 34 dp up from the bottom.
    bar_y = px[1] - int((48 + 34) * density / 160)
    blanks = []
    shot_bytes = []
    for name, frac in TABS:
        adb(serial, "shell", "input", "tap", str(int(px[0] * frac)), str(bar_y))
        time.sleep(3)
        shot = os.path.join(shots, "%s.png" % name)
        with open(shot, "wb") as f:
            f.write(subprocess.run(["adb", "-s", serial, "exec-out",
                                    "screencap", "-p"],
                                   capture_output=True, timeout=120).stdout)
        if blank(shot):
            blanks.append(name)
        shot_bytes.append(open(shot, "rb").read())

    # A sweep where every screenshot is identical did not sweep anything —
    # that is what a dialog over the bar looks like from here.
    stuck = len(set(shot_bytes)) <= 1 and len(shot_bytes) > 1

    results.append({
        "version": version, "width": width, "alive": alive,
        "crashes": crashes[:3], "blank_tabs": blanks, "shots": shots,
        "stuck": stuck,
    })


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("apk")
    ap.add_argument("--avd", action="append")
    ap.add_argument("--size", action="append", type=int)
    args = ap.parse_args()

    os.makedirs(OUT, exist_ok=True)
    targets = args.avd or avds()
    widths = args.size or sorted(SIZES)
    results = []
    port = 5554

    for avd in targets:
        serial, started = boot(avd, port)
        version = adb(serial, "shell", "getprop",
                      "ro.build.version.release").stdout.strip()
        sdk = adb(serial, "shell", "getprop",
                  "ro.build.version.sdk").stdout.strip()
        label = "android%s(api%s)" % (version, sdk)

        install = adb(serial, "install", "-r", args.apk, timeout=1800)
        installed = "Success" in install.stdout
        if installed:
            # GRANT EVERYTHING FIRST. The first run left the runtime dialogs
            # up, every tap landed on «ALLOW/DENY», and the sweep photographed
            # the same home screen seven times while reporting a pass. A
            # permission prompt is a real part of a first run, but it is not
            # what this matrix is measuring.
            for perm in ("ACCESS_FINE_LOCATION", "ACCESS_COARSE_LOCATION",
                         "POST_NOTIFICATIONS", "READ_MEDIA_AUDIO",
                         "READ_EXTERNAL_STORAGE", "WRITE_EXTERNAL_STORAGE"):
                adb(serial, "shell", "pm", "grant", PKG,
                    "android.permission." + perm)
            adb(serial, "shell", "settings", "put", "secure", "location_mode", "3")
        if not installed:
            results.append({"version": label, "width": "-", "alive": False,
                            "crashes": [install.stdout.strip()[:200]],
                            "blank_tabs": [], "shots": ""})
        else:
            for w in widths:
                run_one(serial, args.apk, w, results, label)

        adb(serial, "shell", "wm", "size", "reset")
        adb(serial, "shell", "wm", "density", "reset")
        if started:
            adb(serial, "emu", "kill")
            time.sleep(8)
        port += 2

    report = os.path.join(OUT, "report.txt")
    with open(report, "w", encoding="utf-8") as f:
        f.write("apk: %s\n\n" % args.apk)
        f.write("%-22s %-7s %-9s %-8s %s\n"
                % ("android", "width", "installs", "alive", "problems"))
        for r in results:
            problems = []
            if r["crashes"]:
                problems.append("CRASH: " + r["crashes"][0][:90])
            if r["blank_tabs"]:
                problems.append("blank: " + ",".join(r["blank_tabs"]))
            if r.get("stuck"):
                problems.append("tabs never changed (dialog over the bar?)")
            f.write("%-22s %-7s %-9s %-8s %s\n"
                    % (r["version"], r["width"], "yes" if r["shots"] or r["alive"] else "NO",
                       "yes" if r["alive"] else "NO",
                       "; ".join(problems) or "-"))
        f.write("\nscreenshots under %s\n" % OUT)
    print(open(report, encoding="utf-8").read())
    bad = [r for r in results
           if not r["alive"] or r["crashes"] or r["blank_tabs"] or r.get("stuck")]
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
