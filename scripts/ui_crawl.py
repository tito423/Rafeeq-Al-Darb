"""Screenshot the app's screens one level deep, for the contrast scan.

    py -3 scripts/ui_crawl.py OUT_DIR PREFIX

Expects: emulator-5554, app open, English UI, portrait, on any tab.
Each target is a path of labels tapped in order from a tab; after the
last one the screen is shot, scrolled once and shot again, then Back is
pressed until the tab bar is back. Labels are matched by prefix on the
accessibility tree (the same tree scripts/ui_find.py reads).
"""
import os
import re
import subprocess
import sys
import tempfile
import time

OUT, PREFIX = sys.argv[1], sys.argv[2]
TABS = {'home': 77, 'quran': 231, 'prayer': 386, 'adhkar': 540,
        'tasbeeh': 694, 'library': 848, 'more': 1003}

# (name, tab, [labels to tap in order])
TARGETS = [
    ('adhan_settings', 'prayer', ['Adhan settings']),
    ('times_adjust', 'prayer', ['Times & date adjustment']),
    ('adhkar_morning', 'adhkar', ['Morning Adhkar']),
    ('adhkar_ruqyah', 'adhkar', ['Ruqyah']),
    ('tasbeeh_long', 'tasbeeh', ['Longer remembrances']),
    ('lib_hadith', 'library', ['Hadith']),
    ('lib_enc', 'library', ['Hadith Encyclopedia']),
    ('lib_categories', 'library', ['Categories']),
    ('lib_audio', 'library', ['Audio']),
    ('lib_mine', 'library', ['My library']),
    ('lib_author', 'library', ['Ibn Kathir']),
    ('m_player', 'more', ["Qur'an & worship", 'Quran Recitation Player']),
    ('m_tajweed', 'more', ["Qur'an & worship", 'Learn Tajweed']),
    ('m_hajj', 'more', ["Qur'an & worship", 'Hajj and Umrah']),
    ('m_hifz', 'more', ["Qur'an & worship", 'Memorize and recite']),
    ('m_ruqyah', 'more', ["Qur'an & worship", 'Listen to the Ruqyah']),
    ('m_dedic', 'more', ["Qur'an & worship", 'Dedications']),
    ('m_newmuslim', 'more', ["Qur'an & worship", 'New Muslim Guide']),
    ('m_downloads', 'more', ['Downloads']),
    ('m_focus', 'more', ['Tools', 'Focus mode']),
    ('m_rem_sunan', 'more', ['Reminders', 'Sunnah Surahs Reminders']),
    ('m_rem_tasbih', 'more', ['Reminders', 'Tasbih reminders']),
    ('m_rem_fast', 'more', ['Reminders', 'Sunnah fasting reminders']),
    ('m_rem_quotes', 'more', ['Reminders', 'Quotes']),
    ('m_set_lang', 'more', ['Settings', 'Language']),
    ('m_set_theme', 'more', ['Settings', 'Theme']),
    ('m_set_font', 'more', ['Settings', 'Font']),
    ('m_set_clock', 'more', ['Settings', 'Home clock']),
    ('m_set_mushaf', 'more', ['Settings', 'Text mushaf themes']),
    ('m_set_perm', 'more', ['Settings', 'Permissions']),
    ('m_set_reader', 'more', ['Settings', 'Book reader']),
    ('m_about', 'more', ['About']),
    ('m_support', 'more', ['About', 'Support the app']),
    ('m_sources', 'more', ['About', 'Sources']),
]


def adb(*a):
    return subprocess.run(['adb', *a], capture_output=True)


def labels():
    adb('shell', 'rm', '-f', '/sdcard/u.xml')
    adb('shell', 'uiautomator', 'dump', '/sdcard/u.xml')
    local = os.path.join(tempfile.gettempdir(), 'crawl_u.xml')
    if os.path.exists(local):
        os.remove(local)
    adb('pull', '/sdcard/u.xml', local)
    if not os.path.exists(local):
        return []
    xml = open(local, encoding='utf-8').read()
    out = []
    for n in re.finditer(r'<node [^>]*>', xml):
        s = n.group(0)
        m = re.search(r'(?:text|content-desc)="([^"]+)"', s)
        b = re.search(r'bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"', s)
        if m and b:
            x1, y1, x2, y2 = map(int, b.groups())
            text = m.group(1).replace('&amp;', '&').replace('&#10;', '\n')
            out.append((text, (x1 + x2) // 2, (y1 + y2) // 2))
    return out


def tap_label(prefix):
    for _ in range(3):
        for text, x, y in labels():
            if text.startswith(prefix) and y < 2200:
                adb('shell', 'input', 'tap', str(x), str(y))
                time.sleep(3)
                return True
        # not on screen: scroll a little and look again
        adb('shell', 'input', 'swipe', '540', '1700', '540', '1000', '300')
        time.sleep(1.5)
    return False


def shot(path):
    with open(path, 'wb') as f:
        f.write(adb('exec-out', 'screencap', '-p').stdout)


def in_app():
    top = adb('shell', 'dumpsys', 'activity', 'activities').stdout.decode(
        'utf-8', 'replace')
    line = next((l for l in top.splitlines() if 'topResumedActivity' in l), '')
    return 'com.tito.rafeeq_aldarb/.MainActivity' in line


def back_to_tabs():
    # One Back closes the pushed screen. Reading the tree to decide is not
    # safe: on Home the ticking clock makes the dump fail, and an earlier
    # version pressed Back until it left the app.
    adb('shell', 'input', 'keyevent', 'KEYCODE_BACK')
    time.sleep(1.5)
    if not in_app():
        adb('shell', 'monkey', '-p', 'com.tito.rafeeq_aldarb', '-c',
            'android.intent.category.LAUNCHER', '1')
        time.sleep(8)


os.makedirs(OUT, exist_ok=True)
for name, tab, path in TARGETS:
    adb('shell', 'input', 'tap', str(TABS[tab]), '2272')
    time.sleep(2.5)
    # the More groups remember being open; a second tap would close one
    ok = True
    for i, label in enumerate(path):
        if i + 1 < len(path) and any(
                t.startswith(path[i + 1]) and y < 2200
                for t, _, y in labels()):
            continue  # group already open
        if not tap_label(label):
            ok = False
            break
    if not ok:
        print(f'{name}: NOT REACHED ({label})', flush=True)
        back_to_tabs()
        continue
    shot(os.path.join(OUT, f'{PREFIX}_{name}_1.png'))
    adb('shell', 'input', 'swipe', '540', '1900', '540', '600', '400')
    time.sleep(2)
    shot(os.path.join(OUT, f'{PREFIX}_{name}_2.png'))
    print(f'{name}: ok', flush=True)
    back_to_tabs()
