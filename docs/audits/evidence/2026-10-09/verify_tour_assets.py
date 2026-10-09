"""Read-only frame/asset structural validation; does not certify screenshots."""
import json, math
from pathlib import Path

root = Path(__file__).resolve().parents[4]
tour = root / 'rafeeq_app/assets/tour'
frames = json.loads((tour / 'frames.json').read_text(encoding='utf-8'))
rows, errors = [], []
expected = {'ar', 'en', 'fr', 'es', 'pt', 'ru', 'ur'}
if set(frames) != expected:
    errors.append('Unexpected language set')
for locale, entries in frames.items():
    for key, frame in entries.items():
        path = tour / locale / f'{key}.webp'
        data = path.read_bytes() if path.exists() else b''
        rect, aspect = frame.get('r'), frame.get('a')
        valid = (isinstance(rect, list) and len(rect) == 4
                 and all(isinstance(n, (int, float)) and math.isfinite(n) for n in rect)
                 and rect[0] < rect[2] and rect[1] < rect[3]
                 and isinstance(aspect, (int, float)) and math.isfinite(aspect) and aspect > 0
                 and data[:4] == b'RIFF' and data[8:12] == b'WEBP')
        rows.append({'locale': locale, 'key': key, 'bytes': len(data), 'valid': valid})
        if not valid:
            errors.append(f'{locale}/{key}')
result = {'languages': sorted(frames), 'frames': len(rows), 'errors': errors,
          'scope': 'JSON geometry, referenced file existence and WebP signature only; no visual or source certification',
          'rows': rows}
out = Path(__file__).with_name('tour-assets-validation.json')
out.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding='utf-8')
print(json.dumps({k: v for k, v in result.items() if k != 'rows'}))
raise SystemExit(bool(errors))
