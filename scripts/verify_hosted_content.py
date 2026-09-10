# -*- coding: utf-8 -*-
"""Range-request every hosted content path the app depends on.

CLAUDE.md §6 step 1: "a range request against every hosted content path
(`hadith/hadith.zip`, a book, one page of each mushaf edition, a translation).
Record the actual results."

Trap #5: a soft-404 answers 200 with an HTML body, so status alone proves
nothing — the content type and the byte count are checked too.
Trap #19: R2's public endpoint answers a bare urllib request with 403; it wants
a User-Agent, so one is always sent.

    py -3 scripts/verify_hosted_content.py
"""

import io
import json
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
APP = os.path.join(ROOT, 'rafeeq_app')
REPORT = os.path.join(ROOT, 'content_verification.txt')

UA = ('RafeeqAlDarb/3.15 (https://github.com/tito423/Rafeeq-Al-Darb) curl/8')
R2 = 'https://pub-39dbef68a1a845d5ba669b43a59516b9.r2.dev'


def probe(url, expect_kind):
    """Fetch the first 2 KB. Returns (ok, note)."""
    try:
        out = subprocess.run(
            ['curl', '-sL', '--max-time', '60', '-r', '0-2047',
             '-A', UA, '-o', '-', '-w',
             '\\n__META__%{http_code}|%{content_type}|%{size_download}', url],
            capture_output=True, timeout=180)
    except subprocess.TimeoutExpired:
        return False, 'timed out'
    raw = out.stdout
    marker = raw.rfind(b'__META__')
    if marker < 0:
        return False, 'no response'
    body = raw[:marker]
    code, ctype, size = raw[marker + 8:].decode('ascii', 'replace').split('|')
    size = int(size or 0)
    if code not in ('200', '206'):
        return False, 'HTTP %s' % code
    if size == 0:
        return False, 'HTTP %s but zero bytes' % code
    # Trap #5: an HTML body where binary content was asked for is a soft-404.
    if b'<!DOCTYPE' in body[:400] or b'<html' in body[:400]:
        return False, 'HTML body (soft-404), %s' % ctype
    if expect_kind == 'zip' and not body.startswith(b'PK'):
        return False, 'not a zip (%r)' % body[:4]
    if expect_kind == 'image' and not (
            body.startswith(b'\xff\xd8') or body.startswith(b'\x89PNG')):
        return False, 'not a JPEG/PNG (%r)' % body[:4]
    if expect_kind == 'svg' and b'<svg' not in body[:600]:
        return False, 'not an SVG'
    return True, '%s %s %d B' % (code, ctype.split(';')[0], size)


checks = []

# ── the hadith database ──────────────────────────────────────────────────
checks.append(('hadith.zip', R2 + '/hadith/hadith.zip', 'zip'))

# ── one page of every mushaf edition ─────────────────────────────────────
ed_path = os.path.join(APP, 'assets', 'data', 'mushaf', 'editions.json')
doc = json.load(io.open(ed_path, encoding='utf-8'))
editions = doc['editions'] if isinstance(doc, dict) and 'editions' in doc else doc
for e in editions:
    eid = e.get('id')
    if e.get('is_raster') or e.get('image_path'):
        ext = e.get('image_ext', 'jpg')
        url = '%s/mushaf/%s/001.%s' % (R2, e.get('image_path', eid), ext)
        checks.append(('mushaf %s' % eid, url, 'image'))
    else:
        pin = 'b91d39e1065b57bdda3e94aca8ecf3575e50e1e6'
        url = ('https://raw.githubusercontent.com/quranpedia/quran-svg/'
               '%s/mushafs/%s/svg/001.svg' % (pin, e.get('source_path', '')))
        checks.append(('mushaf %s' % eid, url, 'svg'))

# ── a book, a translation, the encyclopaedia, an adhan video ─────────────
checks.append(('a library book', R2 + '/books/text/riyad_as_salihin.json', 'any'))
# The real shape, read out of AppConfig.quranTranslationUrl rather than
# guessed: '<base>/quran/translations/<lang>.json.gz'.
checks.append(('Quran translation en', R2 + '/quran/translations/en.json.gz', 'any'))
checks.append(('Quran translation ur', R2 + '/quran/translations/ur.json.gz', 'any'))
checks.append(('hadeethenc ar pack', R2 + '/hadeethenc/ar.zip', 'zip'))
checks.append(('hadeethenc en pack', R2 + '/hadeethenc/en.zip', 'zip'))

lines = []
failed = 0
for label, url, kind in checks:
    ok, note = probe(url, kind)
    if not ok:
        failed += 1
    lines.append('%-26s %-4s %s' % (label, 'ok' if ok else 'FAIL', note))

header = ['%d paths checked, %d failed' % (len(checks), failed), '']
io.open(REPORT, 'w', encoding='utf-8', newline='\n').write(
    '\n'.join(header + lines) + '\n')
sys.stdout.write(io.open(REPORT, encoding='utf-8').read())
sys.exit(1 if failed else 0)
