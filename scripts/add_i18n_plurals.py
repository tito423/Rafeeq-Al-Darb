# -*- coding: utf-8 -*-
"""«1 livres». Seven count labels that were a noun glued after a number.

Photographed on the device: the French Library's author tile read "1 livres".
Every one of these keys was a bare plural noun — `book_count: "livres"` — with
the count concatenated in front of it in Dart, so the singular case was wrong
in all six non-Arabic languages, and Arabic's own dual and its 3–10 form were
wrong too («2 كتاب» rather than «كتابان»).

Each key becomes a plural map and the call site becomes `.plural(n)`.
easy_localization resolves the case with real CLDR rules per language
(`plural_rules.dart`: Arabic has zero/one/two/few/many/other, Russian has
one/few/many, the rest one/other) and falls back to `other` for any case a
language does not use — but `translation_parity_test` requires every locale to
carry the same key set, so every locale spells out all six. For French,
`few` and `many` simply repeat `other`; that is not padding, it is what the
test's guarantee costs, and it keeps a missing form from ever reaching a screen.

`{}` is replaced with the number by `plural()` itself. The Arabic zero, one and
dual forms deliberately carry no `{}`: «كتابان» already says two.
"""

import collections
import io
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TR = os.path.join(ROOT, "rafeeq_app", "assets", "translations")

LOCALES = ["ar", "en", "es", "fr", "pt", "ru", "ur"]
CASES = ["zero", "one", "two", "few", "many", "other"]


def simple(one, other):
    """A language with only a singular and a plural."""
    return {"zero": other, "one": one, "two": other,
            "few": other, "many": other, "other": other}


def russian(one, few, many):
    return {"zero": many, "one": one, "two": few,
            "few": few, "many": many, "other": few}


def arabic(zero, one, two, few, many, other):
    return {"zero": zero, "one": one, "two": two,
            "few": few, "many": many, "other": other}


COUNTS = {
    ("downloads", "items"): {
        "ar": arabic("لا عناصر", "عنصر واحد", "عنصران",
                     "{} عناصر", "{} عنصرًا", "{} عنصر"),
        "en": simple("{} item", "{} items"),
        "es": simple("{} elemento", "{} elementos"),
        "fr": simple("{} élément", "{} éléments"),
        "pt": simple("{} item", "{} itens"),
        "ru": russian("{} элемент", "{} элемента", "{} элементов"),
        "ur": simple("{} شے", "{} اشیا"),
    },
    ("quran", "ayahs"): {
        "ar": arabic("لا آيات", "آية واحدة", "آيتان",
                     "{} آيات", "{} آية", "{} آية"),
        "en": simple("{} ayah", "{} ayahs"),
        "es": simple("{} aleya", "{} aleyas"),
        "fr": simple("{} verset", "{} versets"),
        "pt": simple("{} versículo", "{} versículos"),
        "ru": russian("{} аят", "{} аята", "{} аятов"),
        "ur": simple("{} آیت", "{} آیات"),
    },
    ("quran", "ayahs_count"): {
        "ar": arabic("لا آيات", "آية واحدة", "آيتان",
                     "{} آيات", "{} آية", "{} آية"),
        "en": simple("{} ayah", "{} ayahs"),
        "es": simple("{} aleya", "{} aleyas"),
        "fr": simple("{} verset", "{} versets"),
        "pt": simple("{} versículo", "{} versículos"),
        "ru": russian("{} аят", "{} аята", "{} аятов"),
        "ur": simple("{} آیت", "{} آیات"),
    },
    ("quran", "pages_count"): {
        "ar": arabic("لا صفحات", "صفحة واحدة", "صفحتان",
                     "{} صفحات", "{} صفحة", "{} صفحة"),
        "en": simple("{} page", "{} pages"),
        "es": simple("{} página", "{} páginas"),
        "fr": simple("{} page", "{} pages"),
        "pt": simple("{} página", "{} páginas"),
        "ru": russian("{} страница", "{} страницы", "{} страниц"),
        "ur": simple("{} صفحہ", "{} صفحات"),
    },
    ("library", "book_count"): {
        "ar": arabic("لا كتب", "كتاب واحد", "كتابان",
                     "{} كتب", "{} كتابًا", "{} كتاب"),
        "en": simple("{} book", "{} books"),
        "es": simple("{} libro", "{} libros"),
        "fr": simple("{} livre", "{} livres"),
        "pt": simple("{} livro", "{} livros"),
        "ru": russian("{} книга", "{} книги", "{} книг"),
        "ur": simple("{} کتاب", "{} کتب"),
    },
    ("library", "text_search_results"): {
        "ar": arabic("لا نتائج", "نتيجة واحدة", "نتيجتان",
                     "{} نتائج", "{} نتيجة", "{} نتيجة"),
        "en": simple("{} result", "{} results"),
        "es": simple("{} resultado", "{} resultados"),
        "fr": simple("{} résultat", "{} résultats"),
        "pt": simple("{} resultado", "{} resultados"),
        "ru": russian("{} результат", "{} результата", "{} результатов"),
        "ur": simple("{} نتیجہ", "{} نتائج"),
    },
    ("search", "results_count"): {
        "ar": arabic("لا نتائج", "نتيجة واحدة", "نتيجتان",
                     "{} نتائج", "{} نتيجة", "{} نتيجة"),
        "en": simple("{} result", "{} results"),
        "es": simple("{} resultado", "{} resultados"),
        "fr": simple("{} résultat", "{} résultats"),
        "pt": simple("{} resultado", "{} resultados"),
        "ru": russian("{} результат", "{} результата", "{} результатов"),
        "ur": simple("{} نتیجہ", "{} نتائج"),
    },
}


def main():
    changed = 0
    for code in LOCALES:
        path = os.path.join(TR, "%s.json" % code)
        doc = json.loads(io.open(path, encoding="utf-8").read(),
                         object_pairs_hook=collections.OrderedDict)
        for (bucket_name, key), per_locale in COUNTS.items():
            bucket = doc.setdefault(bucket_name, collections.OrderedDict())
            if isinstance(bucket.get(key), dict):
                continue
            forms = per_locale[code]
            bucket[key] = collections.OrderedDict(
                (c, forms[c]) for c in CASES)
            changed += 1
        io.open(path, "w", encoding="utf-8").write(
            json.dumps(doc, ensure_ascii=False, indent=2) + "\n")
    print("converted %d key/locale pairs to plural maps" % changed)


if __name__ == "__main__":
    main()
