"""Adds the library's bulk-selection strings to all 7 locales, right after
`library.download_author_all`, without reformatting the files.

    py -3 scripts/add_library_select_keys.py
"""
import json
from pathlib import Path

T = Path(__file__).resolve().parent.parent / "rafeeq_app/assets/translations"

KEYS = {
    "download_section_all": {
        "ar": "تحميل كل كتب القسم ({})", "en": "Download every book in this section ({})",
        "es": "Descargar todos los libros de esta sección ({})", "fr": "Télécharger tous les livres de cette section ({})",
        "pt": "Baixar todos os livros desta seção ({})", "ru": "Скачать все книги раздела ({})",
        "ur": "اس حصے کی سب کتابیں ڈاؤن لوڈ کریں ({})"},
    "download_list_all": {
        "ar": "تحميل الكل ({})", "en": "Download all ({})", "es": "Descargar todo ({})",
        "fr": "Tout télécharger ({})", "pt": "Baixar tudo ({})", "ru": "Скачать все ({})",
        "ur": "سب ڈاؤن لوڈ کریں ({})"},
    "select": {
        "ar": "تحديد", "en": "Select", "es": "Seleccionar", "fr": "Sélectionner",
        "pt": "Selecionar", "ru": "Выбрать", "ur": "منتخب کریں"},
    "select_cancel": {
        "ar": "إلغاء التحديد", "en": "Cancel selection", "es": "Cancelar selección",
        "fr": "Annuler la sélection", "pt": "Cancelar seleção", "ru": "Отменить выбор",
        "ur": "انتخاب منسوخ کریں"},
    "select_all": {
        "ar": "تحديد الكل", "en": "Select all", "es": "Seleccionar todo", "fr": "Tout sélectionner",
        "pt": "Selecionar tudo", "ru": "Выбрать все", "ur": "سب منتخب کریں"},
    "selected_n": {
        "ar": "المحدد: {}", "en": "Selected: {}", "es": "Seleccionados: {}", "fr": "Sélectionnés : {}",
        "pt": "Selecionados: {}", "ru": "Выбрано: {}", "ur": "منتخب: {}"},
    "download_n": {
        "ar": "تحميل ({})", "en": "Download ({})", "es": "Descargar ({})", "fr": "Télécharger ({})",
        "pt": "Baixar ({})", "ru": "Скачать ({})", "ur": "ڈاؤن لوڈ ({})"},
    "delete_n": {
        "ar": "حذف ({})", "en": "Delete ({})", "es": "Eliminar ({})", "fr": "Supprimer ({})",
        "pt": "Excluir ({})", "ru": "Удалить ({})", "ur": "حذف ({})"},
    "delete_n_confirm": {
        "ar": "حذف {} من الكتب المحمّلة من الجهاز؟", "en": "Delete {} downloaded books from this device?",
        "es": "¿Eliminar {} libros descargados de este dispositivo?",
        "fr": "Supprimer {} livres téléchargés de cet appareil ?",
        "pt": "Excluir {} livros baixados deste dispositivo?",
        "ru": "Удалить с устройства скачанные книги: {}?",
        "ur": "اس آلے سے {} ڈاؤن لوڈ شدہ کتابیں حذف کریں؟"},
}

for lang in ("ar", "en", "es", "fr", "pt", "ru", "ur"):
    path = T / f"{lang}.json"
    lines = path.read_text(encoding="utf-8").split("\n")
    idx = next(i for i, l in enumerate(lines) if l.strip().startswith('"download_author_all"'))
    indent = lines[idx][: len(lines[idx]) - len(lines[idx].lstrip())]
    if not lines[idx].rstrip().endswith(","):
        lines[idx] = lines[idx].rstrip() + ","
    new = [f'{indent}"{k}": {json.dumps(v[lang], ensure_ascii=False)},' for k, v in KEYS.items()
           if not any(l.strip().startswith(f'"{k}"') for l in lines[idx - 60: idx + 60])]
    if not new:
        continue
    nxt = lines[idx + 1].strip()
    if nxt.startswith("}"):
        new[-1] = new[-1].rstrip(",")
    lines[idx + 1: idx + 1] = new
    text = "\n".join(lines)
    json.loads(text)  # still valid JSON
    path.write_text(text, encoding="utf-8")
    print(lang, len(new), "keys")
