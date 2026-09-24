"""List (or find) on-screen elements of the app on emulator-5554.

Flutter exposes its widgets to the accessibility tree, so `uiautomator dump`
gives every visible label with its bounds - a way to tap by what a control
SAYS instead of by guessed coordinates.

    py -3 scripts/ui_find.py            # list every labelled element
    py -3 scripts/ui_find.py تجربة      # only those whose label contains it;
                                        # prints the centre to tap
    py -3 scripts/ui_find.py تجربة --tap  # tap the one whose label STARTS so
"""
import re
import subprocess
import sys
import tempfile
import os

dump = os.path.join(tempfile.gettempdir(), 'ui_find.xml')
subprocess.run(['adb', 'shell', 'rm', '-f', '/sdcard/u.xml'], capture_output=True)
r = subprocess.run(['adb', 'shell', 'uiautomator', 'dump', '/sdcard/u.xml'],
                   capture_output=True, text=True)
# An animating screen (a ticking clock, a progress bar) never goes idle and
# the dump fails; without the rm above the OLD file was read back as if new.
if 'dumped' not in (r.stdout + r.stderr):
    sys.stdout.buffer.write(b'DUMP FAILED (screen not idle) - take a screenshot\n')
    sys.exit(2)
subprocess.run(['adb', 'pull', '/sdcard/u.xml', dump], capture_output=True)
xml = open(dump, encoding='utf-8').read()
want = sys.argv[1] if len(sys.argv) > 1 else None
out = []
for node in re.finditer(r'<node [^>]*>', xml):
    n = node.group(0)
    label = ''
    for attr in ('text', 'content-desc'):
        m = re.search(attr + r'="([^"]*)"', n)
        if m and m.group(1).strip():
            label = m.group(1)
            break
    b = re.search(r'bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"', n)
    if not label or not b:
        continue
    if want and want not in label:
        continue
    x1, y1, x2, y2 = map(int, b.groups())
    out.append(f'{(x1 + x2) // 2} {(y1 + y2) // 2}\t{label[:60]!r}')
if '--tap' in sys.argv and want:
    starts = [o for o in out if o.split('\t')[1].strip("'").startswith(want)]
    pick = (starts or out)[:1]
    if pick:
        x, y = pick[0].split('\t')[0].split()
        subprocess.run(['adb', 'shell', 'input', 'tap', x, y])
        out = ['tapped ' + pick[0]]
    else:
        out = ['NOT FOUND: ' + want]
sys.stdout.buffer.write(('\n'.join(out) + '\n').encode('utf-8'))
