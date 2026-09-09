# -*- coding: utf-8 -*-
"""Turn the two hadith-book count chips into real plurals.

WHY
The chips were `'$value $label'` with a fixed noun, which is fine in English
and wrong in Russian: «97 Главы» was on screen during the Russian sweep, where
97 takes the genitive plural («97 глав»), and the noun was capitalised
mid-phrase as well. Arabic has the same problem in the other direction — «7277
حديث» reads as one hadith repeated.

Both keys become the six-form maps `easy_localization` expects, in the same
shape the app already uses for `quran.ayahs` and `search.results_count`, and
`translation_parity_test` keeps every locale carrying every form.

    py -3 scripts/add_i18n_keys_count_plurals.py
"""

import io
import json
import os
from collections import OrderedDict

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TR = os.path.join(ROOT, "rafeeq_app", "assets", "translations")

HADITHS = {
    "ar": {
        "zero": "لا أحاديث", "one": "حديث واحد", "two": "حديثان",
        "few": "{} أحاديث", "many": "{} حديثًا", "other": "{} حديث",
    },
    "en": {
        "zero": "{} hadiths", "one": "{} hadith", "two": "{} hadiths",
        "few": "{} hadiths", "many": "{} hadiths", "other": "{} hadiths",
    },
    "es": {
        "zero": "{} hadices", "one": "{} hadiz", "two": "{} hadices",
        "few": "{} hadices", "many": "{} hadices", "other": "{} hadices",
    },
    "fr": {
        "zero": "{} hadiths", "one": "{} hadith", "two": "{} hadiths",
        "few": "{} hadiths", "many": "{} hadiths", "other": "{} hadiths",
    },
    "pt": {
        "zero": "{} hadiths", "one": "{} hadith", "two": "{} hadiths",
        "few": "{} hadiths", "many": "{} hadiths", "other": "{} hadiths",
    },
    # Russian: 1 хадис · 2-4 хадиса · 5-20 хадисов, and the "many" bucket is
    # the one 7277 and 7459 land in.
    "ru": {
        "zero": "{} хадисов", "one": "{} хадис", "two": "{} хадиса",
        "few": "{} хадиса", "many": "{} хадисов", "other": "{} хадиса",
    },
    "ur": {
        "zero": "{} احادیث", "one": "{} حدیث", "two": "{} احادیث",
        "few": "{} احادیث", "many": "{} احادیث", "other": "{} احادیث",
    },
}

CHAPTERS = {
    "ar": {
        "zero": "لا أبواب", "one": "باب واحد", "two": "بابان",
        "few": "{} أبواب", "many": "{} بابًا", "other": "{} باب",
    },
    "en": {
        "zero": "{} chapters", "one": "{} chapter", "two": "{} chapters",
        "few": "{} chapters", "many": "{} chapters", "other": "{} chapters",
    },
    "es": {
        "zero": "{} capítulos", "one": "{} capítulo", "two": "{} capítulos",
        "few": "{} capítulos", "many": "{} capítulos",
        "other": "{} capítulos",
    },
    "fr": {
        "zero": "{} chapitres", "one": "{} chapitre", "two": "{} chapitres",
        "few": "{} chapitres", "many": "{} chapitres",
        "other": "{} chapitres",
    },
    "pt": {
        "zero": "{} capítulos", "one": "{} capítulo", "two": "{} capítulos",
        "few": "{} capítulos", "many": "{} capítulos",
        "other": "{} capítulos",
    },
    # 97 and 57 are "many" in Russian (they end in 7), which is «97 глав».
    "ru": {
        "zero": "{} глав", "one": "{} глава", "two": "{} главы",
        "few": "{} главы", "many": "{} глав", "other": "{} главы",
    },
    "ur": {
        "zero": "{} ابواب", "one": "{} باب", "two": "{} ابواب",
        "few": "{} ابواب", "many": "{} ابواب", "other": "{} ابواب",
    },
}


def main():
    for code in HADITHS:
        path = os.path.join(TR, "%s.json" % code)
        with io.open(path, encoding="utf-8") as f:
            data = json.load(f, object_pairs_hook=OrderedDict)
        lib = data["library"]
        lib["hadiths_count"] = OrderedDict(
            (k, HADITHS[code][k])
            for k in ("zero", "one", "two", "few", "many", "other"))
        lib["chapters"] = OrderedDict(
            (k, CHAPTERS[code][k])
            for k in ("zero", "one", "two", "few", "many", "other"))
        with io.open(path, "w", encoding="utf-8", newline="\n") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
            f.write(u"\n")
        print("ok", code)


if __name__ == "__main__":
    main()
