"""Inserts new translation keys into all 7 locales right after an existing
anchor key, without reformatting the files, and checks they still parse.

    py -3 scripts/add_i18n_keys.py <keys.json>

keys.json: {"anchor": "autoscroll_off_reciting",
            "keys": {"new_key": {"ar": "...", "en": "...", ...7 locales}}}
The anchor is matched as the first line starting with `"<anchor>":`, so pick
one that is unique in the file. A key already present near the anchor is
skipped, so re-running is harmless.
"""
import json
import sys
from pathlib import Path

T = Path(__file__).resolve().parent.parent / "rafeeq_app/assets/translations"
LANGS = ("ar", "en", "es", "fr", "pt", "ru", "ur")

spec = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
anchor, keys = spec["anchor"], spec["keys"]
for k, v in keys.items():
    missing = [l for l in LANGS if not v.get(l)]
    assert not missing, f"{k}: no {missing}"

for lang in LANGS:
    path = T / f"{lang}.json"
    lines = path.read_text(encoding="utf-8").split("\n")
    hits = [i for i, l in enumerate(lines) if l.strip().startswith(f'"{anchor}":')]
    assert len(hits) == 1, f"{lang}: anchor {anchor} found {len(hits)} times"
    idx = hits[0]
    indent = lines[idx][: len(lines[idx]) - len(lines[idx].lstrip())]
    near = lines[max(0, idx - 80): idx + 80]
    new = [f'{indent}"{k}": {json.dumps(v[lang], ensure_ascii=False)},' for k, v in keys.items()
           if not any(l.strip().startswith(f'"{k}":') for l in near)]
    if not new:
        continue
    if not lines[idx].rstrip().endswith(","):
        lines[idx] = lines[idx].rstrip() + ","
    if lines[idx + 1].strip().startswith("}"):
        new[-1] = new[-1].rstrip(",")
    lines[idx + 1: idx + 1] = new
    text = "\n".join(lines)
    json.loads(text)
    path.write_text(text, encoding="utf-8")
    print(lang, len(new), "keys")
