"""Writes NNN.json for a surah from an ordered list of i'rab entries, one per
mushaf token (the same tokens check.py compares against). Every entry is
read against al-Da'as before it is written (show.py); `check` defaults to
«agree», an entry may be a (text, check) pair.
    from write_surah import write; write(97, [...], status)"""
import json, os, re, sqlite3
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

# Group B of the second review (SAMIN_REVIEW.md, 2026-11-12): al-Da'as's reading
# of these words is contradicted by a named book in the packet and supported
# by none. (surah, ayah, token): [(old, new), ...] substring replacements; the
# old text is kept under the word as al-Da'as's alt by apply_groupb.py.
def bare(w):
    return ''.join(c for c in w if 'ء' <= c <= 'ي' or c == 'ٱ').replace('آ', 'ا')


GROUPB = {
    (2, 57, 'ولكن'): [('الواو حالية', 'الواو عاطفة')],
    (2, 125, 'ٱلسجود'): [('معطوف على «الطائفين» بحذف حرف العطف', 'نعت لـ«الركع»')],
    (2, 170, 'ءاباءنا'): [('مفعول به ثان', 'مفعول به أول')],
    (4, 92, 'يصدقوا'): [('في محل نصب حال', 'في محل نصب على الاستثناء المنقطع')],
    (7, 58, 'بإذن'): [('صفة لمفعول به محذوف', 'حال من «نباته»')],
    (7, 178, 'من'): [('في محل رفع مبتدأ', 'في محل نصب مفعول به مقدم')],
    (7, 186, 'من'): [('في محل رفع مبتدأ', 'في محل نصب مفعول به مقدم')],
    (3, 54, 'وٱلله'): [('الواو حالية', 'الواو استئنافية')],
    (3, 100, 'بعد'): [('ظرف مكان', 'ظرف زمان')],
    (3, 119, 'ٱلغيظ'): [('متعلقان بمحذوف تمييز', 'متعلقان بـ«عضوا»')],
    (3, 140, 'فقد'): [('الفاء حرف عطف', 'الفاء رابطة لجواب الشرط')],
    (3, 173, 'فٱخشوهم'): [('الفاء الفصيحة', 'الفاء عاطفة'),
                           ('والجملة جواب شرط غير جازم لا محل لها من الإعراب', 'والجملة معطوفة على جملة «قد جمعوا» في محل رفع')],
    (3, 197, 'وبئس'): [('الواو حالية', 'الواو استئنافية')],
    (4, 4, 'هنيـا'): [('حال من الواو', 'حال من الهاء')],
    (4, 4, 'مريـا'): [('حال من الواو', 'حال من الهاء')],
}

# Group B, second part (b016-b031 judged 2026-11-12): same rule as above, keys
# written with the mushaf token and bared on load.
_GB2 = {
    (9, 80, 'سَبۡعِينَ'): [('ظرف زمان', 'نائب مفعول مطلق')],
    (9, 96, 'فَإِن'): [('الفاء الفصيحة، حرف شرط جازم', 'الفاء استئنافية، «إن» حرف شرط جازم')],
    (9, 126, 'مَّرَّةً'): [('ظرف زمان', 'نائب مفعول مطلق')],
    (10, 32, 'فَمَاذَا'): [('الفاء حرف استئناف، «ما» حرف نفي مبني على السكون، و«ذا» زائدة',
                          'الفاء استئنافية، «ماذا» اسم استفهام مبني على السكون في محل رفع مبتدأ بمعنى النفي')],
    (11, 19, 'هُمۡ'): [('ضمير فصل لا محل له من الإعراب', 'ضمير منفصل مبني على السكون في محل رفع توكيد لفظي للضمير «هم» الأول')],
    (11, 45, 'فَقَالَ'): [('الفاء زائدة', 'الفاء عاطفة'),
                        ('والجملة مفسرة لا محل لها من الإعراب', 'والجملة معطوفة على جملة «نادى» لا محل لها من الإعراب')],
    (12, 4, 'سَٰجِدِينَ'): [('مفعول به ثان منصوب وعلامة نصبه الياء', 'حال منصوبة وعلامة نصبها الياء')],
    (12, 9, 'أَرۡضٗا'): [('ظرف مكان منصوب وعلامة نصبه الفتحة الظاهرة، والظرف متعلق بالفعل «اطرحوا»',
                         'منصوب بنزع الخافض (أي: في أرض) وعلامة نصبه الفتحة الظاهرة')],
    (17, 72, 'أَعۡمَىٰ'): [('اسم «كان» مؤخر مرفوع وعلامة رفعه الضمة المقدرة على الألف للتعذر',
                          'خبر «كان» منصوب وعلامة نصبه الفتحة المقدرة على الألف للتعذر')],
    (17, 100, 'أَنتُمۡ'): [('توكيد للفاعل في الفعل المحذوف الذي يفسره ما بعده', 'فاعل لفعل محذوف يفسره ما بعده')],
    (18, 24, 'عَسَىٰٓ'): [('ناقص', 'تام'), ('واسمه ضمير مستتر،', 'والمصدر المؤول من «أن يهدين» في محل رفع فاعل،')],
    (19, 48, 'عَسَىٰٓ'): [('ناقص', 'تام'), ('واسمه ضمير مستتر تقديره: أنا', 'والمصدر المؤول من «ألا أكون» في محل رفع فاعل')],
    (20, 110, 'عِلۡمٗا'): [('مفعول به منصوب', 'نائب مفعول مطلق منصوب')],
    (23, 33, 'ٱلَّذِينَ'): [('في محل جر صفة لـ«قوم»', 'في محل رفع نعت لـ«الملأ»')],
    (24, 39, 'حَتَّىٰٓ'): [('حرف غاية وجر', 'حرف ابتداء')],
    (18, 86, 'حَتَّىٰٓ'): [('حرف غاية وجر', 'حرف ابتداء')],
    (18, 90, 'حَتَّىٰٓ'): [('حرف غاية وجر', 'حرف ابتداء')],
    (18, 93, 'حَتَّىٰٓ'): [('حرف غاية وجر', 'حرف ابتداء')],
    (18, 96, 'حَتَّىٰٓ'): [('حرف غاية وجر', 'حرف ابتداء')],
    (21, 96, 'حَتَّىٰٓ'): [('حرف غاية وجر', 'حرف ابتداء')],
    (25, 49, 'وَنُسۡقِيَهُۥ'): [('مفعول به أول', 'مفعول به ثان')],
    (25, 49, 'أَنۡعَٰمٗا'): [('مفعول به ثان', 'مفعول به أول')],
}
GROUPB.update({(s_, a_, bare(w_)): r_ for (s_, a_, w_), r_ in _GB2.items()})
# Group B part 3 (b032-b047, judged with the two-book rule, every item read by
# Opus 2026-11-12): whole-text replacements, kept in groupb3_fixes.json.
for _f in json.load(open(os.path.join(H, 'groupb3_fixes.json'), encoding='utf-8')):
    GROUPB.setdefault((_f['s'], _f['a'], bare(_f['w'])), []).append((_f['old'].rstrip('.'), _f['new'].rstrip('.')))
