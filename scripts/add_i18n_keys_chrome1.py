# -*- coding: utf-8 -*-
"""The two keys `fix_i18n_chrome_batch1.py` needs, in all seven locales.

The Home card's countdown was built as `'$label: $hس $mد'` — the hour and
minute markers were Arabic letters welded into the format string, so a French
or Russian reader read «Restant: 2س 30د».

Everything else in that batch reuses keys the app already ships (`app.name`,
`quran.surah`, `quran.juz`, `quran.page`, `hijri.suffix`, `prayer.*`).
"""

import collections
import io
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TR = os.path.join(ROOT, "rafeeq_app", "assets", "translations")

# bucket -> key -> locale -> text
KEYS = {
    "home": {
        # A short unit marker glued straight onto the number: «2س», "2h".
        "hours_short": {
            "ar": "س",
            "en": "h",
            "es": "h",
            "fr": "h",
            "pt": "h",
            "ru": "ч",
            "ur": "گھ"},
        "minutes_short": {
            "ar": "د",
            "en": "m",
            "es": "min",
            "fr": "min",
            "pt": "min",
            "ru": "м",
            "ur": "م"},
    },
}

LOCALES = ["ar", "en", "es", "fr", "pt", "ru", "ur"]


def main():
    added = 0
    for code in LOCALES:
        path = os.path.join(TR, "%s.json" % code)
        doc = json.loads(io.open(path, encoding="utf-8").read(),
                         object_pairs_hook=collections.OrderedDict)
        for bucket_name, keys in KEYS.items():
            bucket = doc.setdefault(bucket_name, collections.OrderedDict())
            for key, per_locale in keys.items():
                if key in bucket:
                    continue
                bucket[key] = per_locale[code]
                added += 1
        io.open(path, "w", encoding="utf-8").write(
            json.dumps(doc, ensure_ascii=False, indent=2) + "\n")
    print("added %d key/locale pairs" % added)


if __name__ == "__main__":
    main()
