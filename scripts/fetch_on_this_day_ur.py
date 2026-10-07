"""«On this day» for Urdu, from Urdu Wikipedia's own day pages.

The Wikimedia feed fetch_on_this_day.py uses answers Urdu with
404 "The language you have requested is not yet supported" (checked
2026-10-08), so an Urdu reader was falling back to English. Urdu Wikipedia
does keep a page per day ("8_اکتوبر") whose «واقعات» section lists dated
events, one per line:

    * [[2005ء]] - {{پرچم تصویر چھوٹی|پاکستان}} - [[پاکستان]] کے صوبہ ...

This reads that section for all 366 days, keeps the lines that start with a
year, strips the wiki markup, and writes assets/data/on_this_day_ur.json in
the same gzip shape as the other languages. The text is Wikipedia's own.

    py -3 scripts/fetch_on_this_day_ur.py
"""
import gzip
import json
import os
import re
import subprocess
import sys
import time
import urllib.parse

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from fetch_on_this_day import DAYS, OUT_DIR, PER_DAY, UA, trim  # noqa: E402

MONTHS = ['جنوری', 'فروری', 'مارچ', 'اپریل', 'مئی', 'جون', 'جولائی', 'اگست',
          'ستمبر', 'اکتوبر', 'نومبر', 'دسمبر']
ISLAMIC_UR = ['اسلام', 'مسلم', 'مسجد', 'خلیفہ', 'خلافت', 'حج', 'نبی', 'صحابی',
              'عثمانی', 'مکہ', 'مدینہ', 'قرآن', 'رمضان', 'بیت المقدس', 'ہجری']
API = 'https://ur.wikipedia.org/w/api.php'


def get(params):
    url = API + '?' + urllib.parse.urlencode(params)
    for attempt in range(4):
        r = subprocess.run(['curl', '-s', '-m', '60', '-A', UA, url],
                           capture_output=True)
        try:
            return json.loads(r.stdout.decode('utf-8'))
        except Exception:
            time.sleep(2 + attempt * 3)
    return None


def events_wikitext(title):
    secs = get({'action': 'parse', 'page': title, 'prop': 'sections',
                'format': 'json', 'redirects': 1})
    if not secs or 'parse' not in secs:
        return ''
    idx = next((s['index'] for s in secs['parse']['sections']
                if s['line'].strip() == 'واقعات'), None)
    if idx is None:
        return ''
    d = get({'action': 'parse', 'page': title, 'prop': 'wikitext',
             'section': idx, 'format': 'json', 'redirects': 1})
    return ((d or {}).get('parse') or {}).get('wikitext', {}).get('*', '')


def clean(s):
    s = re.sub(r'<ref[^>]*/>', '', s)
    s = re.sub(r'<ref[^>]*>.*?</ref>', '', s, flags=re.S)
    s = re.sub(r'<[^>]+>', '', s)
    for _ in range(3):  # nested templates
        s = re.sub(r'\{\{[^{}]*\}\}', '', s)
    s = re.sub(r'\[\[(?:[^\]|]*\|)?([^\]]*)\]\]', r'\1', s)
    s = re.sub(r"'{2,}", '', s)
    s = re.sub(r'\s+', ' ', s).strip()
    return s.strip(' -–—۔:')


LINE = re.compile(r'^\*\s*\[?\[?(\d{1,4})\s*ء?\]?\]?\s*ء?\s*(?:[-–—۔:]\s*)+(.*)$')


def parse(wikitext):
    rows = []
    for line in wikitext.splitlines():
        m = LINE.match(line.strip())
        if not m:
            continue
        text = clean(m.group(2))
        if len(text) < 8:
            continue
        rows.append({'y': int(m.group(1)), 't': trim(text) + ('' if text.endswith('۔') else '۔'),
                     'i': 1 if any(w in text for w in ISLAMIC_UR) else 0})
    rows.sort(key=lambda r: (-r['i'], r['y']))
    rows = rows[:PER_DAY]
    for r in rows:
        r.pop('i')
    rows.sort(key=lambda r: r['y'])
    return rows


def main():
    out, total, empty = {}, 0, []
    for month in range(1, 13):
        for day in range(1, DAYS[month - 1] + 1):
            rows = parse(events_wikitext('%d_%s' % (day, MONTHS[month - 1])))
            key = '%02d-%02d' % (month, day)
            out[key] = rows
            total += len(rows)
            if not rows:
                empty.append(key)
            print(key, len(rows))
            time.sleep(0.2)
    path = os.path.join(OUT_DIR, 'on_this_day_ur.json')
    raw = json.dumps({'source': 'wikipedia', 'lang': 'ur', 'days': out},
                     ensure_ascii=False, separators=(',', ':')).encode('utf-8')
    with open(path, 'wb') as fh:
        fh.write(gzip.compress(raw, compresslevel=9))
    print('ur: %d events, %d empty days %s, %d KB gzip -> %s'
          % (total, len(empty), empty[:20], os.path.getsize(path) // 1024, path))


if __name__ == '__main__':
    main()
