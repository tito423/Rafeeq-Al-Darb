"""Fetch the Arabic UI fonts the app offers in Settings > الخط.

Each family is downloaded from the Google Fonts CSS API as static TTF files,
one per weight the family really has among 400/500/600/700, and saved under
rafeeq_app/assets/fonts/google_fonts/ with the exact names the google_fonts
package looks for (<FamilyNoSpaces>-<Regular|Medium|SemiBold|Bold>.ttf):
runtime fetching is off in this app, and the package throws if the weight it
picks is not bundled. All families are SIL Open Font License 1.1.

    py -3 scripts/fetch_app_fonts.py
"""
import os
import re
import sys
import urllib.error
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'rafeeq_app', 'assets', 'fonts', 'google_fonts')
UA = 'curl/8.4.0'

FAMILIES = [
    'Tajawal', 'Almarai', 'IBM Plex Sans Arabic', 'Noto Kufi Arabic',
    'Noto Naskh Arabic', 'Amiri', 'Scheherazade New', 'Lateef', 'Markazi Text',
    'Reem Kufi', 'El Messiri', 'Aref Ruqaa', 'Changa', 'Alexandria',
]
WEIGHTS = {400: 'Regular', 500: 'Medium', 600: 'SemiBold', 700: 'Bold'}


def get(url):
    req = urllib.request.Request(url, headers={'User-Agent': UA})
    with urllib.request.urlopen(req, timeout=60) as r:
        return r.read()


def main():
    total = 0
    report = []
    for fam in FAMILIES:
        got = []
        for w, name in WEIGHTS.items():
            css_url = ('https://fonts.googleapis.com/css2?family='
                       + fam.replace(' ', '+') + f':wght@{w}')
            try:
                css = get(css_url).decode('utf-8')
            except urllib.error.HTTPError:
                continue  # the family has no such weight
            m = re.search(r"src: url\((https://[^)]+\.ttf)\)", css)
            if not m:
                sys.exit(f'{fam} {w}: no ttf in css')
            data = get(m.group(1))
            if data[:4] not in (b'\x00\x01\x00\x00', b'true'):
                sys.exit(f'{fam} {w}: not a TrueType file')
            path = os.path.join(OUT, fam.replace(' ', '') + f'-{name}.ttf')
            with open(path, 'wb') as f:
                f.write(data)
            total += len(data)
            got.append(f'{w}:{len(data)}')
        if not got:
            sys.exit(f'{fam}: nothing downloaded')
        report.append(f'{fam}: ' + ' '.join(got))
    report.append(f'TOTAL {total}')
    with open(os.path.join(ROOT, 'rafeeq_app', 'build', 'fonts_report.txt'),
              'w', encoding='utf-8') as f:
        f.write('\n'.join(report))


if __name__ == '__main__':
    main()
