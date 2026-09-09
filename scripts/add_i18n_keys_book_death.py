# -*- coding: utf-8 -*-
"""Three keys cover every death line in the 226-book catalogue.

`authorDeathAr` was free Arabic prose per book — «توفي 852 هـ» — so on a French
UI the library's author line read "Ibn Hajar al-Asqalani · توفي 852 هـ". It
looked like 226 strings to translate. It is three: 219 books say «توفي N هـ»,
5 say «توفي نحو N هـ», and exactly one author has no year at all. Counting
before translating is the whole difference between a template and a chore.

The year keeps Latin digits in Arabic too, because that is what the catalogue
already wrote — «توفي 852 هـ», not «توفي ٨٥٢ هـ». Nothing about the Arabic
rendering changes.
"""

import collections
import io
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TR = os.path.join(ROOT, "rafeeq_app", "assets", "translations")

KEYS = {
    "library": {
        "died_ah": {
            "ar": "توفي {} هـ",
            "en": "Died {} AH",
            "es": "Falleció en {} AH",
            "fr": "Mort en {} AH",
            "pt": "Faleceu em {} AH",
            "ru": "Умер в {} г. х.",
            "ur": "وفات {}ھ"},
        "died_circa_ah": {
            "ar": "توفي نحو {} هـ",
            "en": "Died c. {} AH",
            "es": "Falleció hacia {} AH",
            "fr": "Mort vers {} AH",
            "pt": "Faleceu por volta de {} AH",
            "ru": "Умер около {} г. х.",
            "ur": "وفات تقریباً {}ھ"},
        "death_8th_century": {
            "ar": "من علماء القرن الثامن الهجري",
            "en": "A scholar of the eighth Hijri century",
            "es": "Un sabio del siglo VIII de la Hégira",
            "fr": "Un savant du VIIIe siècle de l’Hégire",
            "pt": "Um sábio do século VIII da Hégira",
            "ru": "Учёный VIII века хиджры",
            "ur": "آٹھویں صدی ہجری کے علما میں سے"},
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
