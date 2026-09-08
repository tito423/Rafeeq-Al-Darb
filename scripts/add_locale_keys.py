"""Add (or update) translation keys across every locale, in one step.

`test/translation_parity_test.dart` fails the build if the 7 locale files do not
carry an identical key set with no empty values — which is the point of it, and
which makes hand-editing seven JSON files the single most repetitive way to
break this project. This does the write for all of them from one table.

Usage:

    py -3 scripts/add_locale_keys.py path/to/keys.json

where keys.json is:

    {
      "more.ruqyah_title": {
        "ar": "الرقية الشرعية",
        "en": "Ruqyah",
        ...one entry per locale...
      }
    }

Every locale listed in LOCALES must be present for every key, or the script
refuses to write anything — a partial write is exactly the bug the parity test
exists to catch, and it is cheaper to catch it here.

Keys are dotted paths into the nested JSON. Existing keys are overwritten; the
file's own ordering is preserved for untouched keys and new keys are appended
inside their parent object.
"""

import io
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TRANSLATIONS = ROOT / "rafeeq_app" / "assets" / "translations"
LOCALES = ["ar", "en", "es", "fr", "pt", "ru", "ur"]


def set_path(obj, dotted, value):
    parts = dotted.split(".")
    for p in parts[:-1]:
        nxt = obj.get(p)
        if not isinstance(nxt, dict):
            if nxt is not None:
                raise SystemExit(
                    f"refusing to write: '{dotted}' would overwrite the "
                    f"non-object value at '{p}'"
                )
            nxt = {}
            obj[p] = nxt
        obj = nxt
    obj[parts[-1]] = value


def main():
    if len(sys.argv) != 2:
        raise SystemExit(__doc__)
    table = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))

    # Validate the whole table before touching a single file.
    for key, by_locale in table.items():
        missing = [loc for loc in LOCALES if loc not in by_locale]
        if missing:
            raise SystemExit(f"'{key}' is missing locales: {', '.join(missing)}")
        empty = [loc for loc, v in by_locale.items() if not str(v).strip()]
        if empty:
            raise SystemExit(f"'{key}' has empty values for: {', '.join(empty)}")

    for loc in LOCALES:
        path = TRANSLATIONS / f"{loc}.json"
        data = json.loads(path.read_text(encoding="utf-8"))
        for key, by_locale in table.items():
            set_path(data, key, by_locale[loc])
        # ensure_ascii=False keeps the Arabic readable in git diffs; the files
        # are already stored that way.
        with io.open(path, "w", encoding="utf-8", newline="\n") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
            f.write("\n")
        print(f"{loc}: +{len(table)} keys -> {path.name}")


if __name__ == "__main__":
    main()
