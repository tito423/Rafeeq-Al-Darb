"""Splits a surah into chunks of whole ayahs of about N words each, the
ranges handed to chunk writers (CHUNK_PROMPT.md).
    py -3 scripts/own_irab/chunks.py 4 [450]"""
import collections, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from write_surah import tokens


def chunks(s, size=450):
    need = collections.Counter(a for a, _ in tokens(s))
    out, a0, n = [], 1, 0
    for a in sorted(need):
        if n and n + need[a] > size:
            out.append((a0, a - 1, n)); a0, n = a, 0
        n += need[a]
    out.append((a0, max(need), n))
    return out


if __name__ == '__main__':
    s = int(sys.argv[1])
    for a0, a1, n in chunks(s, int(sys.argv[2]) if len(sys.argv) > 2 else 450):
        print(s, a0, a1, n)
