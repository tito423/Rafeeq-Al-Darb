"""Screenshot sweep of the main screens across languages x themes x
orientations on emulator-5554 (owner, 2026-09-24: «every feature in every
theme, every language, landscape and portrait»).

    py -3 scripts/ui_matrix_sweep.py OUT_DIR [lang ...]

For each language: Home > language sheet > that language; then for each
theme (the Home theme button cycles system -> light -> dark -> rgb) and each
orientation, one screenshot per tab (+ the Home page scrolled down). Then a
contact sheet per (lang, theme, orientation) so a person can read them.

Starting state it expects: app open on Home, portrait, theme LIGHT.
Nothing here judges a screen - the sheets are read by eye.
"""
import os
import re
import subprocess
import sys
import tempfile
import time

from PIL import Image

OUT = sys.argv[1]
LANGS = sys.argv[2:] or ['ar', 'en', 'es', 'ru', 'pt', 'fr', 'ur']
NATIVE = {'ar': 'العربية', 'en': 'English', 'es': 'Español', 'ru': 'Русский',
          'pt': 'Português', 'fr': 'Français', 'ur': 'اردو'}
RTL = {'ar', 'ur'}
# light is where the sweep starts; each tap moves one step on.
THEMES = ['light', 'dark', 'rgb']

# Tab centres, Home..More, left to right in an LTR layout.
PORTRAIT_TABS = [77, 231, 386, 540, 694, 848, 1003]
PORTRAIT_Y = 2272
LAND_TABS = [171, 514, 857, 1199, 1542, 1885, 2228]
LAND_Y = 948
NAMES = ['home', 'quran', 'prayer', 'adhkar', 'tasbeeh', 'library', 'more']


def adb(*a):
    return subprocess.run(['adb', *a], capture_output=True)


def tap(x, y, wait=1.5):
    adb('shell', 'input', 'tap', str(x), str(y))
    time.sleep(wait)


def shot(path):
    with open(path, 'wb') as f:
        f.write(adb('exec-out', 'screencap', '-p').stdout)


def labels():
    adb('shell', 'rm', '-f', '/sdcard/u.xml')
    adb('shell', 'uiautomator', 'dump', '/sdcard/u.xml')
    local = os.path.join(tempfile.gettempdir(), 'sweep_u.xml')
    adb('pull', '/sdcard/u.xml', local)
    try:
        xml = open(local, encoding='utf-8').read()
    except FileNotFoundError:
        return []
    out = []
    for n in re.finditer(r'<node [^>]*>', xml):
        s = n.group(0)
        m = re.search(r'(?:text|content-desc)="([^"]+)"', s)
        b = re.search(r'bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"', s)
        if m and b:
            x1, y1, x2, y2 = map(int, b.groups())
            out.append((m.group(1), (x1 + x2) // 2, (y1 + y2) // 2))
    return out


def tab(i, rtl, land):
    xs = LAND_TABS if land else PORTRAIT_TABS
    x = xs[len(xs) - 1 - i] if rtl else xs[i]
    tap(x, LAND_Y if land else PORTRAIT_Y, 3)


def header_button(which, rtl):
    """Home header: language + settings on one side, theme + support on the
    other; the sides swap in RTL."""
    left, right = (162, 268), (918, 268)
    if which == 'lang':
        return left if rtl else right
    return right if rtl else left


def set_lang(code, rtl_now):
    tab(0, rtl_now, False)
    tap(*header_button('lang', rtl_now), wait=2)
    for text, x, y in labels():
        if text == NATIVE[code]:
            tap(x, y, 4)
            return True
    return False


def rotate(land):
    adb('shell', 'settings', 'put', 'system', 'accelerometer_rotation', '0')
    adb('shell', 'settings', 'put', 'system', 'user_rotation',
        '1' if land else '0')
    time.sleep(3)


def sweep_screens(prefix, rtl, land):
    files = []
    for i, name in enumerate(NAMES):
        tab(i, rtl, land)
        f = f'{prefix}_{name}.png'
        shot(f)
        files.append(f)
        if name == 'home':
            # The page below the prayer card.
            w, h = (2400, 1080) if land else (1080, 2400)
            adb('shell', 'input', 'swipe', str(w // 2), str(h * 3 // 4),
                str(w // 2), str(h // 4), '400')
            time.sleep(2)
            f2 = f'{prefix}_home2.png'
            shot(f2)
            files.append(f2)
            adb('shell', 'input', 'swipe', str(w // 2), str(h // 4),
                str(w // 2), str(h * 3 // 4), '300')
            adb('shell', 'input', 'swipe', str(w // 2), str(h // 4),
                str(w // 2), str(h * 3 // 4), '300')
        if name == 'quran':
            # The reader opens full screen, over the tab bar.
            adb('shell', 'input', 'keyevent', 'KEYCODE_BACK')
            time.sleep(2)
    return files


def contact_sheet(files, out, land):
    tw, th = (600, 270) if land else (270, 600)
    cols = 4
    rows = (len(files) + cols - 1) // cols
    sheet = Image.new('RGB', (tw * cols, th * rows), 'white')
    for k, f in enumerate(files):
        im = Image.open(f).convert('RGB').resize((tw, th))
        sheet.paste(im, ((k % cols) * tw, (k // cols) * th))
    sheet.save(out)


def main():
    os.makedirs(OUT, exist_ok=True)
    rtl_now = True  # the sweep is started from Arabic
    for code in LANGS:
        if not set_lang(code, rtl_now):
            print(f'{code}: language option not found', flush=True)
            continue
        rtl_now = code in RTL
        for t_i, theme in enumerate(THEMES):
            for land in (False, True):
                rotate(land)
                prefix = os.path.join(OUT, f'{code}_{theme}_{"L" if land else "P"}')
                files = sweep_screens(prefix, rtl_now, land)
                contact_sheet(files, prefix + '_SHEET.png', land)
                print(prefix + '_SHEET.png', flush=True)
            rotate(False)
            tab(0, rtl_now, False)
            # next theme (light -> dark -> rgb -> system -> light)
            tap(*header_button('theme', rtl_now), wait=3)
        # three taps above ended on system; one more is light again
        tap(*header_button('theme', rtl_now), wait=3)


main()
