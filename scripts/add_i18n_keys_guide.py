# -*- coding: utf-8 -*-
"""The New Muslim Guide in all seven locales.

`guide_content.dart` was written bilingual by hand — `titleAr`/`titleEn`,
`headingAr`/`headingEn`, `bodyAr`/`bodyEn` — and the screens picked with
`languageCode == 'ar'`. So a Spanish, French, Portuguese, Russian **or Urdu**
reader opened «دليل المسلم الجديد» and got English. The file's own doc comment
says it is deliberately outside the key system "because this is religious
content, not app chrome"; that reasoning holds for the *recitations* and not
for the instructions around them, which is where this splits.

WHAT IS TRANSLATED: the 5 section titles, the 32 step headings and the 32
instructional bodies. This is the app's own explanatory prose — "wash the right
arm to the elbow three times" — universally agreed and taught identically
everywhere, as the file already says. Nothing here restates an ayah or a hadith.

WHAT IS NOT: the 10 `phraseAr` values — «أَشْهَدُ أَنْ لَا إِلَهَ إِلَّا اللَّهُ»,
«سُبْحَانَ رَبِّيَ الْعَظِيمِ», the tashahhud. Those are what the reader SAYS,
fully diacritised and set in the Quran font. They stay Arabic for the same
reason an ayah on a mushaf page does (CLAUDE.md §1.2), and a meaning line under
them would need a sourced translation, not one written here.

The Arabic and English are not retyped: this script reads them out of
`guide_content.dart` in file order and writes them straight into `ar.json` and
`en.json`. Only the five other languages are written by hand below. That way a
transcription slip cannot silently change what already shipped, and the key
order is checked against the file rather than assumed — the script fails if the
count does not match.
"""

import collections
import io
import json
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TR = os.path.join(ROOT, "rafeeq_app", "assets", "translations")
SRC = os.path.join(ROOT, "rafeeq_app", "lib", "features", "new_muslim",
                   "data", "guide_content.dart")

# The keys, in the order the fields appear in the Dart file.
SECTIONS = [
    ("pillars", 5),
    ("iman", 6),
    ("wudu", 8),
    ("prayer", 10),
    ("quran", 3),
]

