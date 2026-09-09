# -*- coding: utf-8 -*-
"""Add the Asr-madhab and high-latitude keys; drop the four calc_* names.

The calculation methods themselves stopped being translation keys: an
organisation's name is a proper name, written in the reader's own script by
`properName()` (CLAUDE.md / `core/i18n/proper_name.dart`), so
`kPrayerCalculationMethods` carries both forms and the four
`prayer.calc_umm_alqura`-style keys are removed from all seven locales.
`translation_parity_test` fails if a key exists in one locale and not another,
which is why both halves happen here in one pass.

    py -3 scripts/add_i18n_keys_prayer_calc.py
"""

import io
import json
import os
from collections import OrderedDict

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TR = os.path.join(ROOT, "rafeeq_app", "assets", "translations")

DROP = ["calc_umm_alqura", "calc_egyptian", "calc_mwl", "calc_isna"]

ADD = {
    "ar": {
        "asr_method": "حساب وقت العصر",
        "asr_standard": "الجمهور (مالكي، شافعي، حنبلي)",
        "asr_hanafi": "حنفي",
        "high_latitude": "خطوط العرض العليا",
        "high_latitude_desc": "في المناطق البعيدة عن خط الاستواء قد لا يغيب "
                              "الشفق ليلًا، فلا يكون للفجر والعشاء وقت محسوب. "
                              "اختر القاعدة التي تعتمدها.",
        "high_lat_angle": "الطريقة القائمة على الزاوية",
        "high_lat_midnight": "منتصف الليل",
        "high_lat_seventh": "سُبع الليل",
    },
    "en": {
        "asr_method": "Asr calculation",
        "asr_standard": "Majority (Maliki, Shafi'i, Hanbali)",
        "asr_hanafi": "Hanafi",
        "high_latitude": "High latitudes",
        "high_latitude_desc": "Far from the equator the twilight may never "
                              "end, so Fajr and Isha have no calculated time. "
                              "Choose the rule you follow.",
        "high_lat_angle": "Angle-based",
        "high_lat_midnight": "Middle of the night",
        "high_lat_seventh": "One-seventh of the night",
    },
    "es": {
        "asr_method": "Cálculo del Asr",
        "asr_standard": "Mayoría (malikí, shafi'í, hanbalí)",
        "asr_hanafi": "Hanafí",
        "high_latitude": "Latitudes altas",
        "high_latitude_desc": "Lejos del ecuador el crepúsculo puede no "
                              "terminar, y el Fayr y el Isha no tienen hora "
                              "calculada. Elige la regla que sigues.",
        "high_lat_angle": "Basado en el ángulo",
        "high_lat_midnight": "Mitad de la noche",
        "high_lat_seventh": "Un séptimo de la noche",
    },
    "fr": {
        "asr_method": "Calcul du Asr",
        "asr_standard": "Majorité (malikite, chaféite, hanbalite)",
        "asr_hanafi": "Hanafite",
        "high_latitude": "Hautes latitudes",
        "high_latitude_desc": "Loin de l'équateur, le crépuscule peut ne "
                              "jamais finir : le Fajr et l'Icha n'ont alors "
                              "pas d'heure calculée. Choisissez la règle que "
                              "vous suivez.",
        "high_lat_angle": "Basée sur l'angle",
        "high_lat_midnight": "Milieu de la nuit",
        "high_lat_seventh": "Un septième de la nuit",
    },
    "pt": {
        "asr_method": "Cálculo do Asr",
        "asr_standard": "Maioria (maliki, chafi'i, hanbali)",
        "asr_hanafi": "Hanafi",
        "high_latitude": "Latitudes altas",
        "high_latitude_desc": "Longe do equador o crepúsculo pode não "
                              "terminar, e o Fajr e o Isha ficam sem hora "
                              "calculada. Escolha a regra que segue.",
        "high_lat_angle": "Baseada no ângulo",
        "high_lat_midnight": "Meio da noite",
        "high_lat_seventh": "Um sétimo da noite",
    },
    "ru": {
        "asr_method": "Расчёт времени аср",
        "asr_standard": "Большинство (маликиты, шафииты, ханбалиты)",
        "asr_hanafi": "Ханафитский",
        "high_latitude": "Высокие широты",
        "high_latitude_desc": "Вдали от экватора сумерки могут не "
                              "заканчиваться, и у фаджра и иша нет "
                              "вычисляемого времени. Выберите правило, "
                              "которого придерживаетесь.",
        "high_lat_angle": "По углу",
        "high_lat_midnight": "Середина ночи",
        "high_lat_seventh": "Одна седьмая ночи",
    },
    "ur": {
        "asr_method": "عصر کے وقت کا حساب",
        "asr_standard": "جمہور (مالکی، شافعی، حنبلی)",
        "asr_hanafi": "حنفی",
        "high_latitude": "بلند عرض بلد کے علاقے",
        "high_latitude_desc": "خطِ استوا سے دور شفق کبھی ختم نہیں ہوتی، اس لیے "
                              "فجر اور عشاء کا کوئی محسوب وقت نہیں ہوتا۔ وہ "
                              "اصول منتخب کریں جس پر آپ عمل کرتے ہیں۔",
        "high_lat_angle": "زاویے پر مبنی طریقہ",
        "high_lat_midnight": "نصف شب",
        "high_lat_seventh": "رات کا ساتواں حصہ",
    },
}


def main():
    for code, additions in ADD.items():
        path = os.path.join(TR, "%s.json" % code)
        with io.open(path, encoding="utf-8") as f:
            data = json.load(f, object_pairs_hook=OrderedDict)
        prayer = data["prayer"]

        dropped = 0
        for key in DROP:
            if key in prayer:
                del prayer[key]
                dropped += 1

        added = 0
        for key, value in additions.items():
            if key not in prayer:
                added += 1
            prayer[key] = value

        with io.open(path, "w", encoding="utf-8", newline="\n") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
            f.write(u"\n")
        print("%s: +%d  -%d  (prayer keys now %d)"
              % (code, added, dropped, len(prayer)))


if __name__ == "__main__":
    main()
