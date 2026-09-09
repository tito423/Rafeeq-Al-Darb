# -*- coding: utf-8 -*-
"""Content batch 1: the channel catalogue, the adhan video clips, and ruqyah.

These are the app's OWN prose — what a channel is about, what a background clip
shows, where the recordings came from — so they are translated outright, unlike
the azkar bodies, which are duas and scripture and need a sourced translation
rather than mine.

`common.script` is not a string anyone sees. It is how a proper NAME picks its
script without needing a `BuildContext`: `easy_localization`'s `.tr()` reads a
global, so a locale file is the one place a non-widget helper can ask "which
script does this reader read?". Arabic and Urdu are written in Arabic script
and get the Arabic form of a name; the other five get the Latin
transliteration the catalogue already carries. Nobody's name is translated —
`عبد الله رشدي` and `Abdullah Rushdy` are the same name written twice, which
is not the same thing as translating it.
"""

import collections
import io
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TR = os.path.join(ROOT, "rafeeq_app", "assets", "translations")

KEYS = {
    "common": {
        "script": {
            "ar": "arabic", "ur": "arabic",
            "en": "latin", "es": "latin", "fr": "latin",
            "pt": "latin", "ru": "latin"},
    },
    "channels": {
        "desc_mostafa_mahmoud": {
            "ar": "برنامج العلم والإيمان وحلقات الدكتور مصطفى محمود",
            "en": "Science and Faith, and Dr. Mostafa Mahmoud's episodes",
            "es": "Ciencia y Fe, y los episodios del Dr. Mostafa Mahmoud",
            "fr": "Science et Foi, et les émissions du Dr Mostafa Mahmoud",
            "pt": "Ciência e Fé, e os episódios do Dr. Mostafa Mahmoud",
            "ru": "«Наука и вера» и передачи д-ра Мустафы Махмуда",
            "ur": "پروگرام «العلم والإيمان» اور ڈاکٹر مصطفیٰ محمود کی اقساط"},
        "desc_ayman_abdelgelil": {
            "ar": "دروس ومواعظ ولقاءات",
            "en": "Lessons, sermons and interviews",
            "es": "Lecciones, sermones y entrevistas",
            "fr": "Cours, sermons et entretiens",
            "pt": "Lições, sermões e entrevistas",
            "ru": "Уроки, проповеди и беседы",
            "ur": "دروس، مواعظ اور ملاقاتیں"},
        "desc_abdullah_rushdy": {
            "ar": "دروس وردود وبيان مسائل",
            "en": "Lessons, responses and clarifications",
            "es": "Lecciones, respuestas y aclaraciones",
            "fr": "Cours, réponses et clarifications",
            "pt": "Lições, respostas e esclarecimentos",
            "ru": "Уроки, ответы и разъяснения",
            "ur": "دروس، جوابات اور مسائل کی وضاحت"},
        "desc_yasser_alhazimi": {
            "ar": "محاضرات في التزكية وبناء الذات",
            "en": "Talks on self-development and spiritual growth",
            "es": "Charlas sobre desarrollo personal y purificación espiritual",
            "fr": "Conférences sur le développement de soi et la purification spirituelle",
            "pt": "Palestras sobre desenvolvimento pessoal e purificação espiritual",
            "ru": "Лекции о духовном очищении и работе над собой",
            "ur": "تزکیۂ نفس اور تعمیرِ شخصیت پر محاضرات"},
        "desc_mohamed_hassan": {
            "ar": "دروس ومحاضرات وسلاسل علمية",
            "en": "Lessons, lectures and teaching series",
            "es": "Lecciones, conferencias y series formativas",
            "fr": "Cours, conférences et séries d’enseignement",
            "pt": "Lições, conferências e séries de ensino",
            "ru": "Уроки, лекции и учебные циклы",
            "ur": "دروس، محاضرات اور علمی سلسلے"},
        "desc_abu_ishaq_alheweny": {
            "ar": "دروس في الحديث وعلومه",
            "en": "Lessons in hadith and its sciences",
            "es": "Lecciones de hadiz y sus ciencias",
            "fr": "Cours de hadith et de ses sciences",
            "pt": "Lições de hadith e das suas ciências",
            "ru": "Уроки по хадисам и хадисоведению",
            "ur": "حدیث اور اس کے علوم کے دروس"},
        "desc_mostafa_aladwy": {
            "ar": "فتاوى ودروس في التفسير والحديث",
            "en": "Fatwas and lessons in tafsir and hadith",
            "es": "Fatwas y lecciones de tafsir y hadiz",
            "fr": "Fatwas et cours de tafsir et de hadith",
            "pt": "Fatwas e lições de tafsir e hadith",
            "ru": "Фетвы и уроки по тафсиру и хадисам",
            "ur": "فتاویٰ اور تفسیر و حدیث کے دروس"},
    },
    "adhan_video": {
        "source": {
            "ar": "المصدر: Pixabay — رخصة Pixabay (استخدام حر، بلا نسب)",
            "en": "Source: Pixabay — Pixabay licence (free use, no attribution required)",
            "es": "Fuente: Pixabay — licencia Pixabay (uso libre, sin atribución)",
            "fr": "Source : Pixabay — licence Pixabay (usage libre, sans attribution)",
            "pt": "Fonte: Pixabay — licença Pixabay (uso livre, sem atribuição)",
            "ru": "Источник: Pixabay — лицензия Pixabay (свободное использование, без указания авторства)",
            "ur": "ماخذ: Pixabay — Pixabay لائسنس (آزاد استعمال، بغیر انتساب)"},
        "haram_makkah": {
            "ar": "الحرم المكي",
            "en": "The Grand Mosque, Makkah",
            "es": "La Gran Mezquita de La Meca",
            "fr": "La Grande Mosquée de La Mecque",
            "pt": "A Grande Mesquita de Meca",
            "ru": "Заповедная мечеть в Мекке",
            "ur": "مسجدِ حرام، مکہ"},
        "kaaba": {
            "ar": "الكعبة المشرفة",
            "en": "The Kaaba",
            "es": "La Kaaba",
            "fr": "La Kaaba",
            "pt": "A Caaba",
            "ru": "Кааба",
            "ur": "کعبۃ اللہ"},
        "madina_nabawi": {
            "ar": "المسجد النبوي",
            "en": "The Prophet's Mosque, Madinah",
            "es": "La Mezquita del Profeta, Medina",
            "fr": "La Mosquée du Prophète, Médine",
            "pt": "A Mesquita do Profeta, Medina",
            "ru": "Мечеть Пророка в Медине",
            "ur": "مسجدِ نبوی، مدینہ"},
        "mosque_ottoman": {
            "ar": "مسجد عثماني",
            "en": "An Ottoman-style mosque",
            "es": "Una mezquita de estilo otomano",
            "fr": "Une mosquée de style ottoman",
            "pt": "Uma mesquita de estilo otomano",
            "ru": "Мечеть в османском стиле",
            "ur": "عثمانی طرز کی مسجد"},
        "kaaba_tawaf": {
            "ar": "الحرم والكعبة",
            "en": "The Haram and the Kaaba",
            "es": "El Haram y la Kaaba",
            "fr": "Le Haram et la Kaaba",
            "pt": "O Haram e a Caaba",
            "ru": "Харам и Кааба",
            "ur": "حرم اور کعبہ"},
        "haram_makkah2": {
            "ar": "ساحات الحرم المكي",
            "en": "The Grand Mosque courtyards",
            "es": "Los patios de la Gran Mezquita",
            "fr": "Les cours de la Grande Mosquée",
            "pt": "Os pátios da Grande Mesquita",
            "ru": "Дворы Заповедной мечети",
            "ur": "مسجدِ حرام کے صحن"},
        "kaaba_close": {
            "ar": "الكعبة المشرّفة عن قرب",
            "en": "The Kaaba, up close",
            "es": "La Kaaba, de cerca",
            "fr": "La Kaaba, de près",
            "pt": "A Caaba, de perto",
            "ru": "Кааба вблизи",
            "ur": "کعبۃ اللہ، قریب سے"},
        "madina_haram": {
            "ar": "رحاب المسجد النبوي",
            "en": "The Prophet's Mosque grounds",
            "es": "Los recintos de la Mezquita del Profeta",
            "fr": "Les esplanades de la Mosquée du Prophète",
            "pt": "Os recintos da Mesquita do Profeta",
            "ru": "Территория Мечети Пророка",
            "ur": "مسجدِ نبوی کے صحن"},
        "mosque_minaret": {
            "ar": "مئذنة مسجد",
            "en": "A mosque minaret",
            "es": "El alminar de una mezquita",
            "fr": "Le minaret d’une mosquée",
            "pt": "O minarete de uma mesquita",
            "ru": "Минарет мечети",
            "ur": "مسجد کا مینار"},
        "mosque_view": {
            "ar": "رحاب مسجد",
            "en": "A mosque's grounds",
            "es": "El recinto de una mezquita",
            "fr": "L’enceinte d’une mosquée",
            "pt": "O recinto de uma mesquita",
            "ru": "Двор мечети",
            "ur": "مسجد کا صحن"},
    },
    "ruqyah": {
        "rec_tarteel_hadi": {
            "ar": "رقية شرعية — بسماعة الرأس",
            "en": "Ruqyah — for headphones",
            "es": "Ruqyah — para auriculares",
            "fr": "Roqya — pour écouteurs",
            "pt": "Ruqyah — para auscultadores",
            "ru": "Рукья — для наушников",
            "ur": "رقیہ شرعیہ — ہیڈ فون کے لیے"},
        "audio_source": {
            "ar": "التسجيلات من أرشيف الإنترنت (archive.org)، مرآة على خادم التطبيق",
            "en": "The recordings come from the Internet Archive (archive.org), mirrored on the app's own server",
            "es": "Las grabaciones provienen de Internet Archive (archive.org), replicadas en el servidor de la aplicación",
            "fr": "Les enregistrements proviennent d’Internet Archive (archive.org), copiés sur le serveur de l’application",
            "pt": "As gravações vêm do Internet Archive (archive.org), replicadas no servidor da aplicação",
            "ru": "Записи взяты из Интернет-архива (archive.org) и продублированы на сервере приложения",
            "ur": "ریکارڈنگز انٹرنیٹ آرکائیو (archive.org) سے ہیں، ایپ کے اپنے سرور پر محفوظ"},
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