# es / fr / pt / ru / ur, in the same order.
OTHER = {
    "pillars_title": [
        "Pilares del islam",
        "Piliers de l’islam",
        "Pilares do islão",
        "Столпы ислама",
        "ارکانِ اسلام"],
    "pillars_1_h": [
        "1. Los dos testimonios (Shahada)",
        "1. Les deux témoignages (Chahada)",
        "1. Os dois testemunhos (Shahada)",
        "1. Два свидетельства (шахада)",
        "١. شہادتین"],
    "pillars_1_b": [
        "Testificar que no hay más dios que Alá, único y sin socio, y que Mahoma es Su siervo y Su mensajero. Con estos dos testimonios la persona entra en el islam: se creen en el corazón y se pronuncian con la lengua.",
        "Témoigner qu’il n’y a de dieu qu’Allah, seul et sans associé, et que Mohammed est Son serviteur et Son messager. C’est par ces deux témoignages que l’on entre en islam : crus dans le cœur et prononcés par la langue.",
        "Testemunhar que não há deus senão Allah, único e sem sócio, e que Muhammad é Seu servo e Seu mensageiro. É com estes dois testemunhos que se entra no islão: acreditados no coração e pronunciados com a língua.",
        "Засвидетельствовать, что нет божества, кроме Аллаха, Единого, у Которого нет сотоварища, и что Мухаммад — Его раб и посланник. Этими двумя свидетельствами человек входит в ислам: они принимаются сердцем и произносятся языком.",
        "گواہی دینا کہ اللہ کے سوا کوئی معبود نہیں، وہ اکیلا ہے، اس کا کوئی شریک نہیں، اور یہ کہ محمد ﷺ اس کے بندے اور رسول ہیں۔ انہی دو شہادتوں سے انسان اسلام میں داخل ہوتا ہے: دل سے یقین اور زبان سے اقرار۔"],
    "pillars_2_h": [
        "2. La oración (salat)",
        "2. La prière (salat)",
        "2. A oração (salat)",
        "2. Молитва (салят)",
        "٢. نماز"],
    "pillars_2_b": [
        "Cinco oraciones obligatorias cada día y cada noche: Fayr, Dhuhr, Asr, Magrib e Isha, cada una en su tiempo fijado. La oración es un vínculo directo entre el siervo y su Señor, y es el pilar del islam. Véase el apartado «Pasos de la oración» de esta guía.",
        "Cinq prières obligatoires chaque jour et chaque nuit : Fajr, Dhuhr, Asr, Maghrib et Isha, chacune à son heure fixée. La prière est un lien direct entre le serviteur et son Seigneur, et c’est le pilier de l’islam. Voir « Étapes de la prière » dans ce guide.",
        "Cinco orações obrigatórias em cada dia e noite: Fajr, Dhuhr, Asr, Maghrib e Isha, cada uma no seu tempo fixado. A oração é um vínculo direto entre o servo e o seu Senhor, e é o pilar do islão. Ver «Passos da oração» neste guia.",
        "Пять обязательных молитв в течение суток: фаджр, зухр, аср, магриб и иша — каждая в своё установленное время. Молитва есть прямая связь между рабом и его Господом и столп ислама. См. раздел «Порядок молитвы» в этом руководстве.",
        "دن رات میں پانچ فرض نمازیں: فجر، ظہر، عصر، مغرب اور عشاء، ہر ایک اپنے مقررہ وقت پر۔ نماز بندے اور اس کے رب کے درمیان براہِ راست تعلق ہے، اور یہ دین کا ستون ہے۔ اس رہنما میں «نماز کے مراحل» کا باب دیکھیں۔"],
    "pillars_3_h": [
        "3. El azaque (zakat)",
        "3. L’aumône obligatoire (zakat)",
        "3. O zakat (caridade obrigatória)",
        "3. Обязательная милостыня (закят)",
        "٣. زکوٰۃ"],
    "pillars_3_b": [
        "Entregar una proporción determinada (habitualmente el 2,5 %) de los bienes que alcanzan un mínimo (el nisab) y que se han poseído durante un año completo, destinada a categorías concretas de necesitados. Purifica los bienes y el alma, y solo es obligatoria para quien posee el nisab.",
        "Verser une part déterminée (généralement 2,5 %) des biens ayant atteint un seuil (le nisab) et détenus pendant une année complète, au profit de catégories précises de nécessiteux. Elle purifie les biens et l’âme, et n’est obligatoire que pour celui qui possède le nisab.",
        "Entregar uma parte determinada (habitualmente 2,5 %) dos bens que atingiram um mínimo (o nisab) e foram detidos durante um ano completo, destinada a categorias específicas de necessitados. Purifica os bens e a alma, e só é obrigatória para quem possui o nisab.",
        "Выплата определённой доли (обычно 2,5 %) с имущества, достигшего установленного минимума (нисаба) и находившегося во владении полный год, в пользу строго определённых категорий нуждающихся. Она очищает имущество и душу и обязательна лишь для того, кто владеет нисабом.",
        "اُس مال میں سے مقررہ حصہ (عموماً ٢.٥٪) نکالنا جو نصاب کو پہنچ جائے اور اس پر پورا سال گزر جائے، اور یہ مخصوص مستحقین پر خرچ ہوتا ہے۔ یہ مال کی طہارت اور نفس کا تزکیہ ہے، اور صرف صاحبِ نصاب پر واجب ہے۔"],
    "pillars_4_h": [
        "4. El ayuno de Ramadán",
        "4. Le jeûne du Ramadan",
        "4. O jejum do Ramadão",
        "4. Пост в Рамадан",
        "٤. رمضان کے روزے"],
    "pillars_4_b": [
        "Abstenerse de comer, beber y de lo demás que rompe el ayuno, desde el alba hasta la puesta del sol, durante todo el mes de Ramadán de cada año islámico. Quien no pueda por una causa reconocida (enfermedad, viaje) tiene concesiones bien definidas en la jurisprudencia.",
        "S’abstenir de manger, de boire et de tout ce qui rompt le jeûne, de l’aube au coucher du soleil, pendant tout le mois de Ramadan de chaque année hégirienne. Celui qui en est empêché pour une raison reconnue (maladie, voyage) bénéficie d’allègements précisés par le fiqh.",
        "Abster-se de comer, beber e de tudo o que quebra o jejum, desde a alvorada até ao pôr do sol, durante todo o mês do Ramadão de cada ano islâmico. Quem esteja impedido por uma causa reconhecida (doença, viagem) tem concessões bem definidas na jurisprudência.",
        "Воздержание от еды, питья и всего, что нарушает пост, от рассвета до заката на протяжении всего месяца Рамадан каждого года по хиджре. Для того, кто не в состоянии поститься по признанной причине (болезнь, поездка), фикх предусматривает чёткие послабления.",
        "ہر ہجری سال کے پورے ماہِ رمضان میں طلوعِ فجر سے غروبِ آفتاب تک کھانے، پینے اور دیگر مفطرات سے رکنا۔ جو شرعی عذر (مثلاً بیماری یا سفر) کی وجہ سے عاجز ہو، اس کے لیے فقہ میں واضح رخصتیں بیان ہوئی ہیں۔"],
    "pillars_5_h": [
        "5. La peregrinación (hach)",
        "5. Le pèlerinage (hajj)",
        "5. A peregrinação (hajj)",
        "5. Паломничество (хадж)",
        "٥. حجِ بیت اللہ"],
    "pillars_5_b": [
        "Visitar la Casa Sagrada de Alá en La Meca para realizar unos ritos determinados, una vez en la vida, para quien tenga medios para ello, física y económicamente. No es obligatoria para quien no puede.",
        "Se rendre à la Maison sacrée d’Allah à La Mecque pour y accomplir des rites déterminés, une fois dans la vie, pour qui en a les moyens physiques et financiers. Elle n’est pas obligatoire pour celui qui ne le peut pas.",
        "Visitar a Casa Sagrada de Allah em Meca para cumprir ritos determinados, uma vez na vida, para quem tenha meios físicos e financeiros. Não é obrigatória para quem não pode.",
        "Посещение Заповедного дома Аллаха в Мекке для совершения определённых обрядов — один раз в жизни, для того, кто способен на это телесно и материально. На неспособного оно не возлагается.",
        "زندگی میں ایک بار مکہ میں بیت اللہ الحرام کی زیارت کر کے مخصوص مناسک ادا کرنا، اُس کے لیے جو جسمانی اور مالی طور پر استطاعت رکھتا ہو۔ جو استطاعت نہ رکھے اس پر واجب نہیں۔"],

    "iman_title": [
        "Pilares de la fe (imán)",
        "Piliers de la foi (îmân)",
        "Pilares da fé (imã)",
        "Столпы веры (иман)",
        "ارکانِ ایمان"],
    "iman_1_h": [
        "1. La fe en Alá",
        "1. La foi en Allah",
        "1. A fé em Allah",
        "1. Вера в Аллаха",
        "١. اللہ پر ایمان"],
    "iman_1_b": [
        "Creer en la existencia de Alá, ensalzado sea, que es el Señor, el Dueño y el Creador de todas las cosas, el único que merece ser adorado, descrito con todos los atributos de perfección y libre de toda imperfección.",
        "Croire en l’existence d’Allah, exalté soit-Il, Seigneur, Souverain et Créateur de toute chose, seul digne d’être adoré, décrit par les attributs de la perfection et exempt de tout défaut.",
        "Crer na existência de Allah, exaltado seja, Senhor, Dono e Criador de todas as coisas, o único que merece ser adorado, descrito com os atributos da perfeição e livre de toda a imperfeição.",
        "Вера в существование Аллаха, Пречист Он и Возвышен, Господа, Владыки и Творца всего сущего, единственного, кто достоин поклонения, обладающего качествами совершенства и лишённого всякого недостатка.",
        "اللہ سبحانہ وتعالیٰ کے وجود پر ایمان لانا، کہ وہی ہر چیز کا رب، مالک اور خالق ہے، اور عبادت کا مستحق صرف وہی ہے، صفاتِ کمال سے متصف اور ہر نقص سے پاک۔"],
    "iman_2_h": [
        "2. La fe en los ángeles",
        "2. La foi aux anges",
        "2. A fé nos anjos",
        "2. Вера в ангелов",
        "٢. ملائکہ پر ایمان"],
    "iman_2_b": [
        "Creer que Alá creó a los ángeles de luz, que son siervos honrados que nunca desobedecen lo que Él les ordena, y que cumplen muchas funciones por Su mandato.",
        "Croire qu’Allah a créé les anges de lumière, qu’ils sont des serviteurs honorés qui ne désobéissent jamais à ce qu’Il leur ordonne, et qu’ils accomplissent de nombreuses tâches par Son commandement.",
        "Crer que Allah criou os anjos de luz, que são servos honrados que nunca desobedecem ao que Ele lhes ordena, e que cumprem muitas funções por Seu comando.",
        "Вера в то, что Аллах сотворил ангелов из света, что они — почтенные рабы, которые не ослушиваются Его повелений и исполняют по Его велению многие обязанности.",
        "ایمان لانا کہ اللہ نے فرشتوں کو نور سے پیدا کیا، وہ مکرم بندے ہیں جو اللہ کے حکم کی نافرمانی نہیں کرتے، اور اس کے حکم سے بہت سے کام انجام دیتے ہیں۔"],
    "iman_3_h": [
        "3. La fe en los Libros revelados",
        "3. La foi aux Livres révélés",
        "3. A fé nos Livros revelados",
        "3. Вера в Писания",
        "٣. کتابوں پر ایمان"],
    "iman_3_b": [
        "Creer que Alá reveló Libros a Sus mensajeros — entre ellos la Torá, el Evangelio y los Salmos — y que el último y sello de todos ellos es el Noble Corán, que confirma y prevalece sobre lo anterior y está preservado de toda alteración.",
        "Croire qu’Allah a révélé des Livres à Ses messagers — dont la Torah, l’Évangile et les Psaumes — et que le dernier d’entre eux, qui les scelle, est le noble Coran, qui prévaut sur ce qui l’a précédé et est préservé de toute altération.",
        "Crer que Allah revelou Livros aos Seus mensageiros — entre eles a Torá, o Evangelho e os Salmos — e que o último e selo de todos é o nobre Alcorão, que prevalece sobre o que veio antes e está preservado de qualquer alteração.",
        "Вера в то, что Аллах ниспослал Своим посланникам Писания — среди них Тора, Евангелие и Псалтырь — и что последним, завершающим их, является благородный Коран, подтверждающий предыдущие и сохранённый от искажения.",
        "ایمان لانا کہ اللہ نے اپنے رسولوں پر کتابیں نازل کیں، جن میں تورات، انجیل اور زبور شامل ہیں، اور ان سب کی آخری اور خاتم قرآن کریم ہے، جو پہلی کتابوں پر نگہبان اور تحریف سے محفوظ ہے۔"],
    "iman_4_h": [
        "4. La fe en los mensajeros",
        "4. La foi aux messagers",
        "4. A fé nos mensageiros",
        "4. Вера в посланников",
        "٤. رسولوں پر ایمان"],
    "iman_4_b": [
        "Creer que Alá envió mensajeros para guiar a los seres humanos, desde Adán hasta Mahoma ﷺ, sello de los profetas y los enviados, tras el cual no hay profeta alguno.",
        "Croire qu’Allah a envoyé des messagers pour guider les hommes, d’Adam à Mohammed ﷺ, sceau des prophètes et des envoyés, après lequel il n’y a plus de prophète.",
        "Crer que Allah enviou mensageiros para guiar os seres humanos, de Adão a Muhammad ﷺ, selo dos profetas e dos enviados, depois do qual não há profeta algum.",
        "Вера в то, что Аллах посылал посланников для наставления людей — от Адама до Мухаммада ﷺ, печати пророков и посланников, после которого нет пророка.",
        "ایمان لانا کہ اللہ نے انسانوں کی ہدایت کے لیے رسول بھیجے، آدم علیہ السلام سے لے کر محمد ﷺ تک، جو خاتم النبیین ہیں اور ان کے بعد کوئی نبی نہیں۔"],
    "iman_5_h": [
        "5. La fe en el Último Día",
        "5. La foi au Jour dernier",
        "5. A fé no Último Dia",
        "5. Вера в Последний день",
        "٥. یومِ آخرت پر ایمان"],
    "iman_5_b": [
        "Creer en la resurrección después de la muerte, en la rendición de cuentas por los actos y luego en la retribución: el Paraíso para quien obedeció a Alá, y el Fuego para quien renegó de Él y Le desobedeció.",
        "Croire en la résurrection après la mort, au règlement des comptes pour les actes, puis à la rétribution : le Paradis pour qui a obéi à Allah, et le Feu pour qui L’a renié et Lui a désobéi.",
        "Crer na ressurreição depois da morte, na prestação de contas pelos atos e depois na retribuição: o Paraíso para quem obedeceu a Allah, e o Fogo para quem O negou e Lhe desobedeceu.",
        "Вера в воскрешение после смерти, в отчёт за деяния и затем в воздаяние: Рай для того, кто повиновался Аллаху, и Огонь для того, кто отверг Его и ослушался.",
        "موت کے بعد دوبارہ اٹھائے جانے، اعمال کے حساب اور پھر جزا پر ایمان: جنت اُس کے لیے جس نے اللہ کی اطاعت کی، اور آگ اُس کے لیے جس نے انکار اور نافرمانی کی۔"],
    "iman_6_h": [
        "6. La fe en el decreto divino (qadar)",
        "6. La foi au décret divin (qadar)",
        "6. A fé no decreto divino (qadar)",
        "6. Вера в предопределение (кадар)",
        "٦. تقدیر پر ایمان"],
    "iman_6_b": [
        "Creer que Alá conoció todas las cosas antes de que ocurrieran, las escribió, las quiso y las creó — lo bueno y lo malo — afirmando al mismo tiempo que el ser humano tiene una elección real por la que será juzgado.",
        "Croire qu’Allah a connu toute chose avant qu’elle n’advienne, l’a inscrite, l’a voulue et l’a créée — le bien comme le mal — tout en affirmant que l’être humain dispose d’un choix réel dont il devra répondre.",
        "Crer que Allah conheceu todas as coisas antes de acontecerem, escreveu-as, quis-as e criou-as — o bem e o mal — afirmando ao mesmo tempo que o ser humano tem uma escolha real pela qual será julgado.",
        "Вера в то, что Аллах знал всё до того, как оно произошло, записал это, пожелал и сотворил — и благое, и дурное — при этом за человеком остаётся действительный выбор, за который он держит ответ.",
        "ایمان لانا کہ اللہ نے ہر چیز کو اس کے وقوع سے پہلے جانا، لکھا، چاہا اور پیدا کیا — خیر بھی اور شر بھی — اس کے ساتھ یہ اقرار بھی کہ انسان کو حقیقی اختیار حاصل ہے جس پر اس سے حساب لیا جائے گا۔"],

    "wudu_title": [
        "La ablución (wudú)",
        "Les ablutions (woudou)",
        "A ablução (wudu)",
        "Малое омовение (вуду)",
        "وضو"],
    "wudu_1_h": [
        "1. La intención y la basmala",
        "1. L’intention et la basmala",
        "1. A intenção e a basmala",
        "1. Намерение и «Бисмиллях»",
        "١. نیت اور بسم اللہ"],
    "wudu_1_b": [
        "Se propone en el corazón purificarse para la oración (la intención reside en el corazón y no se pronuncia) y se dice: «Bismillah».",
        "On se propose dans son cœur de se purifier pour la prière (l’intention est dans le cœur et ne se prononce pas), puis on dit : « Bismillah ».",
        "Faz-se a intenção no coração de se purificar para a oração (a intenção reside no coração e não se pronuncia) e diz-se: «Bismillah».",
        "Сердцем намереваются очиститься для молитвы (намерение — в сердце и вслух не произносится) и говорят: «Бисмиллях».",
        "دل میں نماز کے لیے طہارت کی نیت کرے (نیت کا محل دل ہے، زبان سے نہیں) اور کہے: «بسم اللہ»۔"],
    "wudu_2_h": [
        "2. Lavarse las manos",
        "2. Se laver les mains",
        "2. Lavar as mãos",
        "2. Мытьё кистей рук",
        "٢. ہتھیلیاں دھونا"],
    "wudu_2_b": [
        "Se lava las dos manos tres veces antes de introducirlas en el recipiente.",
        "On se lave les deux mains trois fois avant de les plonger dans le récipient.",
        "Lavam-se as duas mãos três vezes antes de as mergulhar no recipiente.",
        "Кисти рук моют трижды, прежде чем опустить их в сосуд.",
        "برتن میں ہاتھ ڈالنے سے پہلے دونوں ہتھیلیاں تین بار دھوئے۔"],
    "wudu_3_h": [
        "3. Enjuagarse la boca y la nariz",
        "3. Se rincer la bouche et le nez",
        "3. Bochechar e aspirar água pelo nariz",
        "3. Полоскание рта и носа",
        "٣. کلی کرنا اور ناک میں پانی ڈالنا"],
    "wudu_3_b": [
        "Se enjuaga la boca, aspira agua por la nariz y la expulsa, tres veces.",
        "On se rince la bouche, on aspire de l’eau par le nez puis on l’expulse, trois fois.",
        "Bocheja-se, aspira-se água pelo nariz e expele-se, três vezes.",
        "Трижды полощут рот, втягивают воду носом и высмаркивают её.",
        "تین بار کلی کرے اور ناک میں پانی چڑھا کر جھاڑے۔"],
    "wudu_4_h": [
        "4. Lavarse el rostro",
        "4. Se laver le visage",
        "4. Lavar o rosto",
        "4. Мытьё лица",
        "٤. چہرہ دھونا"],
    "wudu_4_b": [
        "Se lava el rostro tres veces, desde el nacimiento del cabello hasta debajo del mentón, y de oreja a oreja.",
        "On se lave le visage trois fois, de la racine des cheveux jusqu’au bas du menton, et d’une oreille à l’autre.",
        "Lava-se o rosto três vezes, desde a raiz do cabelo até abaixo do queixo, e de orelha a orelha.",
        "Лицо моют трижды — от линии роста волос до низа подбородка и от уха до уха.",
        "چہرہ تین بار دھوئے، بالوں کی جڑ سے ٹھوڑی کے نیچے تک، اور ایک کان سے دوسرے کان تک۔"],
    "wudu_5_h": [
        "5. Lavarse los brazos hasta los codos",
        "5. Se laver les bras jusqu’aux coudes",
        "5. Lavar os braços até aos cotovelos",
        "5. Мытьё рук до локтей",
        "٥. کہنیوں تک ہاتھ دھونا"],
    "wudu_5_b": [
        "Se lava el brazo derecho hasta el codo tres veces, y después el izquierdo del mismo modo.",
        "On lave le bras droit jusqu’au coude trois fois, puis le bras gauche de la même façon.",
        "Lava-se o braço direito até ao cotovelo três vezes, e depois o esquerdo da mesma forma.",
        "Правую руку моют до локтя трижды, затем так же левую.",
        "دایاں ہاتھ کہنی تک تین بار دھوئے، پھر اسی طرح بایاں۔"],
    "wudu_6_h": [
        "6. Pasar las manos por la cabeza y las orejas",
        "6. Essuyer la tête et les oreilles",
        "6. Passar as mãos pela cabeça e pelas orelhas",
        "6. Обтирание головы и ушей",
        "٦. سر اور کانوں کا مسح"],
    "wudu_6_b": [
        "Se pasa una vez por toda la cabeza con las manos mojadas, de delante hacia atrás y de vuelta, y después se pasan por las orejas, por fuera y por dentro.",
        "On essuie toute la tête une fois avec les mains humides, de l’avant vers l’arrière puis en revenant, puis on essuie les oreilles, à l’extérieur et à l’intérieur.",
        "Passa-se uma vez por toda a cabeça com as mãos molhadas, da frente para trás e de volta, e depois pelas orelhas, por fora e por dentro.",
        "Влажными руками один раз обтирают всю голову — спереди назад и обратно, затем обтирают уши снаружи и внутри.",
        "بھیگے ہاتھوں سے پورے سر کا ایک بار مسح کرے، آگے سے پیچھے اور پھر واپس، پھر کانوں کا اندر باہر سے مسح کرے۔"],
    "wudu_7_h": [
        "7. Lavarse los pies hasta los tobillos",
        "7. Se laver les pieds jusqu’aux chevilles",
        "7. Lavar os pés até aos tornozelos",
        "7. Мытьё ног до щиколоток",
        "٧. ٹخنوں تک پاؤں دھونا"],
    "wudu_7_b": [
        "Se lava el pie derecho hasta los tobillos tres veces, pasando el agua entre los dedos, y después el izquierdo del mismo modo.",
        "On lave le pied droit jusqu’aux chevilles trois fois, en faisant passer l’eau entre les orteils, puis le pied gauche de la même façon.",
        "Lava-se o pé direito até aos tornozelos três vezes, passando a água entre os dedos, e depois o esquerdo da mesma forma.",
        "Правую ногу моют до щиколоток трижды, промывая между пальцами, затем так же левую.",
        "دایاں پاؤں ٹخنوں تک تین بار دھوئے اور انگلیوں کے درمیان خلال کرے، پھر اسی طرح بایاں۔"],
    "wudu_8_h": [
        "8. La súplica después de la ablución",
        "8. L’invocation après les ablutions",
        "8. A súplica depois da ablução",
        "8. Мольба после омовения",
        "٨. وضو کے بعد کی دعا"],
    "wudu_8_b": [
        "Al terminar la ablución se dicen los dos testimonios. A quien los dice se le abren las ocho puertas del Paraíso, para entrar por la que quiera.",
        "Une fois les ablutions terminées, on prononce les deux témoignages. Celui qui les dit se voit ouvrir les huit portes du Paradis, pour entrer par celle qu’il veut.",
        "Ao terminar a ablução dizem-se os dois testemunhos. A quem os diz abrem-se as oito portas do Paraíso, para entrar por aquela que quiser.",
        "По завершении омовения произносят два свидетельства. Тому, кто их скажет, открываются восемь врат Рая, и он войдёт в те, в какие пожелает.",
        "وضو مکمل کرنے کے بعد شہادتین پڑھے۔ جو یہ کہے، اس کے لیے جنت کے آٹھوں دروازے کھول دیے جاتے ہیں، جس سے چاہے داخل ہو۔"],

    "prayer_title": [
        "Pasos de la oración",
        "Étapes de la prière",
        "Passos da oração",
        "Порядок молитвы",
        "نماز کے مراحل"],
    "prayer_1_h": [
        "1. Preparación",
        "1. Préparation",
        "1. Preparação",
        "1. Подготовка",
        "١. تیاری"],
    "prayer_1_b": [
        "Hace la ablución, se orienta hacia la alquibla y hace en su corazón la intención de la oración (sin pronunciarla).",
        "On fait ses ablutions, on se tourne vers la qibla et on formule dans son cœur l’intention de la prière (sans la prononcer).",
        "Faz a ablução, orienta-se para a alquibla e faz no coração a intenção da oração (sem a pronunciar).",
        "Совершают омовение, обращаются к кибле и делают намерение на молитву в сердце (не произнося его вслух).",
        "وضو کرے، قبلہ رخ ہو، اور دل میں نماز کی نیت کرے (زبان سے نہیں)۔"],
    "prayer_2_h": [
        "2. El takbir de apertura",
        "2. Le takbir d’ouverture",
        "2. O takbir de abertura",
        "2. Вступительный такбир",
        "٢. تکبیرِ تحریمہ"],
    "prayer_2_b": [
        "Levanta las manos y dice «Allahu akbar» para entrar en la oración, y después coloca la mano derecha sobre la izquierda por encima del pecho.",
        "On lève les mains et on dit « Allahou akbar » pour entrer en prière, puis on place la main droite sur la gauche au-dessus de la poitrine.",
        "Levanta as mãos e diz «Allahu akbar» para entrar na oração, e depois coloca a mão direita sobre a esquerda acima do peito.",
        "Поднимают руки и произносят «Аллаху акбар», вступая в молитву, затем кладут правую кисть на левую поверх груди.",
        "دونوں ہاتھ اٹھا کر «اللہ اکبر» کہے اور نماز میں داخل ہو، پھر دایاں ہاتھ بائیں پر سینے کے اوپر رکھے۔"],
    "prayer_3_h": [
        "3. De pie y recitación",
        "3. La station debout et la récitation",
        "3. De pé e recitação",
        "3. Стояние и чтение",
        "٣. قیام اور قراءت"],
    "prayer_3_b": [
        "Recita la sura Al-Fátiha y después lo que le resulte fácil del Corán, en las dos primeras unidades.",
        "On récite la sourate Al-Fâtiha, puis ce que l’on peut du Coran, dans les deux premières unités.",
        "Recita a sura Al-Fátiha e depois o que lhe for fácil do Alcorão, nas duas primeiras unidades.",
        "Читают суру «аль-Фатиха», а затем — что доступно из Корана, в первых двух ракаатах.",
        "سورۃ الفاتحہ پڑھے، پھر پہلی دو رکعتوں میں قرآن سے جو میسر ہو پڑھے۔"],
    "prayer_4_h": [
        "4. La inclinación (ruku)",
        "4. L’inclinaison (roukou)",
        "4. A inclinação (ruku)",
        "4. Поясной поклон (руку)",
        "٤. رکوع"],
    "prayer_4_b": [
        "Dice el takbir y se inclina hasta que la espalda quede recta, poniendo las manos sobre las rodillas, y dice tres veces: «Subhana rabbiyal-adhim».",
        "On dit le takbir et on s’incline jusqu’à ce que le dos soit droit, les mains sur les genoux, en disant trois fois : « Soubhâna rabbiyal-‘adhîm ».",
        "Diz o takbir e inclina-se até as costas ficarem direitas, colocando as mãos sobre os joelhos, e diz três vezes: «Subhana rabbiyal-adhim».",
        "Произносят такбир и совершают поясной поклон, пока спина не выпрямится, положив руки на колени, и трижды говорят: «Субхана Раббияль-‘Азым».",
        "تکبیر کہہ کر رکوع کرے یہاں تک کہ پیٹھ سیدھی ہو جائے، ہاتھ گھٹنوں پر رکھے، اور تین بار کہے: «سبحان ربي العظيم»۔"],
    "prayer_5_h": [
        "5. Incorporarse de la inclinación",
        "5. Le redressement après l’inclinaison",
        "5. Erguer-se da inclinação",
        "5. Выпрямление после поклона",
        "٥. رکوع سے اٹھنا"],
    "prayer_5_b": [
        "Dice «Sami Allahu liman hamidah» al incorporarse, y después «Rabbana wa lakal-hamd» una vez erguido.",
        "On dit « Sami‘a Allâhou liman hamidah » en se redressant, puis « Rabbanâ wa lakal-hamd » une fois debout.",
        "Diz «Sami Allahu liman hamidah» ao erguer-se, e depois «Rabbana wa lakal-hamd» já de pé.",
        "Выпрямляясь, говорят: «Сами‘а Ллаху лиман хамидах», а затем, встав прямо: «Раббана уа лякаль-хамд».",
        "اٹھتے ہوئے «سمع الله لمن حمده» کہے، پھر سیدھا کھڑا ہو کر «ربنا ولك الحمد» کہے۔"],
    "prayer_6_h": [
        "6. La postración (suyud)",
        "6. La prosternation (soujoud)",
        "6. A prostração (sujud)",
        "6. Земной поклон (суджуд)",
        "٦. سجدہ"],
    "prayer_6_b": [
        "Dice el takbir y se postra sobre siete apoyos (la frente con la nariz, las dos palmas, las dos rodillas, las puntas de los pies), y dice tres veces: «Subhana rabbiyal-a'la».",
        "On dit le takbir et on se prosterne sur sept appuis (le front avec le nez, les deux paumes, les deux genoux, la pointe des pieds), en disant trois fois : « Soubhâna rabbiyal-a‘lâ ».",
        "Diz o takbir e prostra-se sobre sete apoios (a testa com o nariz, as duas palmas, os dois joelhos, as pontas dos pés), e diz três vezes: «Subhana rabbiyal-a'la».",
        "Произносят такбир и совершают земной поклон на семи опорах (лоб вместе с носом, обе ладони, оба колена, кончики пальцев ног), трижды говоря: «Субхана Раббияль-А‘ля».",
        "تکبیر کہہ کر سات اعضا پر سجدہ کرے (پیشانی ناک سمیت، دونوں ہتھیلیاں، دونوں گھٹنے، پاؤں کی انگلیاں)، اور تین بار کہے: «سبحان ربي الأعلى»۔"],
    "prayer_7_h": [
        "7. Sentarse entre las dos postraciones",
        "7. L’assise entre les deux prosternations",
        "7. Sentar-se entre as duas prostrações",
        "7. Сидение между двумя поклонами",
        "٧. دو سجدوں کے درمیان بیٹھنا"],
    "prayer_7_b": [
        "Levanta la cabeza de la postración y se sienta con calma, diciendo «Rabbi ghfir li» (Señor mío, perdóname), y después hace la segunda postración como la primera.",
        "On relève la tête de la prosternation et on s’assied posément en disant « Rabbi ghfir lî » (Seigneur, pardonne-moi), puis on accomplit la seconde prosternation comme la première.",
        "Levanta a cabeça da prostração e senta-se com calma, dizendo «Rabbi ghfir li» (Senhor meu, perdoa-me), e depois faz a segunda prostração como a primeira.",
        "Поднимают голову из земного поклона и спокойно садятся, говоря: «Рабби гфир ли» (Господи, прости меня), затем совершают второй поклон, как и первый.",
        "سجدے سے سر اٹھا کر اطمینان سے بیٹھے اور کہے: «رب اغفر لي»، پھر پہلے کی طرح دوسرا سجدہ کرے۔"],
    "prayer_8_h": [
        "8. Repetir las unidades restantes",
        "8. Répéter les unités restantes",
        "8. Repetir as unidades restantes",
        "8. Повторение остальных ракаатов",
        "٨. باقی رکعتیں دہرانا"],
    "prayer_8_b": [
        "Se levanta para la unidad siguiente y repite lo anterior, según el número de unidades de cada oración (2 en Fayr, 4 en Dhuhr, Asr e Isha, 3 en Magrib).",
        "On se relève pour l’unité suivante et on répète ce qui précède, selon le nombre d’unités de la prière (2 pour Fajr, 4 pour Dhuhr, Asr et Isha, 3 pour Maghrib).",
        "Levanta-se para a unidade seguinte e repete o anterior, conforme o número de unidades de cada oração (2 no Fajr, 4 no Dhuhr, Asr e Isha, 3 no Maghrib).",
        "Встают на следующий ракаат и повторяют предыдущее — по числу ракаатов данной молитвы (2 в фаджр, 4 в зухр, аср и иша, 3 в магриб).",
        "اگلی رکعت کے لیے کھڑا ہو اور نماز کی رکعتوں کی تعداد کے مطابق یہی دہرائے (فجر میں ٢، ظہر، عصر اور عشاء میں ٤، مغرب میں ٣)۔"],
    "prayer_9_h": [
        "9. El tashahhud",
        "9. Le tachahhoud",
        "9. O tashahhud",
        "9. Ташаххуд",
        "٩. تشہد"],
    "prayer_9_b": [
        "Se sienta después de la segunda unidad (y al final de la oración), recita el tashahhud y pide la bendición sobre el Profeta ﷺ.",
        "On s’assied après la deuxième unité (et à la fin de la prière), on récite le tachahhoud et on prie sur le Prophète ﷺ.",
        "Senta-se depois da segunda unidade (e no final da oração), recita o tashahhud e pede a bênção sobre o Profeta ﷺ.",
        "Садятся после второго ракаата (и в конце молитвы), читают ташаххуд и призывают благословение на Пророка ﷺ.",
        "دوسری رکعت کے بعد (اور نماز کے آخر میں) بیٹھے، تشہد پڑھے اور نبی ﷺ پر درود بھیجے۔"],
    "prayer_10_h": [
        "10. El saludo final",
        "10. Le salut final",
        "10. A saudação final",
        "10. Завершающий салям",
        "١٠. سلام"],
    "prayer_10_b": [
        "Concluye la oración dando el saludo hacia su derecha y después hacia su izquierda.",
        "On conclut la prière par le salut, d’abord vers la droite puis vers la gauche.",
        "Conclui a oração dando a saudação para a sua direita e depois para a sua esquerda.",
        "Молитву завершают саламом — сначала направо, затем налево.",
        "دائیں طرف پھر بائیں طرف سلام پھیر کر نماز ختم کرے۔"],

    "quran_title": [
        "Introducción al Corán",
        "Introduction au Coran",
        "Introdução ao Alcorão",
        "Введение в Коран",
        "قرآن کا تعارف"],
    "quran_1_h": [
        "¿Qué es el Corán?",
        "Qu’est-ce que le Coran ?",
        "O que é o Alcorão?",
        "Что такое Коран?",
        "قرآن کیا ہے؟"],
    "quran_1_b": [
        "El noble Corán es la palabra de Alá revelada al Profeta Mahoma ﷺ por medio del ángel Gabriel, preservada de toda alteración, y su recitación es en sí misma un acto de adoración.",
        "Le noble Coran est la parole d’Allah révélée au Prophète Mohammed ﷺ par l’ange Gabriel, préservée de toute altération, et sa récitation est en elle-même un acte d’adoration.",
        "O nobre Alcorão é a palavra de Allah revelada ao Profeta Muhammad ﷺ por intermédio do anjo Gabriel, preservada de qualquer alteração, e a sua recitação é em si mesma um ato de adoração.",
        "Благородный Коран — это слово Аллаха, ниспосланное Пророку Мухаммаду ﷺ через ангела Джибриля, сохранённое от искажения; само его чтение является поклонением.",
        "قرآن کریم اللہ کا کلام ہے جو نبی محمد ﷺ پر فرشتے جبریل علیہ السلام کے ذریعے نازل ہوا، تحریف سے محفوظ ہے، اور اس کی تلاوت بذاتِ خود عبادت ہے۔"],
    "quran_2_h": [
        "¿Cómo está organizado?",
        "Comment est-il organisé ?",
        "Como está organizado?",
        "Как он устроен?",
        "اس کی ترتیب کیسی ہے؟"],
    "quran_2_b": [
        "Se divide en 114 suras, mecanas (reveladas antes de la Hégira) y medinenses (después), y también en 30 partes (yuz) para facilitar su lectura completa a lo largo del mes.",
        "Il se divise en 114 sourates, mecquoises (révélées avant l’Hégire) et médinoises (après), et aussi en 30 parties (juz) afin d’en faciliter la lecture complète au fil du mois.",
        "Divide-se em 114 suras, mecanas (reveladas antes da Hégira) e medinenses (depois), e também em 30 partes (juz) para facilitar a leitura completa ao longo do mês.",
        "Он делится на 114 сур — мекканские (ниспосланные до хиджры) и мединские (после неё) — а также на 30 частей (джуз), чтобы прочитать его целиком за месяц.",
        "یہ ١١٤ سورتوں میں تقسیم ہے، مکی (ہجرت سے پہلے نازل ہونے والی) اور مدنی (اس کے بعد)، اور مہینے بھر میں ختم آسان بنانے کے لیے ٣٠ پاروں میں بھی۔"],
    "quran_3_h": [
        "¿Por dónde empiezo?",
        "Par où commencer ?",
        "Por onde começo?",
        "С чего начать?",
        "کہاں سے شروع کروں؟"],
    "quran_3_b": [
        "Muchos musulmanes nuevos empiezan memorizando la sura Al-Fátiha (que se recita en cada unidad de la oración) y las suras breves de la última parte del Corán (yuz Amma), y luego avanzan en la lectura y la comprensión. Todo eso está en la pestaña «Corán» de esta aplicación, con el texto, la recitación y la traducción del significado.",
        "Beaucoup de nouveaux musulmans commencent par mémoriser la sourate Al-Fâtiha (récitée à chaque unité de prière) et les sourates brèves de la dernière partie du Coran (juz ‘Amma), puis progressent dans la lecture et la compréhension. Tout cela se trouve dans l’onglet « Coran » de cette application, avec le texte, la récitation et la traduction du sens.",
        "Muitos muçulmanos novos começam por memorizar a sura Al-Fátiha (recitada em cada unidade da oração) e as suras breves da última parte do Alcorão (juz Amma), e depois avançam na leitura e na compreensão. Tudo isso está no separador «Alcorão» desta aplicação, com o texto, a recitação e a tradução do significado.",
        "Многие новообращённые начинают с заучивания суры «аль-Фатиха» (читаемой в каждом ракаате) и коротких сур последней части Корана (джуз ‘Амма), а затем продвигаются в чтении и понимании. Всё это есть во вкладке «Коран» этого приложения — текст, чтение и перевод смыслов.",
        "بہت سے نئے مسلمان سورۃ الفاتحہ (جو ہر رکعت میں پڑھی جاتی ہے) اور قرآن کے آخری پارے (پارۂ عمّ) کی چھوٹی سورتیں یاد کرنے سے آغاز کرتے ہیں، پھر بتدریج پڑھنے اور سمجھنے میں آگے بڑھتے ہیں۔ یہ سب اس ایپ کے «قرآن» ٹیب میں موجود ہے، متن، تلاوت اور ترجمۂ معانی کے ساتھ۔"],
}

