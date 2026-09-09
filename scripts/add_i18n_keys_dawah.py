# -*- coding: utf-8 -*-
"""Descriptions for the ten dawah channels and five Islamic sites, in all
seven locales.

The NAMES stay Arabic and are rendered with `ArabicText`: they are the real
names of Arabic-language channels and sites, and a proper noun is not
translated. What a French or Russian reader needs is to understand what each
one IS, which is the description - and that was hardcoded in Arabic.
"""

import collections
import io
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TR = os.path.join(ROOT, "rafeeq_app", "assets", "translations")

DESCRIPTIONS = {
    "ch_sergany": {
        "ar": "تاريخ إسلامي وسيرة نبوية وحضارة",
        "en": "Islamic history, the Prophet's biography and civilisation",
        "es": "Historia islámica, biografía del Profeta y civilización",
        "fr": "Histoire islamique, biographie du Prophète et civilisation",
        "pt": "História islâmica, biografia do Profeta e civilização",
        "ru": "Исламская история, жизнеописание Пророка и цивилизация",
        "ur": "اسلامی تاریخ، سیرتِ نبوی اور تہذیب"},
    "ch_husseiny": {
        "ar": "مقارنة أديان وعقيدة ودعوة",
        "en": "Comparative religion, creed and dawah",
        "es": "Religión comparada, credo y dawah",
        "fr": "Religions comparées, credo et dawa",
        "pt": "Religião comparada, credo e dawah",
        "ru": "Сравнительное религиоведение, вероучение и призыв",
        "ur": "تقابلِ ادیان، عقیدہ اور دعوت"},
    "ch_amgad": {
        "ar": "فقه وعلوم شرعية وتزكية",
        "en": "Fiqh, the sharia sciences and spiritual purification",
        "es": "Fiqh, ciencias islámicas y purificación espiritual",
        "fr": "Fiqh, sciences islamiques et purification spirituelle",
        "pt": "Fiqh, ciências islâmicas e purificação espiritual",
        "ru": "Фикх, шариатские науки и очищение души",
        "ur": "فقہ، شرعی علوم اور تزکیہ"},
    "ch_arabi": {
        "ar": "تدبر القرآن الكريم وعلومه",
        "en": "Reflecting on the Qur'an and its sciences",
        "es": "Reflexión sobre el Corán y sus ciencias",
        "fr": "Méditation du Coran et de ses sciences",
        "pt": "Reflexão sobre o Alcorão e as suas ciências",
        "ru": "Размышление над Кораном и его науками",
        "ur": "قرآن اور اس کے علوم میں تدبر"},
    "ch_haytham": {
        "ar": "ردود علمية وفكرية على الإلحاد والشبهات",
        "en": "Scientific and intellectual answers to atheism and objections",
        "es": "Respuestas científicas e intelectuales al ateísmo y a las objeciones",
        "fr": "Réponses scientifiques et intellectuelles à l’athéisme et aux objections",
        "pt": "Respostas científicas e intelectuais ao ateísmo e às objeções",
        "ru": "Научные и интеллектуальные ответы атеизму и сомнениям",
        "ur": "الحاد اور شبہات کے علمی و فکری جوابات"},
    "ch_fahem": {
        "ar": "محتوى فكري إسلامي بأسلوب بصري عصري",
        "en": "Islamic thought in a modern visual style",
        "es": "Pensamiento islámico con un estilo visual moderno",
        "fr": "Pensée islamique dans un style visuel moderne",
        "pt": "Pensamento islâmico num estilo visual moderno",
        "ru": "Исламская мысль в современном визуальном стиле",
        "ur": "جدید بصری انداز میں اسلامی فکری مواد"},
    "ch_qunaibi": {
        "ar": "فكر إسلامي وردود على الشبهات المعاصرة",
        "en": "Islamic thought and answers to contemporary objections",
        "es": "Pensamiento islámico y respuestas a las objeciones contemporáneas",
        "fr": "Pensée islamique et réponses aux objections contemporaines",
        "pt": "Pensamento islâmico e respostas às objeções contemporâneas",
        "ru": "Исламская мысль и ответы на современные сомнения",
        "ur": "اسلامی فکر اور معاصر شبہات کے جوابات"},
    "ch_makany": {
        "ar": "محتوى دعوي وتعليمي هادف",
        "en": "Purposeful dawah and educational content",
        "es": "Contenido de dawah y educativo con propósito",
        "fr": "Contenu de dawa et pédagogique utile",
        "pt": "Conteúdo de dawah e educativo com propósito",
        "ru": "Целенаправленный призыв и обучающий контент",
        "ur": "بامقصد دعوتی و تعلیمی مواد"},
    "ch_ayman": {
        "ar": "محتوى إيماني ودعوي متنوع",
        "en": "Varied faith-building and dawah content",
        "es": "Contenido variado de fe y dawah",
        "fr": "Contenu varié de foi et de dawa",
        "pt": "Conteúdo variado de fé e dawah",
        "ru": "Разнообразный контент о вере и призыве",
        "ur": "متنوع ایمانی و دعوتی مواد"},
    "ch_waei": {
        "ar": "وعي فكري إسلامي معاصر",
        "en": "Contemporary Islamic intellectual awareness",
        "es": "Conciencia intelectual islámica contemporánea",
        "fr": "Conscience intellectuelle islamique contemporaine",
        "pt": "Consciência intelectual islâmica contemporânea",
        "ru": "Современное исламское интеллектуальное просвещение",
        "ur": "معاصر اسلامی فکری شعور"},

    "site_islamqa": {
        "ar": "أكبر موقع إسلامي للفتاوى والأسئلة الشرعية بإشراف الشيخ محمد صالح المنجد",
        "en": "The largest Islamic fatwa and questions site, supervised by Shaykh Muhammad Salih al-Munajjid",
        "es": "El mayor sitio islámico de fatuas y preguntas, supervisado por el jeque Muhammad Salih al-Munajjid",
        "fr": "Le plus grand site islamique de fatwas et de questions, supervisé par le cheikh Muhammad Salih al-Munajjid",
        "pt": "O maior site islâmico de fatwas e perguntas, supervisionado pelo xeque Muhammad Salih al-Munajjid",
        "ru": "Крупнейший исламский сайт фетв и вопросов под руководством шейха Мухаммада Салиха аль-Мунаджида",
        "ur": "فتاویٰ اور شرعی سوالات کی سب سے بڑی اسلامی ویب سائٹ، شیخ محمد صالح المنجد کی نگرانی میں"},
    "site_dorar": {
        "ar": "موسوعة شاملة للحديث النبوي والعقيدة والفقه وتخريج الأحاديث",
        "en": "A comprehensive encyclopedia of hadith, creed, fiqh and hadith authentication",
        "es": "Enciclopedia completa de hadiz, credo, fiqh y verificación de hadices",
        "fr": "Une encyclopédie complète du hadith, du credo, du fiqh et de l’authentification des hadiths",
        "pt": "Uma enciclopédia completa de hadith, credo, fiqh e autenticação de hadiths",
        "ru": "Полная энциклопедия хадисов, вероучения, фикха и проверки хадисов",
        "ur": "حدیث، عقیدہ، فقہ اور تخریجِ احادیث کا جامع انسائیکلوپیڈیا"},
    "site_islamway": {
        "ar": "دروس ومحاضرات ومقالات إسلامية من كبار العلماء والدعاة",
        "en": "Islamic lessons, lectures and articles from leading scholars and preachers",
        "es": "Lecciones, conferencias y artículos islámicos de grandes sabios y predicadores",
        "fr": "Cours, conférences et articles islamiques de grands savants et prédicateurs",
        "pt": "Lições, conferências e artigos islâmicos de grandes sábios e pregadores",
        "ru": "Исламские уроки, лекции и статьи ведущих учёных и проповедников",
        "ur": "بڑے علما اور داعیوں کے اسلامی دروس، محاضرات اور مضامین"},
    "site_saaid": {
        "ar": "مكتبة إسلامية شاملة تضم مقالات وكتب ومحاضرات متنوعة",
        "en": "A broad Islamic library of articles, books and lectures",
        "es": "Una amplia biblioteca islámica de artículos, libros y conferencias",
        "fr": "Une vaste bibliothèque islamique d’articles, de livres et de conférences",
        "pt": "Uma ampla biblioteca islâmica de artigos, livros e conferências",
        "ru": "Обширная исламская библиотека статей, книг и лекций",
        "ur": "مضامین، کتب اور محاضرات پر مشتمل جامع اسلامی کتب خانہ"},
    "site_alukah": {
        "ar": "شبكة علمية ثقافية تضم بحوثاً ومقالات أكاديمية إسلامية",
        "en": "A scholarly and cultural network of Islamic academic research and articles",
        "es": "Red académica y cultural con investigaciones y artículos islámicos",
        "fr": "Un réseau scientifique et culturel de recherches et d’articles académiques islamiques",
        "pt": "Uma rede académica e cultural de investigação e artigos islâmicos",
        "ru": "Научно-культурная сеть исламских академических исследований и статей",
        "ur": "اسلامی تحقیقی و علمی مضامین پر مشتمل علمی و ثقافتی نیٹ ورک"},
}

LOCALES = ["ar", "en", "es", "fr", "pt", "ru", "ur"]


def main():
    added = 0
    for code in LOCALES:
        path = os.path.join(TR, "%s.json" % code)
        doc = json.loads(io.open(path, encoding="utf-8").read(),
                         object_pairs_hook=collections.OrderedDict)
        bucket = doc.setdefault("dawah", collections.OrderedDict())
        for key, per_locale in DESCRIPTIONS.items():
            if key in bucket:
                continue
            bucket[key] = per_locale[code]
            added += 1
        io.open(path, "w", encoding="utf-8").write(
            json.dumps(doc, ensure_ascii=False, indent=2) + "\n")
    print("added %d key/locale pairs" % added)


if __name__ == "__main__":
    main()
