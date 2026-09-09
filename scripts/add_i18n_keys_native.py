# -*- coding: utf-8 -*-
"""The eight strings Android renders itself, in all seven locales.

`i18n_audit.py` only reads Dart, so none of these were ever on its list — and
every one of them was hardcoded Arabic in Kotlin. On a French UI the notification
channel in the system's own settings read «الأذان»، the adhan alert read
«أذان الظهر / الله أكبر، حان وقت الصلاة» with «إيقاف» and «كتم» buttons, and the
download service's notification was Arabic too.

The rest of what Kotlin needs already had keys and is reused rather than
duplicated: `prayer.adhan`, `prayer.mode_vibrate`, `prayer.mode_silent`,
`prayer.azan_of`, `prayer.stop`, `prayer.mute`, `notif.dl_files_running_title`.
See `lib/core/services/native_strings.dart` for how they are assembled.

«الله أكبر» is left as the app already renders it elsewhere: `prayer.
god_is_greatest` transliterates rather than translates the takbir, and that
decision is followed here rather than reopened.
"""

import collections
import io
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TR = os.path.join(ROOT, "rafeeq_app", "assets", "translations")

KEYS = {
    "notif": {
        "adhan_channel_desc": {
            "ar": "تنبيه الأذان عند دخول وقت الصلاة",
            "en": "The adhan alert when a prayer time begins",
            "es": "El aviso del adhan al entrar el tiempo de la oración",
            "fr": "L’alerte de l’adhan à l’entrée du temps de la prière",
            "pt": "O alerta do adhan quando entra o tempo da oração",
            "ru": "Оповещение азана с наступлением времени молитвы",
            "ur": "نماز کا وقت داخل ہونے پر اذان کی اطلاع"},
        "adhan_channel_vibrate_desc": {
            "ar": "تنبيه بالاهتزاز فقط عند دخول وقت الصلاة",
            "en": "Vibration only, when a prayer time begins",
            "es": "Solo vibración al entrar el tiempo de la oración",
            "fr": "Vibration seule à l’entrée du temps de la prière",
            "pt": "Apenas vibração quando entra o tempo da oração",
            "ru": "Только вибрация с наступлением времени молитвы",
            "ur": "نماز کا وقت داخل ہونے پر صرف ارتعاش"},
        "adhan_channel_silent_desc": {
            "ar": "تنبيه صامت عند دخول وقت الصلاة، بلا صوت أو اهتزاز",
            "en": "A silent alert when a prayer time begins — no sound, no vibration",
            "es": "Un aviso silencioso al entrar el tiempo de la oración, sin sonido ni vibración",
            "fr": "Une alerte silencieuse à l’entrée du temps de la prière, sans son ni vibration",
            "pt": "Um alerta silencioso quando entra o tempo da oração, sem som nem vibração",
            "ru": "Беззвучное оповещение с наступлением времени молитвы — без звука и вибрации",
            "ur": "نماز کا وقت داخل ہونے پر خاموش اطلاع — نہ آواز، نہ ارتعاش"},
        "adhan_body": {
            "ar": "الله أكبر، حان وقت الصلاة",
            "en": "Allahu Akbar — it is time for prayer",
            "es": "Allahu Akbar — es hora de la oración",
            "fr": "Allahou Akbar — c’est l’heure de la prière",
            "pt": "Allahu Akbar — é hora da oração",
            "ru": "Аллаху акбар — настало время молитвы",
            "ur": "اللہ اکبر — نماز کا وقت ہو گیا"},
        "adhan_body_muted": {
            "ar": "مكتوم — الله أكبر، حان وقت الصلاة",
            "en": "Muted — Allahu Akbar, it is time for prayer",
            "es": "Silenciado — Allahu Akbar, es hora de la oración",
            "fr": "En sourdine — Allahou Akbar, c’est l’heure de la prière",
            "pt": "Silenciado — Allahu Akbar, é hora da oração",
            "ru": "Звук выключен — Аллаху акбар, настало время молитвы",
            "ur": "خاموش — اللہ اکبر، نماز کا وقت ہو گیا"},
        "dl_service_channel": {
            "ar": "تنزيل المحتوى في الخلفية",
            "en": "Background downloading",
            "es": "Descarga en segundo plano",
            "fr": "Téléchargement en arrière-plan",
            "pt": "Transferência em segundo plano",
            "ru": "Загрузка в фоновом режиме",
            "ur": "پس منظر میں ڈاؤن لوڈ"},
        "dl_service_channel_desc": {
            "ar": "يبقي التطبيق نشطًا أثناء تنزيل المحتوى في الخلفية",
            "en": "Keeps the app alive while content downloads in the background",
            "es": "Mantiene la aplicación activa mientras el contenido se descarga en segundo plano",
            "fr": "Garde l’application active pendant le téléchargement en arrière-plan",
            "pt": "Mantém a aplicação ativa enquanto o conteúdo é transferido em segundo plano",
            "ru": "Держит приложение активным, пока контент загружается в фоне",
            "ur": "پس منظر میں مواد ڈاؤن لوڈ ہوتے وقت ایپ کو فعال رکھتا ہے"},
        "dl_service_body": {
            "ar": "يتابع التطبيق التنزيل في الخلفية",
            "en": "The app is continuing the download in the background",
            "es": "La aplicación continúa la descarga en segundo plano",
            "fr": "L’application poursuit le téléchargement en arrière-plan",
            "pt": "A aplicação continua a transferência em segundo plano",
            "ru": "Приложение продолжает загрузку в фоновом режиме",
            "ur": "ایپ پس منظر میں ڈاؤن لوڈ جاری رکھے ہوئے ہے"},
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