LOCALES = ["ar", "en", "es", "fr", "pt", "ru", "ur"]
OTHER_ORDER = ["es", "fr", "pt", "ru", "ur"]


_LIT = r"""(?:'(?:\\.|[^'\\])*'|"(?:\\.|[^"\\])*")"""


def dart_strings(src, field):
    """Every value of `field:`, with dartfmt's adjacent-literal wrapping joined
    and Dart's escapes undone.

    Both quote styles, because the file uses both: one `bodyEn` is written with
    double quotes (its text contains apostrophes), and a single-quote-only
    pattern silently returned 31 values where 32 were expected. The count check
    in `main` is what caught it — which is the reason the check is there.
    """
    out = []
    for m in re.finditer(r"\b%s:\s*((?:%s\s*)+)" % (field, _LIT), src):
        chunks = [c[1:-1] for c in re.findall(_LIT, m.group(1))]
        joined = "".join(chunks)
        out.append(joined.replace("\\'", "'").replace('\\"', '"')
                   .replace("\\\\", "\\"))
    return out


def key_order():
    keys = []
    for name, count in SECTIONS:
        keys.append("%s_title" % name)
        for i in range(1, count + 1):
            keys.append("%s_%d_h" % (name, i))
            keys.append("%s_%d_b" % (name, i))
    return keys


