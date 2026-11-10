"""Fetches al-Jadwal and Darwish for every ayah of a surah into books_cache/
once, so that writing a chunk never waits on the network.
    py -3 scripts/own_irab/prefetch.py 4"""
import os, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from books import get, CACHE
from write_surah import tokens

for s in map(int, sys.argv[1:]):
    n = max(a for a, _ in tokens(s))
    bad = []
    for a in range(1, n + 1):
        for src in ('aljadwal', 'iraab-aldarweesh'):
            for attempt in range(4):
                try:
                    get(src, s, a)
                    break
                except Exception as e:  # a half-written cache file must not stay
                    f = os.path.join(CACHE, f'{src}_{s}_{a}.json')
                    if os.path.exists(f):
                        os.remove(f)
                    time.sleep(2 + 3 * attempt)
            else:
                bad.append((src, a))
    print(s, 'ayahs', n, 'failed', bad or 'none', flush=True)
