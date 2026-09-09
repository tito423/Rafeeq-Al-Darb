# -*- coding: utf-8 -*-
"""Adds the notification + Hijri-month keys to all seven locale files.

Every string here was hardcoded in Arabic inside a service, so the app's
notifications arrived in Arabic no matter what language the user had chosen -
the owner's «مش عايز حاجة اسمها اللغة تبقى مثلا فرنساوي والاقي شاشة وحدة مش
مترجمة».

The Hijri month names live in ONE place now: they were duplicated between
`home_screen.dart` and `prayer_status_notification.dart`, in Arabic, in both.
"""

import collections
import io
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TR = os.path.join(ROOT, "rafeeq_app", "assets", "translations")

# section -> key -> {locale: text}
KEYS = {
    "notif": {
        "azkar_channel": {
            "ar": "تذكير الأذكار", "en": "Adhkar reminder",
            "es": "Recordatorio de adhkar", "fr": "Rappel des adhkar",
            "pt": "Lembrete de adhkar", "ru": "Напоминание об азкарах",
            "ur": "اذکار کی یاد دہانی"},
        "azkar_channel_desc": {
            "ar": "تذكير يومي بأذكار الصباح والمساء في الوقت الذي تحدده",
            "en": "A daily reminder for the morning and evening adhkar, at the time you choose",
            "es": "Recordatorio diario de los adhkar de la mañana y la tarde, a la hora que elijas",
            "fr": "Un rappel quotidien des adhkar du matin et du soir, à l’heure que vous choisissez",
            "pt": "Um lembrete diário dos adhkar da manhã e da tarde, à hora que escolher",
            "ru": "Ежедневное напоминание об утренних и вечерних азкарах в выбранное вами время",
            "ur": "صبح و شام کے اذکار کی روزانہ یاد دہانی، آپ کے مقرر کردہ وقت پر"},
        "azkar_morning_title": {
            "ar": "أذكار الصباح", "en": "Morning adhkar",
            "es": "Adhkar de la mañana", "fr": "Adhkar du matin",
            "pt": "Adhkar da manhã", "ru": "Утренние азкары",
            "ur": "صبح کے اذکار"},
        "azkar_morning_body": {
            "ar": "حان وقت أذكار الصباح", "en": "It is time for the morning adhkar",
            "es": "Es hora de los adhkar de la mañana",
            "fr": "C’est l’heure des adhkar du matin",
            "pt": "É hora dos adhkar da manhã",
            "ru": "Время утренних азкаров",
            "ur": "صبح کے اذکار کا وقت ہو گیا"},
        "azkar_evening_title": {
            "ar": "أذكار المساء", "en": "Evening adhkar",
            "es": "Adhkar de la tarde", "fr": "Adhkar du soir",
            "pt": "Adhkar da tarde", "ru": "Вечерние азкары",
            "ur": "شام کے اذکار"},
        "azkar_evening_body": {
            "ar": "حان وقت أذكار المساء", "en": "It is time for the evening adhkar",
            "es": "Es hora de los adhkar de la tarde",
            "fr": "C’est l’heure des adhkar du soir",
            "pt": "É hora dos adhkar da tarde",
            "ru": "Время вечерних азкаров",
            "ur": "شام کے اذکار کا وقت ہو گیا"},

        "khatma_channel": {
            "ar": "تذكير الختمة", "en": "Khatma reminder",
            "es": "Recordatorio de la jatma", "fr": "Rappel de la khatma",
            "pt": "Lembrete da khatma", "ru": "Напоминание о хатме",
            "ur": "ختم قرآن کی یاد دہانی"},
        "khatma_channel_desc": {
            "ar": "تذكير يومي بقراءة وردك من الختمة في الوقت الذي تحدده",
            "en": "A daily reminder to read your khatma portion, at the time you choose",
            "es": "Recordatorio diario para leer tu porción de la jatma, a la hora que elijas",
            "fr": "Un rappel quotidien pour lire votre portion de la khatma, à l’heure que vous choisissez",
            "pt": "Um lembrete diário para ler a sua porção da khatma, à hora que escolher",
            "ru": "Ежедневное напоминание прочитать свою долю хатмы в выбранное вами время",
            "ur": "اپنا روزانہ کا حصہ پڑھنے کی یاد دہانی، آپ کے مقرر کردہ وقت پر"},
        "khatma_title": {
            "ar": "ورد الختمة", "en": "Your daily portion",
            "es": "Tu porción diaria", "fr": "Votre portion du jour",
            "pt": "A sua porção diária", "ru": "Ваша дневная доля",
            "ur": "آج کا ورد"},
        "khatma_body": {
            "ar": "حان وقت وردك من القرآن اليوم",
            "en": "It is time for today's portion of the Qur'an",
            "es": "Es hora de tu porción del Corán de hoy",
            "fr": "C’est l’heure de votre portion du Coran d’aujourd’hui",
            "pt": "É hora da sua porção do Alcorão de hoje",
            "ru": "Время прочитать сегодняшнюю долю Корана",
            "ur": "آج کے قرآنی ورد کا وقت ہو گیا"},

        "sunan_channel": {
            "ar": "تذكير سنن السور", "en": "Surah sunnah reminder",
            "es": "Recordatorio de las sunan de las suras",
            "fr": "Rappel des sunna des sourates",
            "pt": "Lembrete das sunan das suratas",
            "ru": "Напоминание о сунне сур",
            "ur": "سنن سور کی یاد دہانی"},
        "sunan_channel_desc": {
            "ar": "تذكير أسبوعي بقراءة سنن السور في وقتها",
            "en": "A weekly reminder to read the surahs recommended at their time",
            "es": "Recordatorio semanal para leer las suras recomendadas a su hora",
            "fr": "Un rappel hebdomadaire pour lire les sourates recommandées à leur moment",
            "pt": "Um lembrete semanal para ler as suratas recomendadas na sua altura",
            "ru": "Еженедельное напоминание прочитать рекомендованные суры в своё время",
            "ur": "اپنے وقت پر سنن سور پڑھنے کی ہفتہ وار یاد دہانی"},
        "sunan_body": {
            "ar": "حان وقت وردك من سنن السور",
            "en": "It is time for your surah sunnah reading",
            "es": "Es hora de tu lectura de las sunan de las suras",
            "fr": "C’est l’heure de votre lecture des sunna des sourates",
            "pt": "É hora da sua leitura das sunan das suratas",
            "ru": "Время вашего чтения сунны сур",
            "ur": "سنن سور کے ورد کا وقت ہو گیا"},

        "prayer_channel": {
            "ar": "بطاقة الصلاة القادمة", "en": "Next prayer card",
            "es": "Tarjeta de la próxima oración", "fr": "Carte de la prochaine prière",
            "pt": "Cartão da próxima oração", "ru": "Карточка следующей молитвы",
            "ur": "اگلی نماز کا کارڈ"},
        "prayer_channel_desc": {
            "ar": "إشعار ثابت يعرض الصلاة القادمة والتاريخ الهجري وعدّاداً تنازلياً",
            "en": "A persistent notification showing the next prayer, the Hijri date and a countdown",
            "es": "Notificación fija con la próxima oración, la fecha hégira y una cuenta atrás",
            "fr": "Une notification permanente indiquant la prochaine prière, la date hégirienne et un compte à rebours",
            "pt": "Uma notificação fixa com a próxima oração, a data hégira e uma contagem decrescente",
            "ru": "Постоянное уведомление со следующей молитвой, датой по хиджре и обратным отсчётом",
            "ur": "مستقل اطلاع جو اگلی نماز، ہجری تاریخ اور الٹی گنتی دکھاتی ہے"},
        "prayer_enable_location": {
            "ar": "فعّل الموقع لعرض مواقيت الصلاة",
            "en": "Turn on location to show prayer times",
            "es": "Activa la ubicación para ver los horarios de oración",
            "fr": "Activez la localisation pour afficher les horaires de prière",
            "pt": "Ative a localização para ver os horários de oração",
            "ru": "Включите геолокацию, чтобы видеть время молитв",
            "ur": "نماز کے اوقات دیکھنے کے لیے مقام آن کریں"},

        "dl_files_running_title": {
            "ar": "جارٍ التنزيل", "en": "Downloading",
            "es": "Descargando", "fr": "Téléchargement en cours",
            "pt": "A transferir", "ru": "Загрузка", "ur": "ڈاؤن لوڈ جاری"},
        "dl_files_running_body": {
            "ar": "الملفات المكتملة: {numFinished} من {numTotal}",
            "en": "Files completed: {numFinished} of {numTotal}",
            "es": "Archivos completados: {numFinished} de {numTotal}",
            "fr": "Fichiers terminés : {numFinished} sur {numTotal}",
            "pt": "Ficheiros concluídos: {numFinished} de {numTotal}",
            "ru": "Готово файлов: {numFinished} из {numTotal}",
            "ur": "مکمل فائلیں: {numFinished} از {numTotal}"},
        "dl_files_complete_title": {
            "ar": "اكتمل التنزيل", "en": "Download complete",
            "es": "Descarga completada", "fr": "Téléchargement terminé",
            "pt": "Transferência concluída", "ru": "Загрузка завершена",
            "ur": "ڈاؤن لوڈ مکمل"},
        "dl_files_complete_body": {
            "ar": "المحتوى جاهز للاستخدام بدون إنترنت",
            "en": "The content is ready to use offline",
            "es": "El contenido está listo para usar sin conexión",
            "fr": "Le contenu est prêt à être utilisé hors connexion",
            "pt": "O conteúdo está pronto para usar sem ligação",
            "ru": "Материалы готовы к работе без интернета",
            "ur": "مواد آف لائن استعمال کے لیے تیار ہے"},
        "dl_files_error_title": {
            "ar": "تعذّر التنزيل", "en": "Download failed",
            "es": "No se pudo descargar", "fr": "Échec du téléchargement",
            "pt": "Falha na transferência", "ru": "Не удалось загрузить",
            "ur": "ڈاؤن لوڈ ناکام"},
        "dl_files_error_body": {
            "ar": "تعذّر إكمال بعض الملفات", "en": "Some files could not be completed",
            "es": "Algunos archivos no se pudieron completar",
            "fr": "Certains fichiers n’ont pas pu être terminés",
            "pt": "Alguns ficheiros não puderam ser concluídos",
            "ru": "Некоторые файлы не удалось загрузить",
            "ur": "کچھ فائلیں مکمل نہیں ہو سکیں"},
        "dl_paused_title": {
            "ar": "التنزيل متوقف مؤقتًا", "en": "Download paused",
            "es": "Descarga en pausa", "fr": "Téléchargement en pause",
            "pt": "Transferência em pausa", "ru": "Загрузка приостановлена",
            "ur": "ڈاؤن لوڈ روک دیا گیا"},
        "dl_paused_body": {
            "ar": "اضغط للمتابعة", "en": "Tap to resume",
            "es": "Toca para reanudar", "fr": "Touchez pour reprendre",
            "pt": "Toque para retomar", "ru": "Нажмите, чтобы продолжить",
            "ur": "جاری رکھنے کے لیے دبائیں"},

        "dl_recit_running_title": {
            "ar": "تنزيل التلاوة", "en": "Downloading the recitation",
            "es": "Descargando la recitación", "fr": "Téléchargement de la récitation",
            "pt": "A transferir a recitação", "ru": "Загрузка чтения",
            "ur": "تلاوت ڈاؤن لوڈ ہو رہی ہے"},
        "dl_recit_running_body": {
            "ar": "الآيات المكتملة: {numFinished} من {numTotal}",
            "en": "Verses completed: {numFinished} of {numTotal}",
            "es": "Aleyas completadas: {numFinished} de {numTotal}",
            "fr": "Versets terminés : {numFinished} sur {numTotal}",
            "pt": "Versículos concluídos: {numFinished} de {numTotal}",
            "ru": "Готово аятов: {numFinished} из {numTotal}",
            "ur": "مکمل آیات: {numFinished} از {numTotal}"},
        "dl_recit_complete_title": {
            "ar": "اكتملت التلاوة", "en": "Recitation complete",
            "es": "Recitación completada", "fr": "Récitation terminée",
            "pt": "Recitação concluída", "ru": "Чтение загружено",
            "ur": "تلاوت مکمل"},
        "dl_recit_complete_body": {
            "ar": "التلاوة جاهزة للاستماع بدون إنترنت",
            "en": "The recitation is ready to play offline",
            "es": "La recitación está lista para escuchar sin conexión",
            "fr": "La récitation est prête à être écoutée hors connexion",
            "pt": "A recitação está pronta para ouvir sem ligação",
            "ru": "Чтение готово к прослушиванию без интернета",
            "ur": "تلاوت آف لائن سننے کے لیے تیار ہے"},
        "dl_recit_error_title": {
            "ar": "تعذّر تنزيل التلاوة", "en": "Recitation download failed",
            "es": "No se pudo descargar la recitación",
            "fr": "Échec du téléchargement de la récitation",
            "pt": "Falha ao transferir a recitação",
            "ru": "Не удалось загрузить чтение",
            "ur": "تلاوت ڈاؤن لوڈ ناکام"},
        "dl_recit_error_body": {
            "ar": "تعذّر إكمال بعض الآيات", "en": "Some verses could not be completed",
            "es": "Algunas aleyas no se pudieron completar",
            "fr": "Certains versets n’ont pas pu être terminés",
            "pt": "Alguns versículos não puderam ser concluídos",
            "ru": "Некоторые аяты не удалось загрузить",
            "ur": "کچھ آیات مکمل نہیں ہو سکیں"},
        "dl_recit_paused_title": {
            "ar": "تنزيل التلاوة متوقف", "en": "Recitation download paused",
            "es": "Descarga de la recitación en pausa",
            "fr": "Téléchargement de la récitation en pause",
            "pt": "Transferência da recitação em pausa",
            "ru": "Загрузка чтения приостановлена",
            "ur": "تلاوت کا ڈاؤن لوڈ روک دیا گیا"},

        "dl_done": {
            "ar": "تم التنزيل — جاهز للاستخدام بدون إنترنت",
            "en": "Downloaded — ready to use offline",
            "es": "Descargado: listo para usar sin conexión",
            "fr": "Téléchargé — prêt à être utilisé hors connexion",
            "pt": "Transferido — pronto para usar sem ligação",
            "ru": "Загружено — готово к работе без интернета",
            "ur": "ڈاؤن لوڈ ہو گیا — آف لائن استعمال کے لیے تیار"},
        "dl_not_found": {
            "ar": "الملف غير موجود على الخادم (404)",
            "en": "The file is not on the server (404)",
            "es": "El archivo no está en el servidor (404)",
            "fr": "Le fichier est introuvable sur le serveur (404)",
            "pt": "O ficheiro não está no servidor (404)",
            "ru": "Файла нет на сервере (404)",
            "ur": "فائل سرور پر موجود نہیں (404)"},
        "dl_failed": {
            "ar": "تعذّر التنزيل", "en": "Download failed",
            "es": "No se pudo descargar", "fr": "Échec du téléchargement",
            "pt": "Falha na transferência", "ru": "Не удалось загрузить",
            "ur": "ڈاؤن لوڈ ناکام"},
    },

    # The twelve Hijri months, in one place. They were duplicated between the
    # Home screen and the prayer notification, hardcoded in Arabic in both.
    "hijri": {
        "m1": {"ar": "محرم", "en": "Muharram", "es": "Muharram", "fr": "Mouharram",
               "pt": "Muharram", "ru": "Мухаррам", "ur": "محرم"},
        "m2": {"ar": "صفر", "en": "Safar", "es": "Safar", "fr": "Safar",
               "pt": "Safar", "ru": "Сафар", "ur": "صفر"},
        "m3": {"ar": "ربيع الأول", "en": "Rabi' al-Awwal", "es": "Rabi al-Awwal",
               "fr": "Rabi al-Awwal", "pt": "Rabi al-Awwal",
               "ru": "Раби аль-авваль", "ur": "ربیع الاول"},
        "m4": {"ar": "ربيع الآخر", "en": "Rabi' al-Thani", "es": "Rabi al-Zani",
               "fr": "Rabi al-Thani", "pt": "Rabi al-Thani",
               "ru": "Раби ас-сани", "ur": "ربیع الآخر"},
        "m5": {"ar": "جمادى الأولى", "en": "Jumada al-Ula", "es": "Yumada al-Ula",
               "fr": "Joumada al-Oula", "pt": "Jumada al-Ula",
               "ru": "Джумада аль-уля", "ur": "جمادی الاول"},
        "m6": {"ar": "جمادى الآخرة", "en": "Jumada al-Akhirah",
               "es": "Yumada al-Ajira", "fr": "Joumada al-Akhira",
               "pt": "Jumada al-Akhira", "ru": "Джумада аль-ахира",
               "ur": "جمادی الآخر"},
        "m7": {"ar": "رجب", "en": "Rajab", "es": "Rayab", "fr": "Rajab",
               "pt": "Rajab", "ru": "Раджаб", "ur": "رجب"},
        "m8": {"ar": "شعبان", "en": "Sha'ban", "es": "Shaaban", "fr": "Chaabane",
               "pt": "Chaabane", "ru": "Шабан", "ur": "شعبان"},
        "m9": {"ar": "رمضان", "en": "Ramadan", "es": "Ramadán", "fr": "Ramadan",
               "pt": "Ramadão", "ru": "Рамадан", "ur": "رمضان"},
        "m10": {"ar": "شوال", "en": "Shawwal", "es": "Shawwal", "fr": "Chawwal",
                "pt": "Shawwal", "ru": "Шавваль", "ur": "شوال"},
        "m11": {"ar": "ذو القعدة", "en": "Dhu al-Qi'dah", "es": "Du al-Qada",
                "fr": "Dhou al-Qida", "pt": "Dhu al-Qida",
                "ru": "Зуль-каада", "ur": "ذوالقعدہ"},
        "m12": {"ar": "ذو الحجة", "en": "Dhu al-Hijjah", "es": "Du al-Hiyya",
                "fr": "Dhou al-Hijja", "pt": "Dhu al-Hijja",
                "ru": "Зуль-хиджа", "ur": "ذوالحجہ"},
    },
}

LOCALES = ["ar", "en", "es", "fr", "pt", "ru", "ur"]


def main():
    added = 0
    for code in LOCALES:
        path = os.path.join(TR, "%s.json" % code)
        doc = json.loads(io.open(path, encoding="utf-8").read(),
                         object_pairs_hook=collections.OrderedDict)
        for section, keys in KEYS.items():
            bucket = doc.setdefault(section, collections.OrderedDict())
            for key, per_locale in keys.items():
                if key in bucket:
                    continue
                assert code in per_locale, "%s.%s missing %s" % (section, key, code)
                bucket[key] = per_locale[code]
                added += 1
        io.open(path, "w", encoding="utf-8").write(
            json.dumps(doc, ensure_ascii=False, indent=2) + "\n")
    print("added %d key/locale pairs across %d locales" % (added, len(LOCALES)))


if __name__ == "__main__":
    main()
