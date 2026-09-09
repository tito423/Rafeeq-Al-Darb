# -*- coding: utf-8 -*-
"""Add the `quotes.*` and `notif.quote_*` strings to all seven locales.

All seven in one file, because `translation_parity_test` fails the build if a
key exists in one locale and not another (trap #8: a missing key renders as
the raw key on screen).

`quotes.count`, `quotes.books`, `quotes.minutes` and `quotes.hours` are plural
keys with the six CLDR cases, because Arabic and Russian both need them —
«٣٠ دقيقة» vs «١٥ دقيقة» vs «ساعتان» is exactly the agreement the prayer
reminder got wrong this same session.

    py -3 scripts/add_i18n_keys_quotes.py
"""

import io
import json
import os

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..",
                    "rafeeq_app", "assets", "translations")
LOCALES = ["ar", "en", "es", "fr", "pt", "ru", "ur"]


def flat(one, other, zero=None, two=None, few=None, many=None):
    return {
        "zero": zero or other,
        "one": one,
        "two": two or other,
        "few": few or other,
        "many": many or other,
        "other": other,
    }


QUOTES = {
    "ar": {
        "section_title": "المقولات",
        "reminder_title": "إشعار مقولة",
        "reminder_desc": "{count} من {books}، تظهر واحدة كل مدة تختارها.",
        "reminder_desc_plain": "مقولات من كتب المكتبة، بمصادرها.",
        "off": "موقوف",
        "preview": "اعرض مقولة الآن",
        "dismiss": "إغلاق",
        "window_note": "يُجهَّز {n} إشعارًا في كل مرة تفتح فيها التطبيق.",
        "count": flat("مقولة واحدة", "{} مقولة", zero="لا مقولات",
                      two="مقولتان", few="{} مقولات"),
        "books": flat("كتاب واحد", "{} كتابًا", zero="لا كتب",
                      two="كتابان", few="{} كتب"),
        "minutes": flat("دقيقة", "{} دقيقة", two="دقيقتان", few="{} دقائق"),
        "hours": flat("ساعة", "{} ساعة", two="ساعتان", few="{} ساعات"),
    },
    "en": {
        "section_title": "Quotes",
        "reminder_title": "Quote notification",
        "reminder_desc": "{count} from {books}, one at the interval you pick.",
        "reminder_desc_plain": "Sayings from the library's own books, sourced.",
        "off": "Off",
        "preview": "Show one now",
        "dismiss": "Close",
        "window_note": "{n} are armed each time you open the app.",
        "count": flat("{} quote", "{} quotes"),
        "books": flat("{} book", "{} books"),
        "minutes": flat("{} minute", "{} minutes"),
        "hours": flat("{} hour", "{} hours"),
    },
    "es": {
        "section_title": "Citas",
        "reminder_title": "Notificación de citas",
        "reminder_desc": "{count} de {books}, una en el intervalo que elijas.",
        "reminder_desc_plain": "Dichos de los libros de la biblioteca, con su fuente.",
        "off": "Desactivado",
        "preview": "Ver una ahora",
        "dismiss": "Cerrar",
        "window_note": "Se programan {n} cada vez que abres la aplicación.",
        "count": flat("{} cita", "{} citas"),
        "books": flat("{} libro", "{} libros"),
        "minutes": flat("{} minuto", "{} minutos"),
        "hours": flat("{} hora", "{} horas"),
    },
    "fr": {
        "section_title": "Citations",
        "reminder_title": "Notification de citation",
        "reminder_desc": "{count} de {books}, une à l’intervalle choisi.",
        "reminder_desc_plain": "Paroles tirées des livres de la bibliothèque, sourcées.",
        "off": "Désactivé",
        "preview": "En voir une maintenant",
        "dismiss": "Fermer",
        "window_note": "{n} sont programmées à chaque ouverture de l’application.",
        "count": flat("{} citation", "{} citations"),
        "books": flat("{} livre", "{} livres"),
        "minutes": flat("{} minute", "{} minutes"),
        "hours": flat("{} heure", "{} heures"),
    },
    "pt": {
        "section_title": "Citações",
        "reminder_title": "Notificação de citação",
        "reminder_desc": "{count} de {books}, uma no intervalo que escolher.",
        "reminder_desc_plain": "Ditos dos livros da biblioteca, com a sua fonte.",
        "off": "Desligado",
        "preview": "Ver uma agora",
        "dismiss": "Fechar",
        "window_note": "{n} são agendadas sempre que abre a aplicação.",
        "count": flat("{} citação", "{} citações"),
        "books": flat("{} livro", "{} livros"),
        "minutes": flat("{} minuto", "{} minutos"),
        "hours": flat("{} hora", "{} horas"),
    },
    "ru": {
        "section_title": "Изречения",
        "reminder_title": "Уведомление с изречением",
        "reminder_desc": "{count} из {books}, по одному через выбранный интервал.",
        "reminder_desc_plain": "Изречения из книг библиотеки, с указанием источника.",
        "off": "Выключено",
        "preview": "Показать сейчас",
        "dismiss": "Закрыть",
        "window_note": "{n} готовится при каждом открытии приложения.",
        "count": flat("{} изречение", "{} изречений", few="{} изречения",
                      many="{} изречений"),
        "books": flat("{} книга", "{} книг", few="{} книги", many="{} книг"),
        "minutes": flat("{} минута", "{} минут", few="{} минуты",
                        many="{} минут"),
        "hours": flat("{} час", "{} часов", few="{} часа", many="{} часов"),
    },
    "ur": {
        "section_title": "اقوال",
        "reminder_title": "قول کی اطلاع",
        "reminder_desc": "{books} سے {count}، آپ کے منتخب وقفے پر ایک۔",
        "reminder_desc_plain": "لائبریری کی اپنی کتابوں سے اقوال، حوالے کے ساتھ۔",
        "off": "بند",
        "preview": "ابھی ایک دکھائیں",
        "dismiss": "بند کریں",
        "window_note": "ہر بار ایپ کھولنے پر {n} تیار کی جاتی ہیں۔",
        "count": flat("{} قول", "{} اقوال"),
        "books": flat("{} کتاب", "{} کتابیں"),
        "minutes": flat("{} منٹ", "{} منٹ"),
        "hours": flat("{} گھنٹہ", "{} گھنٹے"),
    },
}

