# -*- coding: utf-8 -*-
"""Adds `prayer.minutes_count` (plural) to all seven locales and repairs the
Arabic reminder sentences that emulator-5554 showed on 2026-09-10.

WHAT WAS ON SCREEN
    title  «اقتربت الفجر»            — feminine verb, masculine noun
    body   «باقٍ 10 دقيقة على الفجر»  — masculine adjective, singular counted
                                        noun after 10, Latin digits

WHAT IS WRONG WITH IT
    1. Four of the five prayer names are masculine (الفجر، الظهر، العصر،
       المغرب) and one is feminine (العشاء), so no single verb form agrees
       with «{prayer}». Agreeing with «صلاة» instead is correct for all five
       — which is what `notif.iqama_body` already did.
    2. Arabic counts 3-10 with a plural (دقائق) and 11-99 with a singular
       accusative (دقيقة). `_minutes()` hardcoded one unit for every count.
    3. The digits are shaped by `localizeDigits`, not here.

Run: py -3 scripts/fix_prayer_reminder_strings.py
"""
import io
import json
import os

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..',
                    'rafeeq_app', 'assets', 'translations')

# `zero` is unreachable — `PrayerReminderService._arm` cancels at 0 rather
# than scheduling — but the parity test requires the same key set in all
# seven files, and an honest string costs nothing.
MINUTES_COUNT = {
    'ar': {
        'zero': 'لا دقائق',
        'one': 'دقيقة واحدة',
        'two': 'دقيقتان',
        'few': '{} دقائق',
        'many': '{} دقيقة',
        'other': '{} دقيقة',
    },
    # The other six locales already used an invariant abbreviation for the
    # unit, and an abbreviation does not inflect. Every case is the same
    # string on purpose: the key exists so the parity test passes and so a
    # future translator has somewhere to put a real plural.
    'en': dict.fromkeys(
        ['zero', 'one', 'two', 'few', 'many', 'other'], '{} min'),
    'fr': dict.fromkeys(
        ['zero', 'one', 'two', 'few', 'many', 'other'], '{} min'),
    'es': dict.fromkeys(
        ['zero', 'one', 'two', 'few', 'many', 'other'], '{} min'),
    'pt': dict.fromkeys(
        ['zero', 'one', 'two', 'few', 'many', 'other'], '{} min'),
    'ru': dict.fromkeys(
        ['zero', 'one', 'two', 'few', 'many', 'other'], '{} мин.'),
    'ur': dict.fromkeys(
        ['zero', 'one', 'two', 'few', 'many', 'other'], '{} منٹ'),
}

# Arabic only: the other six read correctly already.
AR_NOTIF = {
    'pre_title': 'اقترب موعد صلاة {prayer}',
    'pre_body': 'بقيت {minutes} على صلاة {prayer}',
    'post_body': 'مضت {minutes} على أذان {prayer}',
}


def rewrite(loc):
    path = os.path.join(ROOT, '%s.json' % loc)
    with io.open(path, encoding='utf-8') as f:
        data = json.load(f)

    changed = []

    prayer = data['prayer']
    if prayer.get('minutes_count') != MINUTES_COUNT[loc]:
        prayer['minutes_count'] = MINUTES_COUNT[loc]
        changed.append('prayer.minutes_count')

    if loc == 'ar':
        for key, value in AR_NOTIF.items():
            if data['notif'].get(key) != value:
                changed.append('notif.%s: %s -> %s'
                               % (key, data['notif'].get(key), value))
                data['notif'][key] = value

    with io.open(path, 'w', encoding='utf-8', newline='\n') as f:
        json.dump(data, f, ensure_ascii=False, indent=2, sort_keys=False)
        f.write('\n')
    return changed


def main():
    report = io.open(os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                  '..', 'fix_prayer_strings_report.txt'),
                     'w', encoding='utf-8')
    for loc in ['ar', 'en', 'fr', 'es', 'pt', 'ru', 'ur']:
        for line in rewrite(loc):
            report.write('%s  %s\n' % (loc, line))
    report.close()


if __name__ == '__main__':
    main()
