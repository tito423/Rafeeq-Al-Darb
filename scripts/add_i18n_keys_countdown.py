# -*- coding: utf-8 -*-
"""One key for the countdown's seconds unit, in all seven locales.

`home.hours_short` and `home.minutes_short` already exist; the Home card's
"remaining" line is a real ticking clock now, so it needs a seconds unit
beside them. `translation_parity_test` fails if a key exists in one locale and
not another, so all seven get it in the same pass.

    py -3 scripts/add_i18n_keys_countdown.py
"""

import io
import json
import os
from collections import OrderedDict

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TR = os.path.join(ROOT, "rafeeq_app", "assets", "translations")

# Matching the register of the existing units: Arabic «س / د», so «ث»;
# English "h / m", so "s"; Spanish, French and Portuguese all use "min", so
# "s"; Russian «ч / м», so «с»; Urdu «گھ / م», so «س».
SECONDS = {
    "ar": "ث",
    "en": "s",
    "es": "s",
    "fr": "s",
    "pt": "s",
    "ru": "с",
    "ur": "س",
}


def main():
    for code, value in SECONDS.items():
        path = os.path.join(TR, "%s.json" % code)
        with io.open(path, encoding="utf-8") as f:
            data = json.load(f, object_pairs_hook=OrderedDict)
        home = data["home"]
        assert "minutes_short" in home, code
        home["seconds_short"] = value
        with io.open(path, "w", encoding="utf-8", newline="\n") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
            f.write(u"\n")
        print("ok", code)


if __name__ == "__main__":
    main()
