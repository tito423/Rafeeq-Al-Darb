"""Prints al-Jadwal and Darwish for a range of ayahs, each passage once (both
books group ayahs, so the same text comes back for neighbours), with the
prose sections (sarf, balagha, fawa'id) cut. The reading sheet for books.py
over a whole chunk.   py -3 scripts/own_irab/books_range.py 42 21 30"""
import json, re, os, sys, io
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from books import get
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
s, a0, a1 = map(int, sys.argv[1:4])
seen = set()
for a in range(a0, a1 + 1):
    for src, name in (('aljadwal', 'J'), ('iraab-aldarweesh', 'D')):
        t = get(src, s, a)
        if src == 'aljadwal':
            t = re.split(r'\* (الصرف|البلاغة|الفوائد|فوائد)', t)[0]
        else:
            m = re.search(r'(الإعراب|الأعراب):', t); t = t[m.start():] if m else t
            t = re.split(r'\* (البلاغة|الفوائد)', t)[0]
        t = re.sub(r'\s+', ' ', t)
        if t in seen: continue
        seen.add(t); print(f'== {name} {s}:{a}\n{t}')