NOTIF = {
    "ar": {
        "quote_channel": "مقولات",
        "quote_channel_desc": "مقولة من كتب المكتبة، كل مدة تختارها",
        "quote_title": "مقولة",
    },
    "en": {
        "quote_channel": "Quotes",
        "quote_channel_desc": "A saying from the library's books, at your chosen interval",
        "quote_title": "A saying",
    },
    "es": {
        "quote_channel": "Citas",
        "quote_channel_desc": "Un dicho de los libros de la biblioteca, en el intervalo que elijas",
        "quote_title": "Una cita",
    },
    "fr": {
        "quote_channel": "Citations",
        "quote_channel_desc": "Une parole tirée des livres de la bibliothèque, à l’intervalle choisi",
        "quote_title": "Une parole",
    },
    "pt": {
        "quote_channel": "Citações",
        "quote_channel_desc": "Um dito dos livros da biblioteca, no intervalo que escolher",
        "quote_title": "Uma citação",
    },
    "ru": {
        "quote_channel": "Изречения",
        "quote_channel_desc": "Изречение из книг библиотеки, через выбранный интервал",
        "quote_title": "Изречение",
    },
    "ur": {
        "quote_channel": "اقوال",
        "quote_channel_desc": "لائبریری کی کتابوں سے ایک قول، آپ کے منتخب وقفے پر",
        "quote_title": "ایک قول",
    },
}


def main():
    for loc in LOCALES:
        path = os.path.join(ROOT, "%s.json" % loc)
        with io.open(path, encoding="utf-8") as f:
            data = json.load(f)
        data["quotes"] = QUOTES[loc]
        data.setdefault("notif", {}).update(NOTIF[loc])
        with io.open(path, "w", encoding="utf-8", newline="\n") as f:
            json.dump(data, f, ensure_ascii=False, indent=2, sort_keys=False)
            f.write("\n")
        print("%s: quotes.* + notif.quote_* written" % loc)


if __name__ == "__main__":
    main()
