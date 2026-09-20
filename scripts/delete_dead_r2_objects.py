"""Delete the R2 objects nothing in the app fetches any more.

The owner asked for it on 2026-09-20 («وامسح الميتة من الr2»). Every prefix
below was checked against `lib/`, `assets/` and `test/` first: the only
mentions left are comments, licence notes and tests that assert the printing
is GONE. `mushaf/madinah_qc/` (the one live printing), `ruqyah/`, `tts/`,
`books/`, `hadith*`, `quran/translations/` and `channels/` are not touched.

Writes the full key list it is about to remove to `docs/r2/deleted_<stamp>.txt`
before deleting anything, so what was there stays on the record.
"""
import io
import sys
import time

sys.path.insert(0, 'scripts')
from r2_common import r2_client  # noqa: E402

BUCKET = 'rafeeq-content'

# Nine printings retired by the 3.43.0 mushaf swap, plus the adhan background
# clips the owner had already asked to be deleted («احذف الكليبات») and whose
# player, catalogue and pipeline scripts went with them.
DEAD = [
    'mushaf/hafs/',              # the 348 MB SVG set madinah_qc replaced
    'mushaf/madinah_gold/',
    'mushaf/tajweed/',
    'mushaf/madinah_nastaleeq/',
    'mushaf/qatar/',
    'mushaf/kuwait/',
    'mushaf/madinah_night/',
    'mushaf/indopak_tajweed/',
    'mushaf/shamarly/',
    'adhan/video/',
]

KEEP_GUARD = 'mushaf/madinah_qc/'


def main() -> int:
    apply = '--apply' in sys.argv
    c = r2_client()
    paginator = c.get_paginator('list_objects_v2')

    keys: list[tuple[str, int]] = []
    for prefix in DEAD:
        assert not KEEP_GUARD.startswith(prefix), prefix
        for page in paginator.paginate(Bucket=BUCKET, Prefix=prefix):
            for obj in page.get('Contents', []):
                keys.append((obj['Key'], obj['Size']))

    total = sum(size for _, size in keys)
    stamp = time.strftime('%Y%m%d-%H%M%S')
    record = 'docs/r2/deleted_%s.txt' % stamp
    with io.open(record, 'w', encoding='utf-8') as fh:
        for key, size in keys:
            fh.write('%s\t%d\n' % (key, size))
        fh.write('\n%d objects\t%d bytes\t%.2f MB\n'
                 % (len(keys), total, total / 1048576))
    print('%d objects, %d bytes (%.2f MB) listed in %s'
          % (len(keys), total, total / 1048576, record))

    if not apply:
        print('dry run - pass --apply to delete')
        return 0

    done = 0
    for i in range(0, len(keys), 1000):
        batch = [{'Key': k} for k, _ in keys[i:i + 1000]]
        res = c.delete_objects(Bucket=BUCKET, Delete={'Objects': batch,
                                                      'Quiet': True})
        errs = res.get('Errors', [])
        if errs:
            print('ERRORS:', errs[:5])
            return 1
        done += len(batch)
        print('deleted %d/%d' % (done, len(keys)))

    # Prove it: every dead prefix must now be empty, and the live one intact.
    for prefix in DEAD:
        left = c.list_objects_v2(Bucket=BUCKET, Prefix=prefix, MaxKeys=1)
        print('%-30s remaining=%d' % (prefix, left.get('KeyCount', 0)))
    live = c.list_objects_v2(Bucket=BUCKET, Prefix=KEEP_GUARD)
    print('%-30s remaining=%d' % (KEEP_GUARD, live.get('KeyCount', 0)))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
