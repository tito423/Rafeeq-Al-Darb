"""Writes NNN.json for a surah from an ordered list of i'rab entries, one per
mushaf token (the same tokens check.py compares against). Every entry is
read against al-Da'as before it is written (show.py); `check` defaults to
«agree», an entry may be a (text, check) pair.
    from write_surah import write; write(97, [...], status)"""
import json, os, sqlite3
from irab_dsl import x  # short codes -> house wording (irab_dsl.py)
H = os.path.dirname(os.path.abspath(__file__))


def tokens(surah):
    db = sqlite3.connect(os.path.join(H, '..', '..', 'rafeeq_app', 'assets', 'data', 'quran_local.db'))
    return [(a, t) for a, txt in db.execute(
        'select ayah_number, text_uthmani from ayahs where surah_id=? order by ayah_number', (surah,))
        for t in txt.split() if any('ء' <= c <= 'ي' for c in t)]


def vowel(w, text):
    # The phrasebook clauses «والهاء ... مبني على الكسر» were applied to words
    # whose ha carries a DAMMA in the mushaf (هُمۡ after a fatha/damma): the
    # vowel named must be the one written on the token (owner, 2026-11-11).
    old = 'والهاء ضمير متصل مبني على الكسر'
    if old in text and ('هُ' in w) and ('هِ' not in w):
        return text.replace(old, 'والهاء ضمير متصل مبني على الضم')
    return text


KANA = ('كان', 'يكون', 'تكون', 'كانت', 'يكن', 'تكن', 'ليس', 'أصبح', 'صار', 'ظل')
# Certain errors found by audit_vowels.py (2026-11-11): the case sign named
# contradicted the vowel written in the mushaf. (surah, ayah, token): (old, new)
FIXES = {
    (24, 26, 'وَٱلۡخَبِيثُونَ'): ('وعلامة رفعه الضمة الظاهرة', 'وعلامة رفعه الواو لأنه جمع مذكر سالم'),
    (24, 26, 'وَٱلطَّيِّبُونَ'): ('وعلامة رفعه الضمة الظاهرة', 'وعلامة رفعه الواو لأنه جمع مذكر سالم'),
    (67, 16, 'ٱلۡأَرۡضَ'): ('فاعل مرفوع وعلامة رفعه الضمة الظاهرة', 'مفعول به منصوب وعلامة نصبه الفتحة الظاهرة'),
}


def certain(surah, a, w, text):
    # Ism kana and its sisters is marfu', always.
    for k in KANA:
        text = text.replace(f'اسم «{k}» منصوب وعلامة نصبه الفتحة الظاهرة', f'اسم «{k}» مرفوع وعلامة رفعه الضمة الظاهرة')
    # A mansub sign must be the fatha.
    text = text.replace('منصوب بـ«أن» وعلامة نصبه الضمة الظاهرة', 'منصوب بـ«أن» وعلامة نصبه الفتحة الظاهرة')
    # A final alif carries no visible kasra.
    if ''.join(c for c in w if 'ء' <= c <= 'ي' or c == 'ٱ').endswith('دنيا'):
        text = text.replace('وعلامة جره الكسرة الظاهرة', 'وعلامة جره الكسرة المقدرة على الألف للتعذر')
    # A sound masculine plural in -ūna is raised by the waw.
    if w.rstrip('ۖۗۘۙۚۛۜ').endswith('ونَ') and 'لأنه جمع مذكر سالم' not in text and not text.startswith('فعل'):
        text = text.replace('مرفوع وعلامة رفعه الضمة الظاهرة', 'مرفوع وعلامة رفعه الواو لأنه جمع مذكر سالم')
    old, new = FIXES.get((surah, a, w), (None, None))
    if old and old in text:
        text = text.replace(old, new)
    return text


def write(surah, entries, status):
    toks = tokens(surah)
    assert len(toks) == len(entries), (surah, len(toks), len(entries))
    words = []
    for (a, w), e in zip(toks, entries):
        if isinstance(e, dict):  # {'text', 'check', 'alts'}: a second view, named
            words.append({'a': a, 'w': w, 'irab': certain(surah, a, w, vowel(w, x(e['text']))), 'check': e['check'], 'alts': e['alts']})
            continue
        text, check = (e, 'agree') if isinstance(e, str) else e
        words.append({'a': a, 'w': w, 'irab': certain(surah, a, w, vowel(w, x(text))), 'check': check})
    json.dump({'surah': surah, 'status': status, 'words': words},
              open(os.path.join(H, f'{surah:03d}.json'), 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
    print(f'{surah:03d}', len(words), 'words')
