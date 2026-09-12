# -*- coding: utf-8 -*-
"""Fix the source line printed under the new books.

Opening «أحكام الجنائز» on the device showed the bug the catalogue's own
fields did not: the footer read

    المكتبة الشاملة — أحكام الجنائز، لـالإمام البخاري — بأحكام الألباني، ...

al-Albani's book, credited to al-Bukhari. The `sourceLabel` strings were built
by the crawler from the manifest's inherited `authorAr` — the same wrong field
that was corrected in `authorAr`/`authorEn` when the entries were written, and
the same wrong field that had already been baked into these labels. §1.2: a
book's attribution is not a cosmetic string.

So every one of the twenty-eight new entries gets its label rebuilt from the
manifest with the manifest's author swapped for the real one, and «لـالشيخ» /
«لـالحافظ» tidied to «للشيخ» / «للحافظ», which is how the phrase is actually
written.

Nothing outside the twenty-eight is touched — «صحيح الأدب المفرد» really is
al-Bukhari's text with al-Albani's gradings and keeps its label.
"""
import io
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from shamela_catalog_three_batches import (  # noqa: E402
    CATALOG, MANIFESTS, PLAN, ROOT, dart_str, wrap)

DROPPED = {'sahih_al_sirah_al_nabawiyyah'}  # the duplicate, already removed


def fixed_label(raw, manifest_author, real_author):
    out = raw.replace(manifest_author, real_author)
    out = out.replace('لـالشيخ', 'للشيخ').replace('لـالحافظ', 'للحافظ')
    out = out.replace('لـأبو', 'لأبي')
    return out


def main():
    apply = '--apply' in sys.argv
    src = io.open(CATALOG, encoding='utf-8').read()
    changed = 0

    for name in MANIFESTS:
        path = os.path.join(ROOT, 'scripts', name)
        for b in json.load(io.open(path, encoding='utf-8')):
            new_id, _, _, author, _ = PLAN[b['slug']]
            if new_id in DROPPED:
                continue
            want = fixed_label(b['sourceLabel'], b['authorAr'], author[0])

            # The entry's sourceLabel is one or more adjacent Dart literals
            # after `sourceLabel:` — replace the whole group.
            anchor = "url: '${AppConfig.contentBaseUrl}/books/text/%s.json'" \
                     % new_id
            at = src.find(anchor)
            if at < 0:
                print('MISSING in catalogue: %s' % new_id)
                return 1
            lab = src.find('sourceLabel:', at)
            end = src.find('\n    ),', lab)
            block = src[lab:end]
            current = ''.join(re.findall(r"'((?:[^'\\]|\\.)*)'", block))
            if current == want:
                continue
            src = (src[:lab]
                   + 'sourceLabel:\n          ' + wrap(want, 10)
                   + ',' + src[end:])
            changed += 1
            print('%-40s %s' % (new_id, want[:70]))

    print('\n%d labels rebuilt' % changed)
    if not apply:
        print('dry run; re-run with --apply')
        return 0
    io.open(CATALOG, 'w', encoding='utf-8', newline='\n').write(src)
    print('written')
    return 0


if __name__ == '__main__':
    sys.exit(main())
