# -*- coding: utf-8 -*-
"""The nine compilers' biographies, in all seven locales.

`hadith_imam_bios.dart` held one Arabic paragraph per collection and nothing
else, so on any non-Arabic UI the whole «عن المؤلف» card was Arabic.

These are the app's own prose about a historical figure — birth and death years,
where he was from, what his collection is known for — and CLAUDE.md's line
about not touching scripture does not reach them: no ayah, no hadith, no
grading is being restated. Nothing here is an assessment or a ranking, in any
language, exactly as the Arabic was written.

Hijri years are written in Arabic-Indic digits in Arabic and in Latin digits
elsewhere, with the era marked the way each language marks it (`هـ`, `AH`,
`г. х.`, `ھ`).
"""

import collections
import io
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TR = os.path.join(ROOT, "rafeeq_app", "assets", "translations")

BIOS = {
    "bukhari": {
        "ar": "وُلد ببخارى سنة ١٩٤هـ وتوفي سنة ٢٥٦هـ. رحل في طلب الحديث إلى الحجاز "
              "والشام والعراق ومصر، وجمع «الجامع الصحيح» واشترط فيه أعلى درجات "
              "الاتصال في السند.",
        "en": "Born in Bukhara in 194 AH, died in 256 AH. He travelled in search of "
              "hadith to the Hijaz, Syria, Iraq and Egypt, and compiled al-Jami' "
              "as-Sahih, for which he required the highest degree of continuity in "
              "the chain of transmission.",
        "es": "Nació en Bujará en 194 AH y murió en 256 AH. Viajó en busca del hadiz "
              "al Hiyaz, Siria, Irak y Egipto, y compiló Al-Yami' as-Sahih, "
              "exigiendo en él el grado más alto de continuidad en la cadena de "
              "transmisión.",
        "fr": "Né à Boukhara en 194 AH, mort en 256 AH. Il voyagea à la recherche du "
              "hadith au Hedjaz, en Syrie, en Irak et en Égypte, et compila "
              "al-Jami' as-Sahih, pour lequel il exigea le plus haut degré de "
              "continuité dans la chaîne de transmission.",
        "pt": "Nasceu em Bucara em 194 AH e morreu em 256 AH. Viajou em busca do "
              "hadith para o Hijaz, a Síria, o Iraque e o Egito, e compilou "
              "al-Jami' as-Sahih, no qual exigiu o mais alto grau de continuidade "
              "na cadeia de transmissão.",
        "ru": "Родился в Бухаре в 194 г. х., умер в 256 г. х. В поисках хадисов "
              "путешествовал в Хиджаз, Шам, Ирак и Египет и составил «аль-Джами‘ "
              "ас-Сахих», поставив условием высшую степень непрерывности иснада.",
        "ur": "بخارا میں 194ھ میں پیدا ہوئے اور 256ھ میں وفات پائی۔ طلبِ حدیث میں "
              "حجاز، شام، عراق اور مصر کا سفر کیا اور «الجامع الصحیح» مرتب کیا، جس "
              "میں سند کے اتصال کا اعلیٰ ترین درجہ شرط رکھا۔"},
    "muslim": {
        "ar": "وُلد بنيسابور سنة ٢٠٤هـ وتوفي سنة ٢٦١هـ. تتلمذ على البخاري وغيره، "
              "ورتّب صحيحه على الأبواب وجمع طرق الحديث الواحد في موضع واحد.",
        "en": "Born in Nishapur in 204 AH, died in 261 AH. He studied under "
              "al-Bukhari and others, arranged his Sahih by chapter, and gathered "
              "all the chains of a single hadith in one place.",
        "es": "Nació en Nishapur en 204 AH y murió en 261 AH. Estudió con Al-Bujari "
              "y otros, ordenó su Sahih por capítulos y reunió en un solo lugar "
              "todas las vías de un mismo hadiz.",
        "fr": "Né à Nichapour en 204 AH, mort en 261 AH. Il étudia auprès "
              "d’al-Bukhari et d’autres, organisa son Sahih par chapitres et "
              "rassembla en un même endroit toutes les voies d’un même hadith.",
        "pt": "Nasceu em Nishapur em 204 AH e morreu em 261 AH. Estudou com "
              "al-Bukhari e outros, organizou o seu Sahih por capítulos e reuniu "
              "num único lugar todas as vias de um mesmo hadith.",
        "ru": "Родился в Нишапуре в 204 г. х., умер в 261 г. х. Учился у аль-Бухари "
              "и других, расположил свой «Сахих» по главам и собрал все пути одного "
              "хадиса в одном месте.",
        "ur": "نیشاپور میں 204ھ میں پیدا ہوئے اور 261ھ میں وفات پائی۔ امام بخاری اور "
              "دیگر سے تلمذ کیا، اپنی صحیح کو ابواب پر مرتب کیا اور ایک حدیث کے تمام "
              "طرق ایک ہی مقام پر جمع کیے۔"},
    "abudawud": {
        "ar": "وُلد بسجستان سنة ٢٠٢هـ وتوفي بالبصرة سنة ٢٧٥هـ. عُني في سننه بأحاديث "
              "الأحكام الفقهية، وهو أحد الكتب الستة.",
        "en": "Born in Sijistan in 202 AH, died in Basra in 275 AH. His Sunan "
              "concentrates on the hadiths of legal rulings, and is one of the Six "
              "Books.",
        "es": "Nació en Siyistán en 202 AH y murió en Basora en 275 AH. Su Sunan se "
              "centra en los hadices de normas jurídicas y es uno de los Seis "
              "Libros.",
        "fr": "Né au Sijistan en 202 AH, mort à Bassora en 275 AH. Son Sunan se "
              "concentre sur les hadiths des règles juridiques et compte parmi les "
              "Six Livres.",
        "pt": "Nasceu em Sijistão em 202 AH e morreu em Baçorá em 275 AH. O seu "
              "Sunan concentra-se nos hadiths das normas jurídicas e é um dos Seis "
              "Livros.",
        "ru": "Родился в Сиджистане в 202 г. х., умер в Басре в 275 г. х. Его "
              "«Сунан» посвящён хадисам правовых норм и входит в число Шести книг.",
        "ur": "سجستان میں 202ھ میں پیدا ہوئے اور 275ھ میں بصرہ میں وفات پائی۔ اپنی "
              "سنن میں احکامِ فقہیہ کی احادیث پر توجہ دی، اور یہ کتبِ ستہ میں سے ایک "
              "ہے۔"},
    "tirmidhi": {
        "ar": "وُلد بترمذ سنة ٢٠٩هـ وتوفي سنة ٢٧٩هـ. تميّز جامعه بذكر اختلاف الفقهاء "
              "ومذاهبهم عقب الأحاديث، وبالتعليق على أسانيدها.",
        "en": "Born in Tirmidh in 209 AH, died in 279 AH. His Jami' is distinguished "
              "by noting the jurists' differences and their schools after each "
              "hadith, and by commenting on its chain.",
        "es": "Nació en Tirmid en 209 AH y murió en 279 AH. Su Yami' destaca por "
              "señalar tras cada hadiz las diferencias de los juristas y sus "
              "escuelas, y por comentar sus cadenas.",
        "fr": "Né à Tirmidh en 209 AH, mort en 279 AH. Son Jami' se distingue en "
              "indiquant après chaque hadith les divergences des juristes et leurs "
              "écoles, et en commentant les chaînes.",
        "pt": "Nasceu em Tirmid em 209 AH e morreu em 279 AH. O seu Jami' "
              "distingue-se por indicar após cada hadith as divergências dos "
              "juristas e as suas escolas, e por comentar as cadeias.",
        "ru": "Родился в Термезе в 209 г. х., умер в 279 г. х. Его «Джами‘» "
              "отличается тем, что после каждого хадиса приводит расхождения "
              "правоведов и их школ и разбирает иснад.",
        "ur": "ترمذ میں 209ھ میں پیدا ہوئے اور 279ھ میں وفات پائی۔ ان کی جامع کی "
              "خصوصیت یہ ہے کہ ہر حدیث کے بعد فقہا کے اختلاف اور مذاہب ذکر کرتے ہیں "
              "اور اسانید پر کلام کرتے ہیں۔"},
    "nasai": {
        "ar": "وُلد بنسا من خراسان سنة ٢١٥هـ وتوفي سنة ٣٠٣هـ. اشتُهر بدقّة نظره في "
              "علل الأسانيد والرجال، وسننه أحد الكتب الستة.",
        "en": "Born in Nasa in Khurasan in 215 AH, died in 303 AH. He was known for "
              "the precision of his eye for hidden defects in chains and narrators; "
              "his Sunan is one of the Six Books.",
        "es": "Nació en Nasa, en Jorasán, en 215 AH y murió en 303 AH. Fue conocido "
              "por su precisión al detectar los defectos ocultos de las cadenas y "
              "de los transmisores; su Sunan es uno de los Seis Libros.",
        "fr": "Né à Nasa, au Khorassan, en 215 AH, mort en 303 AH. Il était réputé "
              "pour la finesse de son examen des défauts cachés des chaînes et des "
              "transmetteurs ; son Sunan compte parmi les Six Livres.",
        "pt": "Nasceu em Nasa, no Khorasan, em 215 AH e morreu em 303 AH. Era "
              "conhecido pela precisão com que detetava os defeitos ocultos das "
              "cadeias e dos transmissores; o seu Sunan é um dos Seis Livros.",
        "ru": "Родился в Насе (Хорасан) в 215 г. х., умер в 303 г. х. Славился "
              "точностью в выявлении скрытых изъянов иснадов и передатчиков; его "
              "«Сунан» входит в Шесть книг.",
        "ur": "خراسان کے شہر نسا میں 215ھ میں پیدا ہوئے اور 303ھ میں وفات پائی۔ "
              "اسانید و رجال کی علتوں میں باریک بینی کے لیے مشہور ہوئے، اور ان کی "
              "سنن کتبِ ستہ میں سے ہے۔"},
    "ibnmajah": {
        "ar": "وُلد بقزوين سنة ٢٠٩هـ وتوفي سنة ٢٧٣هـ. رتّب سننه على الأبواب الفقهية، "
              "وهو سادس الكتب الستة.",
        "en": "Born in Qazwin in 209 AH, died in 273 AH. He arranged his Sunan by "
              "chapters of law; it is the sixth of the Six Books.",
        "es": "Nació en Qazvín en 209 AH y murió en 273 AH. Ordenó su Sunan por "
              "capítulos jurídicos; es el sexto de los Seis Libros.",
        "fr": "Né à Qazwin en 209 AH, mort en 273 AH. Il organisa son Sunan par "
              "chapitres juridiques ; c’est le sixième des Six Livres.",
        "pt": "Nasceu em Qazvin em 209 AH e morreu em 273 AH. Organizou o seu Sunan "
              "por capítulos jurídicos; é o sexto dos Seis Livros.",
        "ru": "Родился в Казвине в 209 г. х., умер в 273 г. х. Расположил свой "
              "«Сунан» по правовым главам; это шестая из Шести книг.",
        "ur": "قزوین میں 209ھ میں پیدا ہوئے اور 273ھ میں وفات پائی۔ اپنی سنن کو فقہی "
              "ابواب پر مرتب کیا، اور یہ کتبِ ستہ میں چھٹی کتاب ہے۔"},
    "ahmed": {
        "ar": "وُلد ببغداد سنة ١٦٤هـ وتوفي سنة ٢٤١هـ، وإليه يُنسب المذهب الحنبلي. "
              "رتّب مسنده على أسماء الصحابة لا على الأبواب.",
        "en": "Born in Baghdad in 164 AH, died in 241 AH; the Hanbali school is named "
              "after him. He arranged his Musnad by the names of the Companions "
              "rather than by chapter.",
        "es": "Nació en Bagdad en 164 AH y murió en 241 AH; la escuela hanbalí lleva "
              "su nombre. Ordenó su Musnad por los nombres de los Compañeros y no "
              "por capítulos.",
        "fr": "Né à Bagdad en 164 AH, mort en 241 AH ; l’école hanbalite porte son "
              "nom. Il organisa son Musnad par les noms des Compagnons plutôt que "
              "par chapitres.",
        "pt": "Nasceu em Bagdade em 164 AH e morreu em 241 AH; a escola hanbali tem "
              "o seu nome. Organizou o seu Musnad pelos nomes dos Companheiros e "
              "não por capítulos.",
        "ru": "Родился в Багдаде в 164 г. х., умер в 241 г. х.; его именем названа "
              "ханбалитская школа. Расположил свой «Муснад» по именам сподвижников, "
              "а не по главам.",
        "ur": "بغداد میں 164ھ میں پیدا ہوئے اور 241ھ میں وفات پائی؛ حنبلی مذہب انہی "
              "کی طرف منسوب ہے۔ اپنی مسند کو ابواب کے بجائے صحابہ کے ناموں پر مرتب "
              "کیا۔"},
    "malik": {
        "ar": "وُلد بالمدينة سنة ٩٣هـ وتوفي بها سنة ١٧٩هـ، وإليه يُنسب المذهب "
              "المالكي. الموطأ من أقدم ما دُوّن، ويجمع الحديث مع عمل أهل المدينة.",
        "en": "Born in Madinah in 93 AH and died there in 179 AH; the Maliki school "
              "is named after him. Al-Muwatta is among the earliest works compiled, "
              "and joins hadith to the practice of the people of Madinah.",
        "es": "Nació en Medina en 93 AH y murió allí en 179 AH; la escuela maliki "
              "lleva su nombre. Al-Muwatta es una de las obras más antiguas "
              "compiladas y une el hadiz a la práctica de la gente de Medina.",
        "fr": "Né à Médine en 93 AH et mort dans cette ville en 179 AH ; l’école "
              "malikite porte son nom. Al-Muwatta compte parmi les plus anciens "
              "ouvrages compilés et joint le hadith à la pratique des gens de "
              "Médine.",
        "pt": "Nasceu em Medina em 93 AH e morreu ali em 179 AH; a escola maliki tem "
              "o seu nome. O Al-Muwatta está entre as obras mais antigas compiladas "
              "e junta o hadith à prática do povo de Medina.",
        "ru": "Родился в Медине в 93 г. х. и умер там же в 179 г. х.; его именем "
              "названа маликитская школа. «Аль-Муватта» — один из древнейших "
              "составленных трудов, соединяющий хадисы с практикой жителей Медины.",
        "ur": "مدینہ میں 93ھ میں پیدا ہوئے اور وہیں 179ھ میں وفات پائی؛ مالکی مذہب "
              "انہی کی طرف منسوب ہے۔ موطأ قدیم ترین مدوَّن کتابوں میں سے ہے، جو حدیث "
              "کو اہلِ مدینہ کے عمل کے ساتھ جمع کرتی ہے۔"},
    "darimi": {
        "ar": "وُلد بسمرقند سنة ١٨١هـ وتوفي سنة ٢٥٥هـ. رتّب سننه على الأبواب، وصدّرها "
              "بمقدمة في العلم وآدابه وفضل النبي ﷺ.",
        "en": "Born in Samarqand in 181 AH, died in 255 AH. He arranged his Sunan by "
              "chapters and opened it with an introduction on knowledge, its "
              "etiquette, and the merits of the Prophet ﷺ.",
        "es": "Nació en Samarcanda en 181 AH y murió en 255 AH. Ordenó su Sunan por "
              "capítulos y lo abrió con una introducción sobre el conocimiento, sus "
              "modales y los méritos del Profeta ﷺ.",
        "fr": "Né à Samarcande en 181 AH, mort en 255 AH. Il organisa son Sunan par "
              "chapitres et l’ouvrit par une introduction sur la science, ses "
              "convenances et les mérites du Prophète ﷺ.",
        "pt": "Nasceu em Samarcanda em 181 AH e morreu em 255 AH. Organizou o seu "
              "Sunan por capítulos e abriu-o com uma introdução sobre o "
              "conhecimento, a sua etiqueta e os méritos do Profeta ﷺ.",
        "ru": "Родился в Самарканде в 181 г. х., умер в 255 г. х. Расположил свой "
              "«Сунан» по главам и предпослал ему введение о знании, его этике и "
              "достоинствах Пророка ﷺ.",
        "ur": "سمرقند میں 181ھ میں پیدا ہوئے اور 255ھ میں وفات پائی۔ اپنی سنن کو "
              "ابواب پر مرتب کیا اور اس کا آغاز علم، اس کے آداب اور فضائلِ نبی ﷺ کے "
              "مقدمے سے کیا۔"},
}

LOCALES = ["ar", "en", "es", "fr", "pt", "ru", "ur"]


def main():
    added = 0
    for code in LOCALES:
        path = os.path.join(TR, "%s.json" % code)
        doc = json.loads(io.open(path, encoding="utf-8").read(),
                         object_pairs_hook=collections.OrderedDict)
        bucket = doc.setdefault("imam_bio", collections.OrderedDict())
        for key, per_locale in BIOS.items():
            if key in bucket:
                continue
            bucket[key] = per_locale[code]
            added += 1
        io.open(path, "w", encoding="utf-8").write(
            json.dumps(doc, ensure_ascii=False, indent=2) + "\n")
    print("added %d key/locale pairs" % added)


if __name__ == "__main__":
    main()
