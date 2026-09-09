# -*- coding: utf-8 -*-
"""Keys for the three prayer reminders the owner asked for.

«زوّد كارت في إعدادات الأذان بتنبيهات قبل الصلاة وبعد الصلاة … وكذلك للإقامة
بعد الأذان» — a reminder N minutes before the adhan, one N minutes after it,
and one for the iqama, each with its own counter.

`{prayer}` and `{minutes}` are easy_localization named arguments, so word
order stays each language's own rather than Arabic's.

    py -3 scripts/add_i18n_keys_prayer_reminders.py
"""

import io
import json
import os
from collections import OrderedDict

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TR = os.path.join(ROOT, "rafeeq_app", "assets", "translations")

PRAYER = {
    "ar": {
        "reminders": "تنبيهات قبل الصلاة وبعدها",
        "reminders_desc": "تنبيه قبل دخول الوقت، وآخر بعد الأذان، وثالث "
                          "للإقامة. اضبط دقائق كل واحد، أو أنزله إلى صفر "
                          "لإيقافه.",
        "pre_reminder": "قبل الأذان",
        "post_reminder": "بعد الأذان",
        "iqama_reminder": "الإقامة",
        "reminder_off": "موقوف",
    },
    "en": {
        "reminders": "Before and after the prayer",
        "reminders_desc": "A reminder before the adhan, one after it, and one "
                          "for the iqama. Set the minutes for each, or take it "
                          "down to zero to turn it off.",
        "pre_reminder": "Before the adhan",
        "post_reminder": "After the adhan",
        "iqama_reminder": "Iqama",
        "reminder_off": "Off",
    },
    "es": {
        "reminders": "Antes y después de la oración",
        "reminders_desc": "Un aviso antes del adhan, otro después y otro para "
                          "el iqama. Ajusta los minutos de cada uno, o "
                          "déjalo en cero para desactivarlo.",
        "pre_reminder": "Antes del adhan",
        "post_reminder": "Después del adhan",
        "iqama_reminder": "Iqama",
        "reminder_off": "Desactivado",
    },
    "fr": {
        "reminders": "Avant et après la prière",
        "reminders_desc": "Un rappel avant l'adhan, un autre après, et un "
                          "pour l'iqama. Réglez les minutes de chacun, ou "
                          "mettez-le à zéro pour le désactiver.",
        "pre_reminder": "Avant l'adhan",
        "post_reminder": "Après l'adhan",
        "iqama_reminder": "Iqama",
        "reminder_off": "Désactivé",
    },
    "pt": {
        "reminders": "Antes e depois da oração",
        "reminders_desc": "Um aviso antes do adhan, outro depois e outro para "
                          "o iqama. Defina os minutos de cada um, ou deixe a "
                          "zero para desligar.",
        "pre_reminder": "Antes do adhan",
        "post_reminder": "Depois do adhan",
        "iqama_reminder": "Iqama",
        "reminder_off": "Desligado",
    },
    "ru": {
        "reminders": "До и после молитвы",
        "reminders_desc": "Напоминание до азана, ещё одно после него и одно "
                          "для икамы. Задайте минуты для каждого или "
                          "поставьте ноль, чтобы отключить.",
        "pre_reminder": "До азана",
        "post_reminder": "После азана",
        "iqama_reminder": "Икама",
        "reminder_off": "Выключено",
    },
    "ur": {
        "reminders": "نماز سے پہلے اور بعد کے تنبیہات",
        "reminders_desc": "اذان سے پہلے ایک تنبیہ، اس کے بعد دوسری، اور اقامت "
                          "کے لیے تیسری۔ ہر ایک کے منٹ مقرر کریں، یا صفر کر "
                          "کے بند کر دیں۔",
        "pre_reminder": "اذان سے پہلے",
        "post_reminder": "اذان کے بعد",
        "iqama_reminder": "اقامت",
        "reminder_off": "بند",
    },
}

