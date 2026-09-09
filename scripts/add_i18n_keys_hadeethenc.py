# -*- coding: utf-8 -*-
"""Add the `hadeethenc.*` strings and `library.tab_hadeethenc` to all seven
locales.

All seven at once, in one file, because `translation_parity_test` fails the
build if a key exists in one locale and not another — which is the point of
that test (CLAUDE.md trap #8: a missing key renders as the raw key on screen).

Counts are NOT written here. The screens reuse `library.hadiths_count`, which
already carries the six CLDR plural cases in every locale, rather than adding
a second way to count the same noun.

    py -3 scripts/add_i18n_keys_hadeethenc.py
"""

import io
import json
import os

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..",
                    "rafeeq_app", "assets", "translations")

TAB = {
    "ar": "الموسوعة",
    "en": "Encyclopedia",
    "es": "Enciclopedia",
    "fr": "Encyclopédie",
    "pt": "Enciclopédia",
    "ru": "Энциклопедия",
    "ur": "موسوعہ",
}

HADEETHENC = {
    "ar": {
        "title": "موسوعة الأحاديث النبوية",
        "intro": "مجموعة مختارة من الأحاديث، كل حديث فيها بتخريجه ودرجته "
                 "بلغتك، ومعه شرح مبسّط.",
        "search_hint": "ابحث في الموسوعة",
        "no_results": "لا توجد نتائج",
        "no_pack_for_language": "لا تتوفر حزمة لهذه اللغة",
        "pack_title": "حزمة {name}",
        "pack_summary": "{name}: {count} — حجم التنزيل {size}",
        "takhrij": "التخريج",
        "grade": "الدرجة",
        "grade_by": "تصنيف {source}",
        "grade_inline": "الدرجة: {grade}",
        "grade_missing": "غير مذكورة",
        "explanation": "الشرح",
        "hints": "من فوائد الحديث",
        "reference": "المراجع",
        "credit": "المصدر: {source}",
    },
    "en": {
        "title": "Hadeeth Encyclopedia",
        "intro": "A curated collection in which every hadith carries its "
                 "takhrij and its grading in your own language, with a plain "
                 "explanation.",
        "search_hint": "Search the encyclopedia",
        "no_results": "No results",
        "no_pack_for_language": "No pack is available for this language",
        "pack_title": "{name} pack",
        "pack_summary": "{name}: {count} — download {size}",
        "takhrij": "Takhrij (source)",
        "grade": "Grade",
        "grade_by": "Graded by {source}",
        "grade_inline": "Grade: {grade}",
        "grade_missing": "Not stated",
        "explanation": "Explanation",
        "hints": "Benefits of the hadith",
        "reference": "References",
        "credit": "Source: {source}",
    },
    "es": {
        "title": "Enciclopedia del Hadiz",
        "intro": "Una colección seleccionada en la que cada hadiz lleva su "
                 "takhrij y su grado en tu propio idioma, con una explicación "
                 "sencilla.",
        "search_hint": "Buscar en la enciclopedia",
        "no_results": "Sin resultados",
        "no_pack_for_language": "No hay paquete disponible para este idioma",
        "pack_title": "Paquete {name}",
        "pack_summary": "{name}: {count} — descarga {size}",
        "takhrij": "Takhrij (fuente)",
        "grade": "Grado",
        "grade_by": "Clasificado por {source}",
        "grade_inline": "Grado: {grade}",
        "grade_missing": "No indicado",
        "explanation": "Explicación",
        "hints": "Beneficios del hadiz",
        "reference": "Referencias",
        "credit": "Fuente: {source}",
    },
    "fr": {
        "title": "Encyclopédie du hadith",
        "intro": "Une collection choisie où chaque hadith porte son takhrij "
                 "et son degré d’authenticité dans votre propre langue, avec "
                 "une explication simple.",
        "search_hint": "Rechercher dans l’encyclopédie",
        "no_results": "Aucun résultat",
        "no_pack_for_language": "Aucun pack n’est disponible pour cette langue",
        "pack_title": "Pack {name}",
        "pack_summary": "{name} : {count} — téléchargement {size}",
        "takhrij": "Takhrij (source)",
        "grade": "Degré d’authenticité",
        "grade_by": "Classé par {source}",
        "grade_inline": "Degré : {grade}",
        "grade_missing": "Non indiqué",
        "explanation": "Explication",
        "hints": "Enseignements du hadith",
        "reference": "Références",
        "credit": "Source : {source}",
    },
    "pt": {
        "title": "Enciclopédia do Hadith",
        "intro": "Uma coleção selecionada em que cada hadith traz o seu "
                 "takhrij e o seu grau no seu próprio idioma, com uma "
                 "explicação simples.",
        "search_hint": "Pesquisar na enciclopédia",
        "no_results": "Sem resultados",
        "no_pack_for_language": "Não há pacote disponível para este idioma",
        "pack_title": "Pacote {name}",
        "pack_summary": "{name}: {count} — descarregar {size}",
        "takhrij": "Takhrij (fonte)",
        "grade": "Grau",
        "grade_by": "Classificado por {source}",
        "grade_inline": "Grau: {grade}",
        "grade_missing": "Não indicado",
        "explanation": "Explicação",
        "hints": "Benefícios do hadith",
        "reference": "Referências",
        "credit": "Fonte: {source}",
    },
    "ru": {
        "title": "Энциклопедия хадисов",
        "intro": "Отобранное собрание, в котором у каждого хадиса есть "
                 "тахридж и степень достоверности на вашем языке, а также "
                 "простое разъяснение.",
        "search_hint": "Поиск по энциклопедии",
        "no_results": "Ничего не найдено",
        "no_pack_for_language": "Для этого языка пакет недоступен",
        "pack_title": "Пакет «{name}»",
        "pack_summary": "{name}: {count} — загрузка {size}",
        "takhrij": "Тахридж (источник)",
        "grade": "Степень достоверности",
        "grade_by": "Оценка: {source}",
        "grade_inline": "Степень: {grade}",
        "grade_missing": "Не указана",
        "explanation": "Разъяснение",
        "hints": "Польза хадиса",
        "reference": "Источники",
        "credit": "Источник: {source}",
    },
    "ur": {
        "title": "موسوعۂ احادیثِ نبویہ",
        "intro": "ایک منتخب مجموعہ، جس میں ہر حدیث کے ساتھ اس کی تخریج اور "
                 "درجہ آپ کی اپنی زبان میں موجود ہے، اور ساتھ آسان شرح بھی۔",
        "search_hint": "موسوعہ میں تلاش کریں",
        "no_results": "کوئی نتیجہ نہیں",
        "no_pack_for_language": "اس زبان کے لیے کوئی پیکج دستیاب نہیں",
        "pack_title": "{name} پیکج",
        "pack_summary": "{name}: {count} — ڈاؤن لوڈ {size}",
        "takhrij": "تخریج",
        "grade": "درجہ",
        "grade_by": "درجہ بندی: {source}",
        "grade_inline": "درجہ: {grade}",
        "grade_missing": "مذکور نہیں",
        "explanation": "شرح",
        "hints": "فوائدِ حدیث",
        "reference": "مراجع",
        "credit": "مصدر: {source}",
    },
}


def main():
    for loc in ["ar", "en", "es", "fr", "pt", "ru", "ur"]:
        path = os.path.join(ROOT, "%s.json" % loc)
        with io.open(path, encoding="utf-8") as f:
            data = json.load(f)
        data["library"]["tab_hadeethenc"] = TAB[loc]
        data["hadeethenc"] = HADEETHENC[loc]
        with io.open(path, "w", encoding="utf-8", newline="\n") as f:
            json.dump(data, f, ensure_ascii=False, indent=2, sort_keys=False)
            f.write("\n")
        print("%s: +%d keys" % (loc, len(HADEETHENC[loc]) + 1))


if __name__ == "__main__":
    main()
