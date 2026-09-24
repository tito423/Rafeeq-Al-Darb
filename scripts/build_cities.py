"""Build the offline city list for manual prayer location.

    py -3 scripts/build_cities.py

Source: GeoNames (https://www.geonames.org), CC BY 4.0 - credited on the
Sources screen. Inputs in scripts/_geonames/ (gitignored, fetched from
https://download.geonames.org/export/dump/):
  cities1000.txt       every place with population > 1000 or an admin seat (ca 130,000)
  countryInfo.txt      ISO code -> English name + the country's geonameid
  alternateNamesV2.zip names WITH language codes (never guessed from script)

Output: scripts/_geonames/out/cities.tsv.gz (-> assets/data + R2 geo/cities.tsv.gz), UTF-8, one row per city:
  lat  lon  cc  population  name  ar  ur  ru  fr  es  pt  en  search
(search: '|'-joined Arabic-script alternates, for matching only)
and a header block of countries, rows starting with '#':
  #cc  en  ar  ur  ru  fr  es  pt
A language column is empty when GeoNames has no name in that language;
the app then shows `name` (the GeoNames main name) - it never invents one.
"""
import gzip
import io
import os
import zipfile

HERE = os.path.join(os.path.dirname(os.path.abspath(__file__)), '_geonames')
# BUNDLED since 2026-09-25 («دول خمسة ميجا بس», owner - earlier the same
# day it was hosted-only). After a rebuild copy OUT to
# rafeeq_app/assets/data/cities.tsv.gz and set CityCatalog.bundledBytes to
# its size (a test checks it). The R2 geo/cities.tsv.gz copy stays.
OUT = os.path.join(HERE, 'out', 'cities.tsv.gz')
LANGS = ['ar', 'ur', 'ru', 'fr', 'es', 'pt', 'en']


def clean(s):
    return s.replace('\t', ' ').replace('\n', ' ').strip()


cities = {}
with open(os.path.join(HERE, 'cities1000.txt'), encoding='utf-8') as f:
    for line in f:
        c = line.rstrip('\n').split('\t')
        # Untagged alternate names in Arabic script: used ONLY to match a
        # search typed in Arabic letters, never shown (their language is
        # not recorded - Arabic, Persian and Urdu share the script).
        arabic_script = sorted({
            clean(a) for a in c[3].split(',')
            if any('؀' <= ch <= 'ۿ' for ch in a)})
        cities[c[0]] = {
            'name': clean(c[1]), 'lat': float(c[4]), 'lon': float(c[5]),
            'cc': c[8], 'pop': int(c[14] or 0),
            'search': '|'.join(arabic_script),
        }

countries = {}
country_by_gid = {}
with open(os.path.join(HERE, 'countryInfo.txt'), encoding='utf-8') as f:
    for line in f:
        if line.startswith('#'):
            continue
        c = line.rstrip('\n').split('\t')
        countries[c[0]] = {'en': clean(c[4])}
        country_by_gid[c[16]] = c[0]

# (geonameid, lang) -> (rank, name); a preferred name beats a plain one,
# a plain one beats a short one. Colloquial and historic names are skipped.
best = {}
with zipfile.ZipFile(os.path.join(HERE, 'alternateNamesV2.zip')) as z:
    with z.open('alternateNamesV2.txt') as raw:
        for line in io.TextIOWrapper(raw, encoding='utf-8'):
            c = line.rstrip('\n').split('\t')
            gid, lang = c[1], c[2]
            if lang not in LANGS:
                continue
            if gid not in cities and gid not in country_by_gid:
                continue
            preferred, short, colloq, hist = (c[4] == '1', c[5] == '1',
                                              c[6] == '1', c[7] == '1')
            if colloq or hist:
                continue
            rank = 0 if preferred else (2 if short else 1)
            key = (gid, lang)
            if key not in best or rank < best[key][0]:
                best[key] = (rank, clean(c[3]))

for (gid, lang), (_, name) in best.items():
    if gid in cities:
        cities[gid][lang] = name
    elif gid in country_by_gid:
        cc = country_by_gid[gid]
        if lang != 'en':
            countries[cc][lang] = name

rows = []
for cc, names in sorted(countries.items()):
    rows.append('#' + '\t'.join([cc] + [names.get(l, '') for l in
                                        ['en'] + LANGS[:-1]]))
for c in sorted(cities.values(), key=lambda c: -c['pop']):
    rows.append('\t'.join([
        f"{c['lat']:.4f}", f"{c['lon']:.4f}", c['cc'], str(c['pop']),
        c['name'],
    ] + [c.get(l, '') for l in LANGS] + [c['search']]))

os.makedirs(os.path.dirname(OUT), exist_ok=True)
with gzip.open(OUT, 'wt', encoding='utf-8', compresslevel=9) as f:
    f.write('\n'.join(rows) + '\n')

have = {l: sum(1 for c in cities.values() if c.get(l)) for l in LANGS}
print(f'{len(cities)} cities, {len(countries)} countries, '
      f'{os.path.getsize(OUT)} bytes -> {OUT}')
print('cities with a name in:', have)
