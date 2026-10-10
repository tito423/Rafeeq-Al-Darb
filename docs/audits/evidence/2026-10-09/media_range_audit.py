"""Resumable bounded live GET checks of all catalogue binary samples.

Stores no audio/video/model files in the repository. A range sample is not a
full decoder or listening test. Servers that ignore ranges are reported apart.
"""
from pathlib import Path
import concurrent.futures, hashlib, json, re, subprocess, tempfile, time

root = Path('E:/My Projects/Rafiq-Al-Darb')
out = root / 'docs/audits/evidence/2026-10-09'
items = [x for x in json.loads((out / 'endpoint-inventory.json').read_text(encoding='utf-8'))
         if x['kind'] not in ['book', 'translation', 'hadeethenc', 'hadith', 'sciences']]
source = 'rafeeq_app/lib/features/channels/data/islamic_channels.dart'
code = (root / source).read_text(encoding='utf-8')
for match in re.finditer(r'IslamicChannel\(\s*id:\s*\x27([^\x27]+)\x27,(.*?)\n  \)', code, re.S):
    ident, body = match.groups()
    if 'hasPhoto: false' not in body:
        items.append(dict(kind='channel-avatar', url=f'https://pub-39dbef68a1a845d5ba669b43a59516b9.r2.dev/channels/{ident}.jpg',
                          path=source, line=code[:match.start()].count('\n')+1))
seen = {x['url']:x for x in items}
log = out / 'media-ranges.jsonl'
existing = [json.loads(line) for line in log.read_text(encoding='utf-8').splitlines()] if log.exists() else []
finished = {x['url'] for x in existing if x.get('transport_ok')}
pending = [x for u, x in seen.items() if u not in finished]

def check(item):
    started = time.monotonic()
    with tempfile.TemporaryDirectory(prefix='rafeeq_range_') as directory:
        dest, headers = Path(directory)/'sample.bin', Path(directory)/'headers.txt'
        process = subprocess.run(['curl.exe', '-sS', '-L', '--range', '0-1023', '--max-time', '30',
            '--max-filesize', '1048576', '-D', str(headers), '-o', str(dest), '-w', '%{http_code}',
            '-A', 'RafeeqAudit/2026-10-10 (https://github.com/tito423/Rafeeq-Al-Darb)', item['url']],
            capture_output=True, text=True)
        data = dest.read_bytes() if dest.exists() else b''
        head = headers.read_text(errors='replace') if headers.exists() else ''
        types = re.findall(r'^content-type:\s*(.+)', head, re.M|re.I)
        ranges = re.findall(r'^content-range:\s*(.+)', head, re.M|re.I)
        http = int(process.stdout[-3:]) if process.stdout[-3:].isdigit() else 0
        mime = types[-1].strip() if types else ''
        html = 'text/html' in mime or data.lstrip()[:15].lower().startswith((b'<!doctype html', b'<html'))
        hint = ('jpeg' if data[:2] == b'\xff\xd8' else 'png' if data[:8] == b'\x89PNG\r\n\x1a\n'
                else 'mp4/m4a' if data[4:8] == b'ftyp' else 'mp3-id3' if data[:3] == b'ID3'
                else 'mpeg-frame' if len(data)>1 and data[0]==255 and data[1]&224==224
                else 'text-tokens' if item['url'].endswith('tokens.txt') else 'unclassified-binary')
        return dict(item, http=http, curl_exit=process.returncode, mime=mime,
                    content_range=ranges[-1].strip() if ranges else None,
                    received_bytes=len(data), sample_sha256=hashlib.sha256(data).hexdigest(),
                    magic_hex=data[:16].hex(), format_hint=hint, html=html,
                    transport_ok=process.returncode==0 and http in [200,206] and bool(data) and not html,
                    range_ignored=http==200, bounded_download_stopped=process.returncode==63,
                    seconds=round(time.monotonic()-started,3))

print('Binary catalogue endpoints',len(seen),'pending',len(pending),flush=True)
with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
    for index, result in enumerate(pool.map(check,pending),1):
        existing.append(result)
        with log.open('a',encoding='utf-8') as stream:
            stream.write(json.dumps(result,ensure_ascii=False)+'\n')
        if index % 100 == 0:
            print('Checked',index,'current unsuccessful',sum(not x['transport_ok'] for x in existing),flush=True)
latest = {x['url']:x for x in existing}
summary = dict(total=len(seen),completed=len(latest), failures=[x for x in latest.values() if not x['transport_ok']],
               unclassified=[x for x in latest.values() if x['format_hint']=='unclassified-binary'],
               scope='Range0-1023 actual bytes/magic, transport and non-HTML; no whole-file integrity, religious/audio identity or decoder certification.')
(out/'media-ranges-summary.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2),encoding='utf-8')
print('Complete',len(latest),'unsuccessful',len(summary['failures']),'unclassified',len(summary['unclassified']),flush=True)
