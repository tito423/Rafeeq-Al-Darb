# -*- coding: utf-8 -*-
"""The 226 book blurbs — which turned out to be one template and 29 paragraphs.

`descriptionAr` looked like 226 bespoke blurbs to translate into six languages.
Counting first (`blurb_shapes.txt`): **197 of them are one generated sentence** —
«مصنَّف لـ <author>، <N> صفحة، ضمن باب <category>.» — and only 29 are prose
somebody wrote. The same lesson as the death lines: count the shapes before
translating the strings.

The template's three slots are already solved elsewhere in the app:
  * the author is `properName(authorAr, authorEn)`
  * the category is `BookCategory.labelKey`, translated in all seven locales
  * the page count is a number, lifted out of the sentence into a field
so the template is ONE key, not 197.

`library.book_desc_generated` takes them in that order. Word order differs by
language — Urdu puts the author first with a possessive, Russian wants the
category in guillemets — and a positional `{}` lets each language put them where
it puts them.

The Arabic of the 29 is not retyped here: `patch_book_desc.py` lifts it from the
catalogue itself. Only the six other languages are written below.
"""

import collections
import io
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TR = os.path.join(ROOT, "rafeeq_app", "assets", "translations")

LOCALES = ["ar", "en", "es", "fr", "pt", "ru", "ur"]
OTHER = ["en", "es", "fr", "pt", "ru", "ur"]

TEMPLATE = {
    "ar": "مصنَّف لـ {}، {} صفحة، ضمن باب {}.",
    "en": "A work by {}, {} pages, in the {} section.",
    "es": "Una obra de {}, {} páginas, en la sección de {}.",
    "fr": "Un ouvrage de {}, {} pages, dans la section {}.",
    "pt": "Uma obra de {}, {} páginas, na secção de {}.",
    "ru": "Труд автора {}, {} страниц, в разделе «{}».",
    "ur": "{} کی تصنیف، {} صفحات، باب {} میں۔",
}

