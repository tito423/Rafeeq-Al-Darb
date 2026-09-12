# -*- coding: utf-8 -*-
"""Build the bundled «في مثل هذا اليوم» dataset from Wikipedia.

WHY WIKIPEDIA AND NOT A LIST I WRITE
------------------------------------
The owner asked for historical events on every day, Islamic and world, with no
empty dates — and §1.1 forbids inventing content. Wikimedia's `onthisday` feed
is a real, attributable, openly licensed source that covers all 366 days:

    GET https://api.wikimedia.org/feed/v1/wikipedia/<lang>/onthisday/events/MM/DD

Its text is CC BY-SA 4.0, so the card credits Wikipedia and links to the day's
page. Nothing is rewritten: each line is the summary Wikipedia serves, trimmed
to one sentence's worth and nothing else.

BUNDLED, NOT FETCHED AT READ TIME. The app works offline by design, and a card
that needs the network to show a date is a card that is blank on a plane.

Trap #38: Wikimedia answers 429 to a User-Agent with no contact in it.

    py -3 scripts/fetch_on_this_day.py            # ar + en
"""
import gzip
import io
import json
import os
import subprocess
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, 'rafeeq_app', 'assets', 'data')
UA = 'RafeeqAlDarb/3.23 (https://github.com/tito423/Rafeeq-Al-Darb) curl/8'

# Days per Gregorian month, February at 29 so the 29th is covered.
DAYS = [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]

PER_DAY = 12

# Words that mark a line as belonging to Islamic history. Used only to ORDER
# the day's events - «خاصة اللي تخص التاريخ الإسلامي» - never to claim one is
# more true than another, and never to drop anything.
ISLAMIC = (
    'الإسلام', 'إسلامي', 'المسلم', 'النبي', 'الرسول', 'الخليفة', 'الخلافة',
    'الصحاب', 'غزوة', 'معركة اليرموك', 'القادسية', 'الأندلس', 'العثماني',
    'الأموي', 'العباسي', 'الفاطمي', 'الأيوبي', 'المملوكي', 'السلجوق',
    'مكة', 'المدينة المنورة', 'القدس', 'الأقصى', 'الكعبة', 'الهجرة',
    'هـ', 'القرآن',
    'Islam', 'Muslim', 'Prophet', 'Caliph', 'Ottoman', 'Umayyad', 'Abbasid',
    'Mecca', 'Medina', 'Jerusalem', 'Quran',
)


def fetch(lang, month, day):
    url = ('https://api.wikimedia.org/feed/v1/wikipedia/%s/onthisday/events/'
           '%02d/%02d' % (lang, month, day))
    for attempt in range(4):
        r = subprocess.run(['curl', '-s', '-m', '60', '-A', UA, url],
                           capture_output=True)
        try:
            return json.loads(r.stdout.decode('utf-8'))
        except Exception:
            time.sleep(2 + attempt * 3)
    return None


def score(text):
    return 1 if any(w in text for w in ISLAMIC) else 0


def trim(text):
    """One sentence's worth. Wikipedia's summaries run long and the card is a
    card, not an article."""
    t = ' '.join(text.split())
    if len(t) <= 190:
        return t
    cut = t[:190]
    for sep in ('. ', '، ', '؛ ', ' - '):
        i = cut.rfind(sep)
        if i > 90:
            return cut[:i + 1].strip()
    return cut.rstrip() + '…'


def main():
    langs = sys.argv[1:] or ['ar', 'en']
    for lang in langs:
        out = {}
        total = 0
        for month in range(1, 13):
            for day in range(1, DAYS[month - 1] + 1):
                data = fetch(lang, month, day)
                events = (data or {}).get('events', [])
                rows = []
                for e in events:
                    text = trim(e.get('text', ''))
                    if not text:
                        continue
                    rows.append({'y': e.get('year'), 't': text,
                                 'i': score(text)})
                # Islamic-history lines first, then the rest, each newest last
                # so a day reads forward in time.
                rows.sort(key=lambda r: (-r['i'], r['y'] if r['y'] else 0))
                rows = rows[:PER_DAY]
                for r in rows:
                    r.pop('i', None)
                out['%02d-%02d' % (month, day)] = rows
                total += len(rows)
                print('%s %02d-%02d  %d events' % (lang, month, day, len(rows)))
                time.sleep(0.25)
        path = os.path.join(OUT_DIR, 'on_this_day_%s.json' % lang)
        raw = json.dumps({'source': 'wikipedia', 'lang': lang, 'days': out},
                         ensure_ascii=False, separators=(',', ':')
                         ).encode('utf-8')
        with open(path, 'wb') as fh:
            fh.write(gzip.compress(raw, compresslevel=9))
        print('%s: %d events, %d KB raw, %d KB gzip -> %s'
              % (lang, total, len(raw) // 1024,
                 os.path.getsize(path) // 1024, path))


if __name__ == '__main__':
    sys.exit(main())