def main():
    src = io.open(SRC, encoding="utf-8").read()
    titles_ar, titles_en = dart_strings(src, "titleAr"), dart_strings(src, "titleEn")
    heads_ar, heads_en = dart_strings(src, "headingAr"), dart_strings(src, "headingEn")
    bodies_ar, bodies_en = dart_strings(src, "bodyAr"), dart_strings(src, "bodyEn")

    want_titles = len(SECTIONS)
    want_items = sum(c for _, c in SECTIONS)
    for label, got, want in (("titleAr", len(titles_ar), want_titles),
                             ("titleEn", len(titles_en), want_titles),
                             ("headingAr", len(heads_ar), want_items),
                             ("headingEn", len(heads_en), want_items),
                             ("bodyAr", len(bodies_ar), want_items),
                             ("bodyEn", len(bodies_en), want_items)):
        if got != want:
            raise SystemExit("%s: found %d, expected %d — the file's shape "
                             "changed, do not guess" % (label, got, want))

    native = {"ar": {}, "en": {}}
    ti = ii = 0
    for name, count in SECTIONS:
        native["ar"]["%s_title" % name] = titles_ar[ti]
        native["en"]["%s_title" % name] = titles_en[ti]
        ti += 1
        for i in range(1, count + 1):
            native["ar"]["%s_%d_h" % (name, i)] = heads_ar[ii]
            native["en"]["%s_%d_h" % (name, i)] = heads_en[ii]
            native["ar"]["%s_%d_b" % (name, i)] = bodies_ar[ii]
            native["en"]["%s_%d_b" % (name, i)] = bodies_en[ii]
            ii += 1

    keys = key_order()
    missing = [k for k in keys if k not in OTHER]
    if missing:
        raise SystemExit("no translation written for: %s" % ", ".join(missing))

    added = 0
    for code in LOCALES:
        path = os.path.join(TR, "%s.json" % code)
        doc = json.loads(io.open(path, encoding="utf-8").read(),
                         object_pairs_hook=collections.OrderedDict)
        bucket = doc.setdefault("guide", collections.OrderedDict())
        for key in keys:
            if key in bucket:
                continue
            if code in native:
                bucket[key] = native[code][key]
            else:
                bucket[key] = OTHER[key][OTHER_ORDER.index(code)]
            added += 1
        io.open(path, "w", encoding="utf-8").write(
            json.dumps(doc, ensure_ascii=False, indent=2) + "\n")
    print("added %d key/locale pairs across %d keys" % (added, len(keys)))


if __name__ == "__main__":
    main()