# book id -> [en, es, fr, pt, ru, ur]
BESPOKE = {
    "bulugh_al_maram": [
        "Ibn Hajar gathered the hadiths of legal rulings the jurists relied on, arranged by chapters of law, naming after each hadith who reported it and its grade. One of the best known and most widely studied primers of legal hadith.",
        "Ibn Hayar reunió los hadices de normas jurídicas en los que se apoyaron los juristas, ordenados por capítulos de fiqh, indicando tras cada hadiz quién lo transmitió y su grado. Uno de los compendios de normas más conocidos y estudiados.",
        "Ibn Hajar y a réuni les hadiths des règles juridiques sur lesquels les juristes se sont appuyés, classés par chapitres de fiqh, en indiquant après chaque hadith qui l’a rapporté et son degré. L’un des recueils de règles les plus connus et les plus étudiés.",
        "Ibn Hajar reuniu os hadiths das normas jurídicas em que os juristas se apoiaram, organizados por capítulos de fiqh, indicando após cada hadith quem o transmitiu e o seu grau. Um dos compêndios de normas mais conhecidos e estudados.",
        "Ибн Хаджар собрал хадисы правовых норм, на которые опирались правоведы, расположив их по главам фикха и указывая после каждого хадиса, кто его привёл и какова его степень. Один из самых известных и изучаемых сводов правовых хадисов.",
        "ابن حجر نے احکام کی وہ احادیث جمع کیں جن پر فقہا نے اعتماد کیا، فقہی ابواب پر مرتب کر کے، اور ہر حدیث کے بعد اس کے مخرِّج اور درجے کا ذکر کیا۔ احکام کے مشہور ترین اور سب سے زیادہ پڑھے جانے والے متون میں سے۔"],
    "al_adab_al_mufrad": [
        "Al-Bukhari's book on character and manners, kindness to parents, keeping family ties and good company. He kept it apart from his Sahih and applied a wider condition to it, so not everything in it reaches the grade of al-Jami' as-Sahih.",
        "El libro de Al-Bujari sobre el carácter y los modales, la bondad con los padres, los lazos de familia y el buen trato. Lo mantuvo aparte de su Sahih con una condición más amplia, de modo que no todo en él alcanza el grado de Al-Yami' as-Sahih.",
        "Le livre d’al-Bukhari sur le caractère et les bonnes manières, la piété filiale, les liens de parenté et la bonne compagnie. Il l’a tenu à part de son Sahih avec une condition plus large : tout ce qu’il contient n’atteint donc pas le degré d’al-Jami' as-Sahih.",
        "O livro de al-Bukhari sobre o carácter e as boas maneiras, a bondade para com os pais, os laços de família e o bom convívio. Manteve-o à parte do seu Sahih com uma condição mais ampla, pelo que nem tudo nele atinge o grau de al-Jami' as-Sahih.",
        "Книга аль-Бухари о нраве и благих манерах, почтении к родителям, поддержании родственных связей и добром обхождении. Он отделил её от своего «Сахиха» и применил в ней более широкое условие, поэтому не всё в ней достигает степени «аль-Джами‘ ас-Сахих».",
        "امام بخاری کی کتاب اخلاق و آداب، والدین کے ساتھ حسنِ سلوک، صلہ رحمی اور حسنِ معاشرت میں۔ اسے اپنی صحیح سے الگ رکھا اور اس میں شرط زیادہ وسیع رکھی، اس لیے اس کا سب کچھ جامع صحیح کی احادیث کے درجے پر نہیں۔"],
    "sahih_al_adab_al_mufrad": [
        "The hadiths of al-Adab al-Mufrad that Shaykh Muhammad Nasir al-Din al-Albani graded authentic, set apart from the weak ones.",
        "Los hadices de Al-Adab Al-Mufrad que el jeque Muhammad Nasir ad-Din al-Albani calificó de auténticos, separados de los débiles.",
        "Les hadiths d’al-Adab al-Mufrad que le cheikh Muhammad Nasir ad-Din al-Albani a jugés authentiques, séparés des faibles.",
        "Os hadiths de al-Adab al-Mufrad que o xeque Muhammad Nasir ad-Din al-Albani classificou como autênticos, separados dos fracos.",
        "Хадисы «аль-Адаб аль-муфрад», признанные достоверными шейхом Мухаммадом Насир ад-Дином аль-Альбани, отделённые от слабых.",
        "الادب المفرد کی وہ احادیث جنہیں شیخ محمد ناصر الدین البانی نے صحیح قرار دیا، ضعیف احادیث سے الگ کر کے۔"],
    "al_shamail_al_muhammadiyyah": [
        "Al-Tirmidhi's collection of what is reported about the Prophet ﷺ in form and character: his appearance, dress, food, worship and manners, arranged by chapter.",
        "La recopilación de At-Tirmidí sobre lo transmitido acerca del Profeta ﷺ en su forma y su carácter: su aspecto, su vestimenta, su comida, su adoración y sus modales, ordenada por capítulos.",
        "Le recueil d’at-Tirmidhi de ce qui est rapporté du Prophète ﷺ dans son apparence et son caractère : son aspect, son vêtement, sa nourriture, son adoration et ses manières, classé par chapitres.",
        "A recolha de at-Tirmidhi do que é transmitido sobre o Profeta ﷺ na forma e no carácter: o seu aspeto, o vestuário, a comida, a adoração e as maneiras, organizada por capítulos.",
        "Собрание ат-Тирмизи того, что передаётся о Пророке ﷺ во внешности и нраве: его облик, одежда, пища, поклонение и манеры, расположенное по главам.",
        "امام ترمذی نے نبی ﷺ کی خَلقی اور خُلقی صفات میں وارد روایات جمع کیں: آپ کی ہیئت، لباس، کھانا، عبادت اور اخلاق، ابواب پر مرتب۔"],
    "mishkat_al_masabih": [
        "An expansion and refinement of al-Baghawi's Masabih al-Sunnah: al-Tibrizi arranged it by chapter, added a third section, and attributed every hadith to the one who reported it. One of the most comprehensive ordered books of the Sunnah.",
        "Ampliación y depuración de Masabih as-Sunnah de Al-Bagawi: At-Tibrizi lo ordenó por capítulos, le añadió una tercera sección y atribuyó cada hadiz a quien lo transmitió. Uno de los libros ordenados de la Sunna más completos.",
        "Un élargissement et une mise au point des Masabih as-Sunnah d’al-Baghawi : at-Tibrizi l’a classé par chapitres, y a ajouté une troisième section et a attribué chaque hadith à celui qui l’a rapporté. L’un des livres ordonnés de la Sunna les plus complets.",
        "Uma ampliação e depuração do Masabih as-Sunnah de al-Baghawi: at-Tibrizi organizou-o por capítulos, acrescentou-lhe uma terceira secção e atribuiu cada hadith a quem o transmitiu. Um dos livros ordenados da Sunnah mais completos.",
        "Расширение и обработка «Масабих ас-сунна» аль-Багави: ат-Тибризи расположил книгу по главам, добавил третий раздел и отнёс каждый хадис к тому, кто его привёл. Один из самых полных упорядоченных сводов Сунны.",
        "بغوی کی «مصابیح السنۃ» کی توسیع اور تہذیب: تبریزی نے اسے ابواب پر مرتب کیا، تیسری فصل کا اضافہ کیا، اور ہر حدیث کو اس کے مخرِّج کی طرف منسوب کیا۔ سنت کی مرتب کتابوں میں سب سے جامع میں سے۔"],
    "al_targhib_wal_tarhib": [
        "Al-Mundhiri's collection of hadiths encouraging obedience and warning against sin, arranged by chapter. Al-Mundhiri himself points to the grade of many of them; it holds authentic, good and weak reports alike.",
        "Recopilación de Al-Mundhiri de hadices que animan a la obediencia y advierten del pecado, ordenada por capítulos. El propio Al-Mundhiri señala el grado de muchos de ellos; contiene relatos auténticos, buenos y débiles.",
        "Recueil d’al-Mundhiri des hadiths incitant à l’obéissance et mettant en garde contre le péché, classé par chapitres. Al-Mundhiri indique lui-même le degré de beaucoup d’entre eux ; on y trouve de l’authentique, du bon et du faible.",
        "Recolha de al-Mundhiri de hadiths que incentivam à obediência e advertem contra o pecado, organizada por capítulos. O próprio al-Mundhiri indica o grau de muitos deles; contém relatos autênticos, bons e fracos.",
        "Собрание аль-Мунзири хадисов, побуждающих к покорности и предостерегающих от грехов, расположенное по главам. Сам аль-Мунзири указывает степень многих из них; в книге есть достоверное, хорошее и слабое.",
        "منذری کا مجموعہ جس میں طاعات کی ترغیب اور معاصی سے ترہیب کی احادیث ابواب پر مرتب ہیں۔ منذری خود بہت سی احادیث کے درجے کی طرف اشارہ کرتے ہیں؛ اس میں صحیح، حسن اور ضعیف سب موجود ہے۔"],
    "umdat_al_ahkam": [
        "A short primer of the hadiths of legal rulings, in which al-Maqdisi confined himself to what al-Bukhari and Muslim both reported, making it among the most firmly established books of rulings. One of the texts a student begins with.",
        "Compendio breve de los hadices de normas jurídicas, en el que Al-Maqdisi se limitó a lo que transmiten a la vez Al-Bujari y Muslim, lo que lo hace de los más firmemente establecidos. Uno de los textos con los que se empieza.",
        "Un bref recueil des hadiths des règles juridiques, dans lequel al-Maqdisi s’est limité à ce que rapportent à la fois al-Bukhari et Muslim, ce qui en fait l’un des plus solidement établis. L’un des textes par lesquels on commence.",
        "Um compêndio breve dos hadiths das normas jurídicas, no qual al-Maqdisi se limitou ao que al-Bukhari e Muslim transmitem em conjunto, o que o torna dos mais solidamente estabelecidos. Um dos textos por onde se começa.",
        "Краткий свод хадисов правовых норм, в котором аль-Макдиси ограничился тем, что приводят и аль-Бухари, и Муслим, что делает его одним из наиболее твёрдо установленных. Один из текстов, с которых начинают.",
        "احکام کی احادیث میں ایک مختصر متن، جس میں مقدسی نے صرف اُن روایات پر اکتفا کیا جن پر بخاری و مسلم متفق ہیں، اس لیے یہ ثبوت کے اعتبار سے بلند ترین کتابوں میں سے ہے۔ طلبِ علم کے ابتدائی متون میں سے۔"],
    "riyad_as_salihin": [
        "The best known digest of hadith on character, manners and the softening of hearts, gathered by Imam al-Nawawi from the two Sahihs and other books of the Sunnah.",
        "El compendio de hadices más conocido sobre carácter, modales y el ablandamiento del corazón, reunido por el imam An-Nawawi de los dos Sahihs y de otros libros de la Sunna.",
        "Le plus connu des abrégés de hadiths sur le caractère, les bonnes manières et l’adoucissement des cœurs, réuni par l’imam an-Nawawi à partir des deux Sahihs et d’autres livres de la Sunna.",
        "O mais conhecido compêndio de hadiths sobre carácter, boas maneiras e o abrandamento dos corações, reunido pelo imã an-Nawawi a partir dos dois Sahihs e de outros livros da Sunnah.",
        "Самый известный сборник хадисов о нраве, манерах и смягчении сердец, собранный имамом ан-Навави из двух «Сахихов» и других книг Сунны.",
        "اخلاق، آداب اور رقائق میں حدیث کا مشہور ترین مختصر، جسے امام نووی نے صحیحین اور دیگر کتبِ سنت سے جمع کیا۔"],
    "mukhtasar_minhaj_al_qasidin": [
        "Ibn Qudama al-Maqdisi's abridgement of Ibn al-Jawzi's Minhaj al-Qasidin on spiritual purification, character and detachment; one of the central books of conduct among Ahl al-Sunnah.",
        "Resumen de Ibn Qudama Al-Maqdisi del Minhay al-Qasidin de Ibn Al-Yawzi, sobre purificación espiritual, carácter y desapego; uno de los libros centrales de conducta entre Ahl as-Sunna.",
        "L’abrégé par Ibn Qudama al-Maqdisi du Minhaj al-Qasidin d’Ibn al-Jawzi, sur la purification de l’âme, le caractère et le détachement ; l’un des livres centraux du comportement chez les gens de la Sunna.",
        "O resumo por Ibn Qudama al-Maqdisi do Minhaj al-Qasidin de Ibn al-Jawzi, sobre purificação espiritual, carácter e desapego; um dos livros centrais de conduta entre Ahl as-Sunnah.",
        "Сокращение Ибн Кудамы аль-Макдиси книги Ибн аль-Джаузи «Минхадж аль-касидин» о духовном очищении, нраве и отрешённости; одна из главных книг о поведении у ахль ас-сунна.",
        "ابن قدامہ مقدسی کا ابن الجوزی کی «منہاج القاصدین» کا اختصار، تزکیہ، اخلاق اور زہد میں؛ اہلِ سنت کے ہاں سلوک کی اہم ترین کتابوں میں سے۔"],
    "al_fawaid": [
        "One of Ibn al-Qayyim's finest books: scattered benefits, admonitions and wisdoms on creed, conduct and upbringing, arranged not by chapter but by the turns of faith itself.",
        "Uno de los mejores libros de Ibn Al-Qayyim: beneficios, exhortaciones y sabidurías dispersas sobre credo, conducta y educación, ordenados no por capítulos sino por los movimientos de la fe.",
        "L’un des plus beaux livres d’Ibn al-Qayyim : bienfaits, exhortations et sagesses épars sur le credo, le comportement et l’éducation, classés non par chapitres mais au fil des élans de la foi.",
        "Um dos melhores livros de Ibn al-Qayyim: benefícios, exortações e sabedorias dispersas sobre credo, conduta e educação, organizados não por capítulos mas ao sabor dos impulsos da fé.",
        "Одна из лучших книг Ибн аль-Каййима: рассыпанные пользы, наставления и мудрости о вероучении, поведении и воспитании, расположенные не по главам, а по движениям самой веры.",
        "ابن القیم کی نفیس ترین کتابوں میں سے: عقیدہ، سلوک اور تربیت میں متفرق فوائد، مواعظ اور حکمتیں، ابواب پر نہیں بلکہ ایمانی خواطر کی ترتیب پر۔"],
    "sayd_al_khatir": [
        "Ibn al-Jawzi's passing thoughts and reflections on the self, religion and the world; among the most delicate writing on admonition and spiritual formation by the scholars of Ahl al-Sunnah.",
        "Los pensamientos y reflexiones de Ibn Al-Yawzi sobre el alma, la religión y el mundo; de lo más delicado que se ha escrito sobre exhortación y formación espiritual entre los sabios de Ahl as-Sunna.",
        "Les pensées et réflexions d’Ibn al-Jawzi sur l’âme, la religion et le monde ; parmi les pages les plus fines écrites sur l’exhortation et la formation spirituelle chez les savants de la Sunna.",
        "Os pensamentos e reflexões de Ibn al-Jawzi sobre a alma, a religião e o mundo; do mais delicado que se escreveu sobre exortação e formação espiritual entre os sábios de Ahl as-Sunnah.",
        "Мысли и размышления Ибн аль-Джаузи о душе, религии и мире; одно из самых тонких сочинений о наставлении и духовном воспитании у учёных ахль ас-сунна.",
        "ابن الجوزی کے خواطر اور نفس، دین اور دنیا پر ان کے تأملات؛ اہلِ سنت کے علما کے ہاں وعظ اور روحانی تربیت میں لکھی گئی نفیس ترین تحریروں میں سے۔"],
    "al_ubudiyyah": [
        "Ibn Taymiyyah's treatise on what servitude to Allah alone truly means, and that a servant's perfection lies in the perfection of his servitude to his Lord; among the most important works on the subject.",
        "Tratado de Ibn Taymiyya sobre el verdadero significado de la servidumbre a Al-lah solo, y que la perfección del siervo está en la perfección de su servidumbre a su Señor; de lo más importante escrito al respecto.",
        "Le traité d’Ibn Taymiyya sur le sens véritable de la servitude à Allah seul, et sur le fait que la perfection du serviteur réside dans la perfection de sa servitude envers son Seigneur ; parmi les écrits majeurs sur le sujet.",
        "O tratado de Ibn Taymiyyah sobre o verdadeiro significado da servidão só a Allah, e que a perfeição do servo está na perfeição da sua servidão ao seu Senhor; do mais importante que se escreveu sobre o tema.",
        "Трактат Ибн Таймийи о подлинном смысле поклонения одному лишь Аллаху и о том, что совершенство раба — в совершенстве его поклонения Господу; одно из важнейших сочинений в этой теме.",
        "ابن تیمیہ کا رسالہ، اللہ وحدہ کی عبودیت کے معنی کی تحقیق میں، اور یہ کہ بندے کا کمال اپنے رب کی عبودیت کے کمال میں ہے؛ اس باب میں لکھی گئی اہم ترین تحریروں میں سے۔"],
    "al_aqidah_al_wasitiyyah": [
        "Ibn Taymiyyah's celebrated treatise on the creed of Ahl al-Sunnah wa al-Jama'ah, written at the request of a judge from Wasit, and among the most commented on and widely circulated creedal texts.",
        "El célebre tratado de Ibn Taymiyya sobre el credo de Ahl as-Sunna wal-Yama'a, escrito a petición de un juez de Wasit, y de los textos de credo más comentados y difundidos.",
        "Le célèbre traité d’Ibn Taymiyya sur le credo des gens de la Sunna et du groupe, écrit à la demande d’un juge de Wasit, et l’un des textes de credo les plus commentés et les plus répandus.",
        "O célebre tratado de Ibn Taymiyyah sobre o credo de Ahl as-Sunnah wal-Jama'ah, escrito a pedido de um juiz de Wasit, e um dos textos de credo mais comentados e difundidos.",
        "Знаменитый трактат Ибн Таймийи о вероучении ахль ас-сунна ва-ль-джама‘а, написанный по просьбе судьи из Васита, и один из самых комментируемых и распространённых вероучительных текстов.",
        "ابن تیمیہ کا مشہور رسالہ، اہلِ سنت و الجماعت کے عقیدے میں، جو واسط کے ایک قاضی کی درخواست پر لکھا گیا، اور عقیدے کے سب سے زیادہ شرح شدہ اور متداول متون میں سے ہے۔"],
    "nawadir_al_usul": [
        "One of al-Hakim al-Tirmidhi's best known works, explaining principles drawn from prophetic hadith in a distinctive Sufi, formative style. Stated plainly: the book — like its author's standing among the hadith scholars — holds a number of weak and unestablished hadiths alongside the authentic, and should be read with that in mind.",
        "Una de las obras más conocidas de Al-Hakim At-Tirmidí, que explica principios extraídos del hadiz profético con un estilo sufí y formativo característico. Dicho con franqueza: el libro —como su autor entre los expertos en hadiz— contiene varios hadices débiles y no establecidos junto a los auténticos, y debe leerse teniéndolo en cuenta.",
        "L’un des ouvrages les plus connus d’al-Hakim at-Tirmidhi, expliquant des principes tirés du hadith prophétique dans un style soufi et formatif caractéristique. Dit franchement : le livre — comme son auteur auprès des spécialistes du hadith — contient plusieurs hadiths faibles et non établis à côté des authentiques, et doit être lu en le sachant.",
        "Uma das obras mais conhecidas de al-Hakim at-Tirmidhi, explicando princípios extraídos do hadith profético num estilo sufi e formativo característico. Dito com franqueza: o livro — tal como o seu autor junto dos especialistas em hadith — contém vários hadiths fracos e não estabelecidos a par dos autênticos, e deve ser lido com isso em mente.",
        "Одно из самых известных сочинений аль-Хакима ат-Тирмизи, разъясняющее основы, извлечённые из пророческих хадисов, в характерном суфийско-воспитательном стиле. Скажем прямо: книга — как и репутация её автора у знатоков хадиса — содержит ряд слабых и неустановленных хадисов наряду с достоверными, и читать её следует с этим в виду.",
        "حکیم ترمذی کی مشہور ترین تصانیف میں سے، جو حدیثِ نبوی سے مستنبط اصولوں کی شرح ایک ممتاز صوفیانہ تربیتی اسلوب میں کرتی ہے۔ دیانتاً تنبیہ: یہ کتاب — جیسا کہ اہلِ حدیث کے ہاں اس کے مصنف کا حال معروف ہے — صحیح کے ساتھ ساتھ متعدد ضعیف اور غیر ثابت احادیث بھی رکھتی ہے، اسے اسی اعتبار سے پڑھا جائے۔"],
    "al_samt_wa_adab_al_lisan": [
        "Ibn Abi al-Dunya's work on the merit of silence, guarding the tongue and the harms of speech, gathering hadiths and reports on the manners of speech and silence among the early generations.",
        "Obra de Ibn Abi ad-Dunya sobre el mérito del silencio, el cuidado de la lengua y los daños del habla, con hadices y relatos sobre los modales del habla y el silencio entre los primeros musulmanes.",
        "L’ouvrage d’Ibn Abi ad-Dunya sur le mérite du silence, la préservation de la langue et les méfaits de la parole, réunissant hadiths et récits sur les convenances de la parole et du silence chez les anciens.",
        "A obra de Ibn Abi ad-Dunya sobre o mérito do silêncio, o guardar da língua e os males da fala, reunindo hadiths e relatos sobre as maneiras da fala e do silêncio entre os antigos.",
        "Сочинение Ибн Аби ад-Дуньи о достоинстве молчания, хранении языка и вреде речей, собравшее хадисы и предания о том, как первые поколения относились к слову и молчанию.",
        "ابن ابی الدنیا کی تصنیف، خاموشی کی فضیلت، زبان کی حفاظت اور کلام کی آفتوں میں، جس میں سلف کے ہاں کلام و سکوت کے آداب پر احادیث و آثار جمع ہیں۔"],
    "qasr_al_amal": [
        "Ibn Abi al-Dunya's work on shortening one's hopes and the blame of long hope and procrastination, gathering hadiths and reports from the early generations on preparing for death and hastening to good deeds.",
        "Obra de Ibn Abi ad-Dunya sobre acortar las esperanzas y el reproche de la larga esperanza y la dilación, con hadices y relatos de los primeros musulmanes sobre prepararse para la muerte y apresurarse a las buenas obras.",
        "L’ouvrage d’Ibn Abi ad-Dunya sur le raccourcissement des espoirs et le blâme du long espoir et de l’ajournement, réunissant hadiths et récits des anciens sur la préparation à la mort et l’empressement aux bonnes œuvres.",
        "A obra de Ibn Abi ad-Dunya sobre encurtar as esperanças e a censura da longa esperança e do adiamento, reunindo hadiths e relatos dos antigos sobre preparar-se para a morte e apressar-se às boas obras.",
        "Сочинение Ибн Аби ад-Дуньи о сокращении надежд и порицании долгих упований и откладывания, собравшее хадисы и предания первых поколений о подготовке к смерти и спешке к благим делам.",
        "ابن ابی الدنیا کی تصنیف، قصرِ امل اور طولِ امل و تسویف کی مذمت میں، جس میں موت کی تیاری اور نیک عمل میں جلدی پر سلف کے احادیث و آثار جمع ہیں۔"],
    "al_hasanah_wa_al_sayyiah": [
        "Ibn Taymiyyah's treatise on the causes of good and evil deeds: that ignorance is the root of disobedience, and that beneficial knowledge produces the awe which drives a person to obedience and away from wrong.",
        "Tratado de Ibn Taymiyya sobre las causas de las buenas y las malas obras: que la ignorancia es la raíz de la desobediencia, y que el conocimiento provechoso produce el temor que lleva a la obediencia y aparta del mal.",
        "Le traité d’Ibn Taymiyya sur les causes des bonnes et des mauvaises actions : l’ignorance est la racine de la désobéissance, et la science utile engendre la crainte qui porte à l’obéissance et éloigne du mal.",
        "O tratado de Ibn Taymiyyah sobre as causas das boas e das más obras: que a ignorância é a raiz da desobediência, e que o conhecimento proveitoso gera o temor que leva à obediência e afasta do mal.",
        "Трактат Ибн Таймийи о причинах благих и дурных дел: невежество — корень ослушания, а полезное знание рождает трепет, который ведёт к покорности и удерживает от дурного.",
        "ابن تیمیہ کا رسالہ، حسنات و سیئات کے اسباب کے بیان میں، اور یہ کہ جہل معاصی کی جڑ ہے اور علمِ نافع وہ خشیت پیدا کرتا ہے جو طاعت پر آمادہ اور منکرات سے باز رکھتی ہے۔"],
    "adab_al_nafs": [
        "Al-Hakim al-Tirmidhi's work on disciplining and purifying the soul, treating the kinds of soul named in the Qur'an (the one that incites, the tranquil, the self-reproaching), the state of the heart, certainty, and the striving of the wayfarers.",
        "Obra de Al-Hakim At-Tirmidí sobre la disciplina y purificación del alma, que trata los tipos de alma nombrados en el Corán (la que incita, la serena y la que se reprocha), el estado del corazón, la certeza y el esfuerzo de los caminantes.",
        "L’ouvrage d’al-Hakim at-Tirmidhi sur la discipline et la purification de l’âme, traitant des types d’âme nommés dans le Coran (celle qui incite, l’apaisée, celle qui se blâme), de l’état du cœur, de la certitude et de l’effort des cheminants.",
        "A obra de al-Hakim at-Tirmidhi sobre a disciplina e purificação da alma, tratando dos tipos de alma nomeados no Alcorão (a que incita, a serena e a que se recrimina), do estado do coração, da certeza e do esforço dos caminhantes.",
        "Сочинение аль-Хакима ат-Тирмизи о воспитании и очищении души, разбирающее виды души, названные в Коране (побуждающая ко злу, умиротворённая, укоряющая), состояние сердца, убеждённость и усердие идущих по пути.",
        "حکیم ترمذی کی تصنیف، ریاضتِ نفس اور تزکیے میں، جس میں قرآن میں مذکور نفس کی اقسام (امّارہ، مطمئنہ، لوّامہ)، حالِ قلب، یقین اور سالکین کی مجاہدت زیرِ بحث ہیں۔"],
    "ar_raheeq_al_makhtum": [
        "A modern biography of the Prophet ﷺ, awarded first prize in the Muslim World League's competition on the sira, setting the events out year by year with the reports critically sifted.",
        "Biografía contemporánea del Profeta ﷺ, primer premio en el concurso de la Liga del Mundo Islámico sobre la sira, que expone los hechos año por año con las narraciones depuradas.",
        "Une biographie contemporaine du Prophète ﷺ, premier prix du concours de la Ligue islamique mondiale sur la sîra, présentant les événements année par année avec un tri critique des récits.",
        "Uma biografia contemporânea do Profeta ﷺ, primeiro prémio no concurso da Liga do Mundo Islâmico sobre a sira, expondo os acontecimentos ano a ano com as narrações depuradas.",
        "Современное жизнеописание Пророка ﷺ, получившее первую премию на конкурсе Всемирной исламской лиги по сире; события изложены год за годом, а сообщения критически отобраны.",
        "نبی ﷺ کی معاصر سیرت، جسے رابطہ عالم اسلامی کے سیرت مقابلے میں پہلا انعام ملا، جس میں واقعات سالوں کی ترتیب پر روایات کی تحقیق کے ساتھ جمع ہیں۔"],
    "seerat_ibn_hisham": [
        "The earliest biography to reach us complete: Ibn Hisham's refinement of Ibn Ishaq's sira. This electronic copy covers only the first two volumes of the edition named.",
        "La biografía más antigua que nos ha llegado completa: la depuración por Ibn Hisham de la sira de Ibn Ishaq. Esta copia electrónica abarca solo los dos primeros volúmenes de la edición indicada.",
        "La plus ancienne biographie qui nous soit parvenue complète : la mise au point par Ibn Hicham de la sîra d’Ibn Ishaq. Cette copie électronique ne couvre que les deux premiers volumes de l’édition indiquée.",
        "A mais antiga biografia que nos chegou completa: a depuração por Ibn Hisham da sira de Ibn Ishaq. Esta cópia eletrónica abrange apenas os dois primeiros volumes da edição indicada.",
        "Древнейшее жизнеописание, дошедшее до нас полностью: обработка Ибн Хишамом сиры Ибн Исхака. Электронная копия охватывает лишь первые два тома указанного издания.",
        "قدیم ترین سیرت جو ہم تک مکمل پہنچی: ابن ہشام کی جانب سے سیرتِ ابن اسحاق کی تہذیب۔ یہ برقی نسخہ مذکورہ طبع کی صرف پہلی دو جلدوں پر مشتمل ہے۔"],
    "zad_al_maad": [
        "The Prophet's ﷺ way in worship, dealings, expeditions and medicine, edited by the two al-Arna'uts. Among the most comprehensive works on prophetic guidance.",
        "La guía del Profeta ﷺ en su adoración, sus tratos, sus expediciones y su medicina, en la edición de los dos Al-Arna'ut. De lo más completo escrito sobre la guía profética.",
        "La voie du Prophète ﷺ dans son adoration, ses transactions, ses expéditions et sa médecine, dans l’édition des deux al-Arna'ut. Parmi les ouvrages les plus complets sur la guidance prophétique.",
        "O caminho do Profeta ﷺ na adoração, nos tratos, nas expedições e na medicina, na edição dos dois al-Arna'ut. Entre as obras mais completas sobre a orientação profética.",
        "Путь Пророка ﷺ в поклонении, в делах, в походах и во врачевании, в редакции двух аль-Арнаутов. Одно из самых полных сочинений о пророческом руководстве.",
        "نبی ﷺ کی ہدایت: عبادات، معاملات، غزوات اور طب میں، ارناؤوط صاحبین کی تحقیق کے ساتھ۔ ہدیِ نبوی پر لکھی گئی جامع ترین کتابوں میں سے۔"],
    "sahih_as_seerah_albani": [
        "The parts of Ibn Kathir's sira that al-Albani graded authentic, summarised and annotated by him. He died before completing it, so it ends at 2/94 of Abd al-Wahid's edition.",
        "Lo que se ha establecido como auténtico de la sira de Ibn Kazir, resumido y anotado por Al-Albani. Murió antes de terminarlo, de modo que acaba en 2/94 de la edición de Abd al-Wahid.",
        "Ce qui est établi comme authentique de la sîra d’Ibn Kathir, résumé et annoté par al-Albani. Il est mort avant de l’achever : l’ouvrage s’arrête à 2/94 de l’édition d’Abd al-Wahid.",
        "O que está estabelecido como autêntico da sira de Ibn Kathir, resumido e anotado por al-Albani. Morreu antes de a concluir, pelo que termina em 2/94 da edição de Abd al-Wahid.",
        "То, что достоверно установлено из сиры Ибн Касира, в сокращении и с комментариями аль-Альбани. Он умер, не завершив труд, поэтому книга обрывается на 2/94 издания Абд аль-Вахида.",
        "سیرتِ ابن کثیر میں سے جو صحیح ثابت ہے، البانی کی تلخیص اور تعلیق کے ساتھ۔ شیخ اس کی تکمیل سے پہلے وفات پا گئے، اس لیے یہ عبد الواحد کی طبع کے ٢/٩٤ پر ختم ہوتی ہے۔"],
    "uyun_al_athar": [
        "A sira composed on the method of the hadith scholars, covering the expeditions, the Prophet's qualities and his life; one of the standard works of sira among the later scholars.",
        "Una sira compuesta según el método de los expertos en hadiz, sobre las expediciones, las cualidades del Profeta y su vida; una de las obras de referencia de la sira entre los sabios posteriores.",
        "Une sîra composée selon la méthode des spécialistes du hadith, portant sur les expéditions, les qualités du Prophète et sa vie ; l’un des ouvrages de référence de la sîra chez les savants postérieurs.",
        "Uma sira composta segundo o método dos especialistas em hadith, sobre as expedições, as qualidades do Profeta e a sua vida; uma das obras de referência da sira entre os sábios posteriores.",
        "Сира, составленная по методу знатоков хадиса и охватывающая походы, качества Пророка и его жизнь; один из опорных трудов по сире у поздних учёных.",
        "محدثین کے منہج پر مرتب کی گئی سیرت، مغازی، شمائل اور سیر میں؛ متأخرین کے ہاں سیرت کی عمدہ کتابوں میں سے۔"],
    "nur_al_yaqin": [
        "A short, plainly worded biography written for teaching, which became famous and one of the most widely circulated abridgements.",
        "Una biografía breve y de expresión sencilla, escrita para la enseñanza, que se hizo famosa y llegó a ser uno de los resúmenes más difundidos.",
        "Une biographie brève et d’expression simple, écrite pour l’enseignement, devenue célèbre et l’un des abrégés les plus répandus.",
        "Uma biografia breve e de expressão simples, escrita para o ensino, que se tornou famosa e um dos resumos mais difundidos.",
        "Краткое жизнеописание простым языком, написанное для преподавания; оно стало известным и одним из самых распространённых сокращений.",
        "ایک مختصر اور سہل عبارت والی سیرت، جو تدریس کے لیے لکھی گئی، پھر مشہور ہوئی اور سب سے زیادہ متداول مختصرات میں شمار ہونے لگی۔"],
    "as_seerah_nadwi": [
        "A biography attentive to the historical setting — the state of the world before the mission and the effect the message had on it — in a fine literary style.",
        "Una biografía atenta al contexto histórico —el estado del mundo antes de la misión y el efecto que el mensaje tuvo en él— con un estilo literario refinado.",
        "Une biographie attentive au contexte historique — l’état du monde avant la mission et l’effet du message sur lui — dans un style littéraire raffiné.",
        "Uma biografia atenta ao contexto histórico — o estado do mundo antes da missão e o efeito que a mensagem teve sobre ele — num estilo literário refinado.",
        "Жизнеописание, внимательное к историческому контексту — состоянию мира до начала пророческой миссии и тому, как послание его изменило, — написанное изящным литературным слогом.",
        "ایک سیرت جو تاریخی سیاق پر توجہ دیتی ہے: بعثت سے پہلے دنیا کا حال اور اس پر رسالت کا اثر، بلند ادبی اسلوب میں۔"],
    "fiqh_as_seerah_ghazali": [
        "A reading of the sira that draws out its lessons, with Shaykh al-Albani's authentication of its hadiths.",
        "Una lectura de la sira que extrae de ella sus lecciones, con la verificación de sus hadices por el jeque Al-Albani.",
        "Une lecture de la sîra qui en tire les leçons, avec l’authentification de ses hadiths par le cheikh al-Albani.",
        "Uma leitura da sira que dela extrai as lições, com a verificação dos seus hadiths pelo xeque al-Albani.",
        "Прочтение сиры, извлекающее из неё уроки, с проверкой её хадисов шейхом аль-Альбани.",
        "سیرت کا ایک مطالعہ جو اس سے دروس و عبر مستنبط کرتا ہے، اس کی احادیث پر شیخ البانی کی تخریج کے ساتھ۔"],
    "as_seerah_ibn_kathir": [
        "The prophetic biography drawn out of al-Bidaya wa al-Nihaya, in which Ibn Kathir gathered the reports and discussed their chains.",
        "La biografía profética extraída de Al-Bidaya wan-Nihaya, en la que Ibn Kazir reunió las narraciones y habló de sus cadenas.",
        "La biographie prophétique extraite d’al-Bidaya wa an-Nihaya, dans laquelle Ibn Kathir a réuni les récits et discuté leurs chaînes.",
        "A biografia profética extraída de al-Bidaya wa an-Nihaya, na qual Ibn Kathir reuniu as narrações e discutiu as suas cadeias.",
        "Жизнеописание Пророка, извлечённое из «аль-Бидая ва-н-нихая», где Ибн Касир собрал сообщения и разобрал их иснады.",
        "«البدایہ والنہایہ» سے مستل سیرتِ نبویہ، جس میں ابن کثیر نے روایات جمع کیں اور ان کی اسانید پر کلام کیا۔"],
    "rijal_hawl_ar_rasul": [
        "Sixty portraits of the Companions of the Messenger of Allah ﷺ in a literary style; one of the most widely read introductions to that generation.",
        "Sesenta semblanzas de los Compañeros del Mensajero de Al-lah ﷺ en estilo literario; una de las obras más difundidas para conocer a aquella generación.",
        "Soixante portraits des Compagnons du Messager d’Allah ﷺ dans un style littéraire ; l’un des ouvrages les plus répandus pour faire connaître cette génération.",
        "Sessenta retratos dos Companheiros do Mensageiro de Allah ﷺ em estilo literário; uma das obras mais difundidas para dar a conhecer aquela geração.",
        "Шестьдесят жизнеописаний сподвижников Посланника Аллаха ﷺ в литературном стиле; одна из самых читаемых книг, знакомящих с тем поколением.",
        "رسول اللہ ﷺ کے صحابہ کے ساٹھ تراجم، ادبی اسلوب میں؛ نسلِ صحابہ سے تعارف کرانے والی سب سے زیادہ پھیلنے والی کتابوں میں سے۔"],
    "la_tahzan": [
        "A book on the softening of hearts and lightening the burden of the self, gathering verses, reports and wisdoms for facing worry and anxiety.",
        "Un libro de rocaiq y alivio del alma, que reúne aleyas, relatos y sabidurías para hacer frente a la angustia y la ansiedad.",
        "Un livre d’adoucissement des cœurs et d’allègement de l’âme, réunissant versets, récits et sagesses pour faire face au souci et à l’angoisse.",
        "Um livro de abrandamento dos corações e alívio da alma, reunindo versículos, relatos e sabedorias para enfrentar a preocupação e a ansiedade.",
        "Книга о смягчении сердец и облегчении душевного бремени, собравшая аяты, предания и мудрости для встречи с тревогой и печалью.",
        "رقائق اور نفس کی تسکین میں ایک کتاب، جو ہمّ و قلق کے مقابلے میں آیات، آثار اور حکمتیں جمع کرتی ہے۔"],
}


def main():
    from patch_book_desc import arabic_blurbs  # noqa: PLC0415
    ar = arabic_blurbs()
    missing = [k for k in BESPOKE if k not in ar]
    if missing:
        raise SystemExit("not in the catalogue: %s" % ", ".join(missing))

    added = 0
    for code in LOCALES:
        path = os.path.join(TR, "%s.json" % code)
        doc = json.loads(io.open(path, encoding="utf-8").read(),
                         object_pairs_hook=collections.OrderedDict)
        lib = doc.setdefault("library", collections.OrderedDict())
        if "book_desc_generated" not in lib:
            lib["book_desc_generated"] = TEMPLATE[code]
            added += 1
        bucket = doc.setdefault("book_desc", collections.OrderedDict())
        for key in sorted(BESPOKE):
            if key in bucket:
                continue
            bucket[key] = (ar[key] if code == "ar"
                           else BESPOKE[key][OTHER.index(code)])
            added += 1
        io.open(path, "w", encoding="utf-8").write(
            json.dumps(doc, ensure_ascii=False, indent=2) + "\n")
    print("added %d key/locale pairs (%d bespoke blurbs + the template)"
          % (added, len(BESPOKE)))


if __name__ == "__main__":
    import sys
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    main()
