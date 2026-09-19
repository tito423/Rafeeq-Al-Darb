"""Install the per-printing ayah maps built by build_printing_map.py.

    py -3 scripts/install_printing_maps.py [edition ...]

For each scanned printing:
* writes rafeeq_app/assets/data/mushaf/<edition>_polygons.json - the same
  shape as hafs_kfqc_polygons.json, but measured on THIS printing's scans,
  in the page box's own 0..1 space;
* points the edition at it in editions.json and gives every VERIFIED page an
  identity fit carrying that page's box aspect. A page the builder could not
  verify gets no fit, so the app shows it with no highlight at all rather
  than a wrong one (see MushafEdition.fitForPage).
"""
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HL = os.path.join(ROOT, 'rafeeq_app', 'build', 'hl')
MUSHAF = os.path.join(ROOT, 'rafeeq_app', 'assets', 'data', 'mushaf')
EDITIONS = os.path.join(MUSHAF, 'editions.json')


def main():
    eds = sys.argv[1:] or ['tajweed_color', 'madinah_gold', 'qatar', 'kuwait']
    raw = open(EDITIONS, encoding='utf-8').read()
    doc = json.loads(raw)
    for ed in eds:
        own = json.load(open(os.path.join(HL, f'own_{ed}.json'), encoding='utf-8'))
        pages = {p: [[s, a, [[[round(x, 4), round(y, 4)] for x, y in ring] for ring in rings]]
                     for s, a, rings in rows]
                 for p, rows in sorted(own['pages'].items(), key=lambda kv: int(kv[0]))}
        asset = f'assets/data/mushaf/{ed}_polygons.json'
        json.dump({
            'version': 1,
            'edition': ed,
            'source': 'Measured on this printing\'s own page scans by '
                      'scripts/build_printing_map.py: ayah markers found on the '
                      'scan, each ayah running from the previous marker to its '
                      'own; every page verified before it is included.',
            'coords': 'normalized 0..1 of the page box (the scan contained in '
                      'an AspectRatio of the page\'s own aspect)',
            'pages': pages,
        }, open(os.path.join(ROOT, 'rafeeq_app', asset), 'w', encoding='utf-8'),
            ensure_ascii=False, separators=(',', ':'))
        e = next(x for x in doc['editions'] if x['id'] == ed)
        e['polygons_asset'] = asset
        e['polygon_fit'] = {
            'source_edition': ed,
            'pages': {p: {'sx': 1.0, 'dx': 0.0, 'sy': 1.0, 'dy': 0.0,
                          'page_aspect': round(own['aspect'][p], 6)}
                      for p in pages},
        }
        print(f'{ed}: {len(pages)} verified pages installed')
    open(EDITIONS, 'w', encoding='utf-8').write(
        json.dumps(doc, ensure_ascii=False, indent=1) + ('\n' if raw.endswith('\n') else ''))


if __name__ == '__main__':
    main()