NOTIF = {
    "ar": {
        "prayer_reminder_channel": "تنبيهات الصلاة",
        "prayer_reminder_channel_desc": "تنبيه قبل الأذان وبعده، وتنبيه "
                                        "الإقامة",
        "pre_title": "اقتربت {prayer}",
        "pre_body": "باقٍ {minutes} على {prayer}",
        "post_title": "مضى وقت من أذان {prayer}",
        "post_body": "مضى {minutes} على أذان {prayer}",
        "iqama_title": "إقامة {prayer}",
        "iqama_body": "حان وقت إقامة صلاة {prayer}",
    },
    "en": {
        "prayer_reminder_channel": "Prayer reminders",
        "prayer_reminder_channel_desc": "Before and after the adhan, and the "
                                        "iqama",
        "pre_title": "{prayer} is near",
        "pre_body": "{minutes} until {prayer}",
        "post_title": "{prayer} adhan has passed",
        "post_body": "{minutes} since the {prayer} adhan",
        "iqama_title": "{prayer} iqama",
        "iqama_body": "It is time for the {prayer} iqama",
    },
    "es": {
        "prayer_reminder_channel": "Avisos de oración",
        "prayer_reminder_channel_desc": "Antes y después del adhan, y el iqama",
        "pre_title": "Se acerca el {prayer}",
        "pre_body": "{minutes} para el {prayer}",
        "post_title": "Ya pasó el adhan del {prayer}",
        "post_body": "{minutes} desde el adhan del {prayer}",
        "iqama_title": "Iqama del {prayer}",
        "iqama_body": "Es hora del iqama del {prayer}",
    },
    "fr": {
        "prayer_reminder_channel": "Rappels de prière",
        "prayer_reminder_channel_desc": "Avant et après l'adhan, et l'iqama",
        "pre_title": "{prayer} approche",
        "pre_body": "{minutes} avant {prayer}",
        "post_title": "L'adhan du {prayer} est passé",
        "post_body": "{minutes} depuis l'adhan du {prayer}",
        "iqama_title": "Iqama du {prayer}",
        "iqama_body": "C'est l'heure de l'iqama du {prayer}",
    },
    "pt": {
        "prayer_reminder_channel": "Avisos de oração",
        "prayer_reminder_channel_desc": "Antes e depois do adhan, e o iqama",
        "pre_title": "{prayer} está próximo",
        "pre_body": "{minutes} para o {prayer}",
        "post_title": "O adhan do {prayer} já passou",
        "post_body": "{minutes} desde o adhan do {prayer}",
        "iqama_title": "Iqama do {prayer}",
        "iqama_body": "É hora do iqama do {prayer}",
    },
    "ru": {
        "prayer_reminder_channel": "Напоминания о молитве",
        "prayer_reminder_channel_desc": "До и после азана, и икама",
        "pre_title": "Скоро {prayer}",
        "pre_body": "{minutes} до {prayer}",
        "post_title": "Азан {prayer} уже прозвучал",
        "post_body": "{minutes} с азана {prayer}",
        "iqama_title": "Икама {prayer}",
        "iqama_body": "Время икамы {prayer}",
    },
    "ur": {
        "prayer_reminder_channel": "نماز کے تنبیہات",
        "prayer_reminder_channel_desc": "اذان سے پہلے اور بعد، اور اقامت",
        "pre_title": "{prayer} قریب ہے",
        "pre_body": "{prayer} میں {minutes} باقی",
        "post_title": "{prayer} کی اذان ہو چکی",
        "post_body": "{prayer} کی اذان کو {minutes} ہو گئے",
        "iqama_title": "{prayer} کی اقامت",
        "iqama_body": "{prayer} کی اقامت کا وقت ہو گیا",
    },
}


def main():
    for code in PRAYER:
        path = os.path.join(TR, "%s.json" % code)
        with io.open(path, encoding="utf-8") as f:
            data = json.load(f, object_pairs_hook=OrderedDict)
        for key, value in PRAYER[code].items():
            data["prayer"][key] = value
        for key, value in NOTIF[code].items():
            data["notif"][key] = value
        with io.open(path, "w", encoding="utf-8", newline="\n") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
            f.write(u"\n")
        print("ok %s  (+%d prayer, +%d notif)"
              % (code, len(PRAYER[code]), len(NOTIF[code])))


if __name__ == "__main__":
    main()