# Group B part 5 (NEIGHBOURS_FINDINGS.md, read against al-Jadwal, Darwish and
# al-Mujtaba by Opus 2026-11-12): neighbours whose tail contradicted a group B
# change. Many of these words were 'agree'; apply_groupb.py touches them too.
GROUPB5 = {}
for _f in json.load(open(os.path.join(H, 'groupb5_fixes.json'), encoding='utf-8')):
    _k = (_f['s'], _f['a'], bare(_f['w']))
    GROUPB5.setdefault(_k, []).append((_f['old'], _f['new']))
    GROUPB.setdefault(_k, []).append((_f['old'], _f['new']))
# Group B part 6 (b048-b063: Sonnet judged j22-j27, Opus read all 78 CHANGE
# proposals 2026-11-12 against the packets plus al-Jadwal and Darwish from
# books_cache; 63 kept by the two-book rule, 15 rejected). Same handling as
# part 5 because some entries are neighbour tails on 'agree' words.
for _f in json.load(open(os.path.join(H, 'groupb6_fixes.json'), encoding='utf-8')):
    _k = (_f['s'], _f['a'], bare(_f['w']))
    GROUPB5.setdefault(_k, []).append((_f['old'], _f['new']))
    GROUPB.setdefault(_k, []).append((_f['old'], _f['new']))
# Group B part 7 (the last open items, Opus 2026-11-12): 36:51 «في الصور»,
# the «حتى إذا» family and the «إنك أنت» family, each by the two-book rule on
# the same ayah's al-Jadwal and al-Mujtaba text (GROUPB7_REJECTED.md).
for _f in json.load(open(os.path.join(H, 'groupb7_fixes.json'), encoding='utf-8')):
    _k = (_f['s'], _f['a'], bare(_f['w']))
    GROUPB5.setdefault(_k, []).append((_f['old'], _f['new']))
    GROUPB.setdefault(_k, []).append((_f['old'], _f['new']))

# «ولقد» parsed as an oath waw (al-Da'as's shorthand) where no sworn-by noun
# follows: al-Jadwal names the waw and an implied oath for the lam (SAMIN
# review 2026-11-12; the same form 53:13-54:51 already use). (surah, ayah): waw kind
LAQAD = {(39, 65): 'استئناف', (44, 17): 'استئناف', (45, 16): 'استئناف', (46, 26): 'عطف',
         (46, 27): 'عطف', (67, 18): 'استئناف', (81, 23): 'عطف'}
LAQAD_OLD = re.compile(r'^الواو حرف قسم وجر، (?:والمقسم به محذوف، )?واللام واقعة في جواب القسم')


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
    if (surah, a) in LAQAD and 'لَقَد' in w:
        text = LAQAD_OLD.sub(f'الواو حرف {LAQAD[(surah, a)]}، واللام واقعة في جواب قسم مقدر', text)
    for old, new in GROUPB.get((surah, a, bare(w)), []):
        text = text.replace(old, new)
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
