"""Writes NNN.json for a surah from an ordered list of i'rab entries, one per
mushaf token (the same tokens check.py compares against). Every entry is
read against al-Da'as before it is written (show.py); `check` defaults to
«agree», an entry may be a (text, check) pair.
    from write_surah import write; write(97, [...], status)"""
import json, os, sqlite3
H = os.path.dirname(os.path.abspath(__file__))


def tokens(surah):
    db = sqlite3.connect(os.path.join(H, '..', '..', 'rafeeq_app', 'assets', 'data', 'quran_local.db'))
    return [(a, t) for a, txt in db.execute(
        'select ayah_number, text_uthmani from ayahs where surah_id=? order by ayah_number', (surah,))
        for t in txt.split() if any('ء' <= c <= 'ي' for c in t)]


def write(surah, entries, status):
    toks = tokens(surah)
    assert len(toks) == len(entries), (surah, len(toks), len(entries))
    words = []
    for (a, w), e in zip(toks, entries):
        if isinstance(e, dict):  # {'text', 'check', 'alts'}: a second view, named
            words.append({'a': a, 'w': w, 'irab': e['text'], 'check': e['check'], 'alts': e['alts']})
            continue
        text, check = (e, 'agree') if isinstance(e, str) else e
        words.append({'a': a, 'w': w, 'irab': text, 'check': check})
    json.dump({'surah': surah, 'status': status, 'words': words},
              open(os.path.join(H, f'{surah:03d}.json'), 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
    print(f'{surah:03d}', len(words), 'words')
