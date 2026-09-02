"""One-shot: add the P2‑5 `downloads.*` keys (unified hub / storage view) to
all 5 locale files at exact key parity.

Uses a full JSON round-trip (order-preserving) rather than string surgery —
`delete_confirm` exists in *two* sections, which broke the naive
anchor-on-key approach. `json` in 3.7+ keeps insertion order, so the only
change is the new keys appended to the `downloads` object; indentation is
kept at 2 spaces and line endings at CRLF to match the existing files.
"""
import io
import json
import os

T = os.path.join(os.path.dirname(__file__), "..", "rafeeq_app",
                 "assets", "translations")

KEYS = {
    "tab_overview": {
        "ar": "نظرة عامة", "en": "Overview", "es": "Resumen",
        "ru": "Обзор", "pt": "Visão geral",
    },
    "cat_mushafs": {
        "ar": "المصاحف", "en": "Mushafs", "es": "Ejemplares del Corán",
        "ru": "Мусхафы", "pt": "Exemplares do Alcorão",
    },
    "cat_recitations": {
        "ar": "التلاوات", "en": "Recitations", "es": "Recitaciones",
        "ru": "Чтения", "pt": "Recitações",
    },
    "cat_hadith": {
        "ar": "الحديث", "en": "Hadith", "es": "Hadiz",
        "ru": "Хадисы", "pt": "Hadith",
    },
    "cat_books": {
        "ar": "الكتب", "en": "Books", "es": "Libros",
        "ru": "Книги", "pt": "Livros",
    },
    "cat_adhan": {
        "ar": "الأذان (فيديو)", "en": "Adhan (video)", "es": "Adhán (vídeo)",
        "ru": "Азан (видео)", "pt": "Adhan (vídeo)",
    },
    "free": {
        "ar": "تفريغ", "en": "Free up", "es": "Liberar",
        "ru": "Очистить", "pt": "Liberar",
    },
    "free_all": {
        "ar": "تفريغ الكل", "en": "Free up all", "es": "Liberar todo",
        "ru": "Очистить всё", "pt": "Liberar tudo",
    },
    "free_confirm": {
        "ar": "حذف الملفات المنزَّلة لهذا القسم من الجهاز؟",
        "en": "Delete this category's downloaded files from the device?",
        "es": "¿Eliminar del dispositivo los archivos descargados de esta categoría?",
        "ru": "Удалить загруженные файлы этой категории с устройства?",
        "pt": "Excluir do dispositivo os arquivos baixados desta categoria?",
    },
    "nothing_downloaded": {
        "ar": "لا يوجد محتوى منزَّل", "en": "Nothing downloaded",
        "es": "Nada descargado", "ru": "Ничего не загружено",
        "pt": "Nada baixado",
    },
    "downloaded_items": {
        "ar": "العناصر المنزَّلة", "en": "Downloaded items",
        "es": "Elementos descargados", "ru": "Загруженные элементы",
        "pt": "Itens baixados",
    },
}


def main():
    for loc in ("ar", "en", "es", "ru", "pt"):
        path = os.path.join(T, f"{loc}.json")
        with io.open(path, "r", encoding="utf-8") as f:
            d = json.load(f)
        dl = d["downloads"]
        added = 0
        for key, vals in KEYS.items():
            if key not in dl:
                dl[key] = vals[loc]
                added += 1
        text = json.dumps(d, ensure_ascii=False, indent=2) + "\n"
        text = text.replace("\r\n", "\n").replace("\n", "\r\n")
        with io.open(path, "w", encoding="utf-8", newline="") as f:
            f.write(text)
        print(f"{loc}: +{added} keys, downloads now {len(dl)}")


if __name__ == "__main__":
    main()
