"""One-shot: add the P2-4b `library.text_*` / `library.edition_*` translation
keys to all 5 locale files, keeping exact key parity (enforced by
test/translation_parity_test.dart).

Pure string insertion so the diff is only the new lines — the rest of each
file is left byte-for-byte. Run once:

    python scripts/add_book_text_keys.py
"""
import io
import os

T = os.path.join(os.path.dirname(__file__), "..", "rafeeq_app",
                 "assets", "translations")

# key -> {locale: value}
KEYS = {
    "edition_image": {
        "ar": "مصوّر", "en": "Scanned", "es": "Escaneado",
        "ru": "Скан", "pt": "Digitalizado",
    },
    "edition_text": {
        "ar": "نص", "en": "Text", "es": "Texto", "ru": "Текст", "pt": "Texto",
    },
    "text_download": {
        "ar": "تنزيل النص", "en": "Download text", "es": "Descargar texto",
        "ru": "Скачать текст", "pt": "Baixar texto",
    },
    "text_open": {
        "ar": "فتح النص", "en": "Open text", "es": "Abrir texto",
        "ru": "Открыть текст", "pt": "Abrir texto",
    },
    "text_unavailable": {
        "ar": "لا تتوفر نسخة نصية لهذا الكتاب",
        "en": "No text edition for this book",
        "es": "No hay edición de texto para este libro",
        "ru": "Для этой книги нет текстовой версии",
        "pt": "Sem edição em texto para este livro",
    },
    "text_index": {
        "ar": "الفهرس", "en": "Index", "es": "Índice",
        "ru": "Оглавление", "pt": "Índice",
    },
    "text_index_filter": {
        "ar": "ابحث في الفهرس", "en": "Filter the index",
        "es": "Filtrar el índice", "ru": "Поиск в оглавлении",
        "pt": "Filtrar o índice",
    },
    "text_search": {
        "ar": "بحث في الكتاب", "en": "Search the book",
        "es": "Buscar en el libro", "ru": "Поиск по книге",
        "pt": "Pesquisar no livro",
    },
    "text_search_hint": {
        "ar": "اكتب كلمة أو عبارة", "en": "Type a word or phrase",
        "es": "Escribe una palabra o frase", "ru": "Введите слово или фразу",
        "pt": "Digite uma palavra ou frase",
    },
    "text_search_results": {
        "ar": "نتيجة", "en": "results", "es": "resultados",
        "ru": "результатов", "pt": "resultados",
    },
    "text_page": {
        "ar": "صفحة", "en": "Page", "es": "Página", "ru": "Стр.",
        "pt": "Página",
    },
    "text_goto": {
        "ar": "اذهب", "en": "Go", "es": "Ir", "ru": "Перейти", "pt": "Ir",
    },
    "text_goto_page": {
        "ar": "اذهب إلى صفحة الطبعة", "en": "Go to printed page",
        "es": "Ir a la página impresa",
        "ru": "Перейти к странице издания",
        "pt": "Ir para a página impressa",
    },
    "text_bookmark": {
        "ar": "علامة مرجعية", "en": "Bookmark", "es": "Marcador",
        "ru": "Закладка", "pt": "Marcador",
    },
    "text_font_larger": {
        "ar": "تكبير الخط", "en": "Larger text", "es": "Texto más grande",
        "ru": "Крупнее шрифт", "pt": "Texto maior",
    },
    "text_font_smaller": {
        "ar": "تصغير الخط", "en": "Smaller text", "es": "Texto más pequeño",
        "ru": "Мельче шрифт", "pt": "Texto menor",
    },
    "text_source": {
        "ar": "مصدر النص", "en": "Text source", "es": "Fuente del texto",
        "ru": "Источник текста", "pt": "Fonte do texto",
    },
    "text_print_matches": {
        "ar": "ترقيم الصفحات مطابق للنسخة المطبوعة",
        "en": "Page numbers match the printed edition",
        "es": "La numeración coincide con la edición impresa",
        "ru": "Нумерация страниц соответствует печатному изданию",
        "pt": "A numeração corresponde à edição impressa",
    },
    "text_open_shamela": {
        "ar": "فتح في المكتبة الشاملة",
        "en": "Open in al-Maktaba al-Shamela",
        "es": "Abrir en al-Maktaba al-Shamela",
        "ru": "Открыть в аль-Мактаба аш-Шамиля",
        "pt": "Abrir na al-Maktaba al-Shamela",
    },
    "text_empty": {
        "ar": "لا يوجد نص", "en": "No text", "es": "Sin texto",
        "ru": "Нет текста", "pt": "Sem texto",
    },
    "text_blank_page": {
        "ar": "صفحة بلا نص", "en": "Blank page", "es": "Página en blanco",
        "ru": "Пустая страница", "pt": "Página em branco",
    },
    "text_ocr_badge": {
        "ar": "نص مستخرَج آلياً", "en": "Auto-extracted text",
        "es": "Texto extraído automáticamente",
        "ru": "Автоизвлечённый текст",
        "pt": "Texto extraído automaticamente",
    },
}

ANCHOR = '"cat_adab":'  # last existing key in the "library" block


def main():
    for loc in ("ar", "en", "es", "ru", "pt"):
        path = os.path.join(T, f"{loc}.json")
        with io.open(path, "r", encoding="utf-8", newline="") as f:
            s = f.read()
        if '"text_index"' in s:
            print(f"{loc}: already has the keys, skipping")
            continue
        nl = "\r\n" if "\r\n" in s else "\n"

        i = s.index(ANCHOR)
        # end of that key's line = the newline that follows its value
        line_end = s.index("\n", i)
        # strip a trailing \r if CRLF
        cut = line_end - 1 if s[line_end - 1] == "\r" else line_end

        additions = ""
        for key, vals in KEYS.items():
            v = vals[loc].replace("\\", "\\\\").replace('"', '\\"')
            additions += f',{nl}    "{key}": "{v}"'

        s = s[:cut] + additions + s[cut:]
        with io.open(path, "w", encoding="utf-8", newline="") as f:
            f.write(s)
        print(f"{loc}: added {len(KEYS)} keys")


if __name__ == "__main__":
    main()
