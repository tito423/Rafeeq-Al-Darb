# -*- coding: utf-8 -*-
"""Relabel the adhan background clips to what their frames actually show, in
all seven locales, and drop the keys of the five clips that were removed.

WHY. Four frames were pulled from across every hosted clip
(`contact_sheet_adhan_videos.py`) and looked at. Six of the ten were not the
scene the app named them:

    mosque_view     «رحاب مسجد»              the flag of Pakistan
    kaaba_close     «الكعبة المشرّفة عن قرب»  gold «محمد» calligraphy
    kaaba_tawaf     «الحرم والكعبة»          the same calligraphy
    kaaba           «الكعبة المشرفة»         a cartoon 3-D animation
    haram_makkah2   «ساحات الحرم المكي»      the same cartoon
    madina_haram    «رحاب المسجد النبوي»     an Ottoman mosque over a Turkish city

CLAUDE.md §1.1: nothing fake. A label is a claim about the content, and a
claim the content does not support is the thing this project exists not to
ship. `adhan_video_content.json` records what each clip shows.

    py -3 scripts/relabel_adhan_videos.py
"""

import io
import json
import os

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..",
                    "rafeeq_app", "assets", "translations")
LOCALES = ["ar", "en", "es", "fr", "pt", "ru", "ur"]

# Only the five that survive, each named for what its frames show.
LABELS = {
    "madina_haram": {
        "ar": "مسجد عثماني فوق المدينة",
        "en": "An Ottoman mosque above the city",
        "es": "Una mezquita otomana sobre la ciudad",
        "fr": "Une mosquée ottomane au-dessus de la ville",
        "pt": "Uma mesquita otomana sobre a cidade",
        "ru": "Османская мечеть над городом",
        "ur": "شہر کے اوپر ایک عثمانی مسجد",
    },
    "mosque_minaret": {
        "ar": "داخل مسجد عثماني",
        "en": "Inside an Ottoman mosque",
        "es": "Dentro de una mezquita otomana",
        "fr": "À l’intérieur d’une mosquée ottomane",
        "pt": "Dentro de uma mesquita otomana",
        "ru": "Внутри османской мечети",
        "ur": "ایک عثمانی مسجد کے اندر",
    },
    "kaaba_close": {
        "ar": "خط عربي: محمد ﷺ",
        "en": "Arabic calligraphy: Muhammad ﷺ",
        "es": "Caligrafía árabe: Muhammad ﷺ",
        "fr": "Calligraphie arabe : Muhammad ﷺ",
        "pt": "Caligrafia árabe: Muhammad ﷺ",
        "ru": "Арабская каллиграфия: Мухаммад ﷺ",
        "ur": "عربی خطاطی: محمد ﷺ",
    },
    "haram_makkah": {
        "ar": "الحرم المكي ليلًا",
        "en": "The Masjid al-Haram at night",
        "es": "La Mezquita Sagrada de noche",
        "fr": "La Mosquée sacrée la nuit",
        "pt": "A Mesquita Sagrada à noite",
        "ru": "Заповедная мечеть ночью",
        "ur": "رات میں مسجدِ حرام",
    },
    "madina_nabawi": {
        "ar": "المسجد النبوي من أعلى",
        "en": "The Prophet's Mosque from above",
        "es": "La Mezquita del Profeta desde arriba",
        "fr": "La Mosquée du Prophète vue d’en haut",
        "pt": "A Mesquita do Profeta vista de cima",
        "ru": "Мечеть Пророка сверху",
        "ur": "اوپر سے مسجدِ نبوی",
    },
}

# Removed from the catalogue, so their keys go too — a dead key is a claim
# nobody can check any more.
DROP = ["kaaba", "kaaba_tawaf", "haram_makkah2", "mosque_ottoman",
        "mosque_view"]


def main():
    for loc in LOCALES:
        path = os.path.join(ROOT, "%s.json" % loc)
        with io.open(path, encoding="utf-8") as f:
            data = json.load(f)
        block = data["adhan_video"]
        for vid in DROP:
            block.pop(vid, None)
        for vid, byLang in LABELS.items():
            block[vid] = byLang[loc]
        with io.open(path, "w", encoding="utf-8", newline="\n") as f:
            json.dump(data, f, ensure_ascii=False, indent=2, sort_keys=False)
            f.write("\n")
        print("%s: %d clip labels, %d dropped" % (loc, len(LABELS), len(DROP)))


if __name__ == "__main__":
    main()
