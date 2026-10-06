"""Generates our word-by-word i'rab for any surah from two named sources, and
lists every word where they disagree (owner, 2026-10-06: «اعمل اسكريبت جامد
لحل مشكلة الاعراب»).

  * MASAQ - Morphologically-Analyzed and Syntactically-Annotated Quran
    (University of Jordan, M. Sawalha et al., 2024, CC BY 4.0,
    data.mendeley.com/datasets/9yvrzxktmr/1): per segment of every word, its
    role, built/declined, case and case sign. The WORD sentence comes from
    here, in our own school wording.
  * al-Da'as (quran_sciences.db irab_daas): the role it gives each quoted
    word, what a jar-majrur attaches to, whether a subject is hidden, the
    kind of a و/ف, and the place of a sentence. Used to complete the
    sentence and to CHECK the MASAQ role.

A word is `agree` when al-Da'as names the same role, `fuller` when al-Da'as
says nothing about it, and `differ` (with both readings) when they part -
those words are read by hand against the other books (CLAUDE.md 1.2) before
anything is shown. MASAQ's own annotator doubts (its Notes column) are
flagged too.

    py -3 scripts/own_irab/gen_masaq.py <surah> [--compare]
writes scripts/own_irab/gen/NNN.json; --compare prints it beside our
hand-checked NNN.json when one exists."""
import io, json, os, re, sqlite3, sys

H = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.join(H, '..', '..', 'rafeeq_app', 'assets', 'data')
MASAQ = os.environ.get('MASAQ_DB', r'E:\DevEnv\masaq\MASAQ.db')
OUTD = os.path.join(H, 'gen')

AR = re.compile('[\u0621-\u064A]')


def letters(t):
    t = re.sub('[\u064b-\u065f\u0670\u06d6-\u06ed\u0640]', '', t)
    t = re.sub('[أإآٱ]', 'ا', t).replace('ى', 'ي').replace('ة', 'ه')
    return re.sub('[^ء-ي]', '', t)


# ---------- the word sentence from MASAQ ----------
SIGN_NOUN = {'مرفوع': 'رفعه', 'منصوب': 'نصبه', 'مجرور': 'جره', 'مجزوم': 'جزمه'}
MARK = {'الضمة': 'الضمة الظاهرة', 'الفتحة': 'الفتحة الظاهرة', 'الكسرة': 'الكسرة الظاهرة',
        'ضمة مقدرة': 'الضمة المقدرة', 'فتحة مقدرة': 'الفتحة المقدرة', 'الكسرة المقدرة': 'الكسرة المقدرة',
        'الفتحة (ممنوع من الصرف)': 'الفتحة نيابة عن الكسرة لأنه ممنوع من الصرف',
        'الياء': 'الياء', 'الواو': 'الواو', 'الألف': 'الألف', 'ثبوت النون': 'ثبوت النون',
        'حذف النون': 'حذف النون', 'حذف حرف العلة': 'حذف حرف العلة', 'السكون': 'السكون'}
BUILT = {'السكون': 'السكون', 'الفتحة': 'الفتح', 'الضمة': 'الضم', 'الكسرة': 'الكسر',
         'فتحة مقدرة': 'الفتح المقدر', 'ضمة مقدرة': 'الضم المقدر', 'الكسرة المقدرة': 'الكسر المقدر',
         'حذف النون': 'حذف النون', 'حذف حرف العلة': 'حذف حرف العلة'}
VERB = {'فعل ماضٍ', 'فعل ماضٍ ناسخ', 'فعل ماضٍ مبني للمجهول', 'فعل مضارع', 'فعل مضارع ناسخ',
        'فعل مضارع مبني للمجهول', 'فعل أمر', 'فعل أمر ناسخ'}
ROLE_WORD = {'فعل ماضٍ': 'فعل ماض', 'فعل ماضٍ ناسخ': 'فعل ماض ناقص', 'فعل ماضٍ مبني للمجهول': 'فعل ماض مبني للمجهول',
             'فعل مضارع ناسخ': 'فعل مضارع ناقص', 'فعل أمر ناسخ': 'فعل أمر ناقص',
             'اسم حرف ناسخ': 'اسم الحرف الناسخ', 'خبر حرف ناسخ': 'خبر الحرف الناسخ',
             'اسم فعل ناسخ': 'اسم الفعل الناسخ', 'خبر فعل ناسخ': 'خبر الفعل الناسخ',
             'حرف ناسخ (إنّ وأخواتها)': 'حرف توكيد ونصب', 'حرف ناسخ (إنّ وأخوتها)': 'حرف توكيد ونصب',
             'حرف جرّ': 'حرف جر', 'اسم معطوف': 'معطوف', 'حرف اسثناء': 'حرف استثناء'}
SKIP_TAGS = {'DET', 'IMPERF_PREF', 'CASE_INDEF_ACC', 'CASE_INDEF_NOM', 'CASE_INDEF_GEN', 'NSUFF_FEM_SG',
             'NSUFF_MASC_PL', 'NSUFF_FEM_PL', 'NSUFF_MASC_DU', 'NSUFF_FEM_DU', 'CASE_DEF_ACC',
             'CASE_DEF_NOM', 'CASE_DEF_GEN', 'PVSUFF_SUBJ'}


LETTER = {'و': 'الواو', 'ف': 'الفاء', 'ب': 'الباء', 'ل': 'اللام', 'ك': 'الكاف', 'س': 'السين',
          'أ': 'الهمزة', 'ت': 'التاء', 'ه': 'الهاء', 'ها': '«ها»', 'ن': 'النون', 'ي': 'الياء', 'نا': '«نا»',
          'كم': '«كم»', 'هم': '«هم»', 'هما': '«هما»', 'كما': '«كما»', 'هن': '«هن»', 'كن': '«كن»', 'ني': '«ني»'}
# What a particle MASAQ only calls «حرف غير عامل» is, by its tag and form.
PARTICLE = {('CONJ', 'و'): 'حرف عطف', ('CONJ', 'ف'): 'حرف عطف', ('CONJ', 'بل'): 'حرف إضراب',
            ('NEG_PART', None): 'حرف نفي', ('EXCEPT_PART', None): 'حرف استثناء',
            ('FUTURE_PART', None): 'حرف استقبال', ('FUT_PART', 'س'): 'حرف استقبال',
            ('FUT_PART', 'سوف'): 'حرف تسويف واستقبال', ('FUTUR_PART', None): 'حرف تسويف واستقبال',
            ('CERT_PART', None): 'حرف تحقيق', ('INTERROG', None): 'حرف استفهام',
            ('INTERROG_PART', None): 'حرف استفهام', ('YES_NO_RESP_PART', 'كلا'): 'حرف ردع وزجر',
            ('YES_NO_RESP_PART', 'بلى'): 'حرف جواب', ('OTHER', 'ها'): 'حرف تنبيه',
            ('SUFF_FEM_TA', None): 'تاء التأنيث الساكنة', ('PVSUFF_SUBJ:3FS', None): 'تاء التأنيث الساكنة',
            ('EMPHATIC_NUN', None): 'نون التوكيد', ('PROTECT_NUN', None): 'نون الوقاية',
            ('PART', 'لكن'): 'حرف استدراك'}
SPECIFIC = {'لم': 'حرف نفي وجزم وقلب', 'لن': 'حرف نفي ونصب واستقبال', 'إن': None, 'قد': 'حرف تحقيق'}


def name(form):
    return LETTER.get(form, f'«{form}»')


def seg_text(seg):
    """One MASAQ segment as a clause of our sentence, or None."""
    form, tag, kind, built, role, case, mark = seg
    if tag == 'NOON_V5':
        return None
    if form == 'أما' and role == 'حرف شرط':
        return 'حرف شرط وتفصيل مبني على السكون'
    if tag == 'OTHER' and form == 'ل':
        return 'حرف'  # al-Da'as names it (المزحلقة / واقعة في جواب القسم / …)
    if role in (None, 'حرف غير عامل') or role == 'حرف جزم' and form == 'لم':
        p = SPECIFIC.get(form) or PARTICLE.get((tag, form)) or PARTICLE.get((tag, None))
        return p
    if not role:
        return None
    r = ROLE_WORD.get(role, role)
    m = mark or ''
    if role in VERB:
        if 'مضارع' in role:
            if case in SIGN_NOUN:
                return f'{r} {case} وعلامة {SIGN_NOUN[case]} {MARK.get(m, m)}'
            return f'{r} مبني على {BUILT.get(m, m)}'
        return f'{r} مبني على {BUILT.get(m, m)}'
    if built and 'ضمير' in built:
        pr = 'ضمير منفصل' if 'منفصل' in built else 'ضمير متصل'
        place = {'مرفوع': 'رفع', 'منصوب': 'نصب', 'مجرور': 'جر'}.get(case)
        b = BUILT.get(m, 'السكون')
        if r == 'اسم مجرور':
            r = 'بالحرف'
        return f'{pr} مبني على {b}' + (f' في محل {place} {r}' if place else '')
    if built in ('مبني', 'اسم استفهام', 'اسم موصول', 'اسم إشارة', 'اسم شرط') or case == 'مبني':
        kindw = '' if built == 'مبني' else built + ' '
        place = {'مرفوع': 'رفع', 'منصوب': 'نصب', 'مجرور': 'جر'}.get(case)
        if role.startswith('حرف') or role in ('أداة تحقيق', 'كافة ومكفوفة', 'لا النافية', 'لا الناهية',
                                              'ما العاملة عمل ليس', 'لا النافية للجنس', 'حروف مقطعة'):
            return f'{r} مبني على {BUILT.get(m, m)}'
        return f'{kindw}مبني على {BUILT.get(m, m)}' + (f' في محل {place} {r}' if place else f'، {r}')
    if case in SIGN_NOUN:
        if r == 'اسم مجرور':
            return f'اسم مجرور وعلامة جره {MARK.get(m, m)}'
        return f'{r} {case} وعلامة {SIGN_NOUN[case]} {MARK.get(m, m)}'
    return r


# ---------- al-Da'as: what it says about each quoted word ----------
QUOTE = re.compile(r'«([^»]+)»([^«]*)')


def daas_notes(text, toks):
    """[(token indexes covered, explanation)], quotes aligned in order."""
    out, i = [], 0
    L = [letters(t) for t in toks]
    for q, expl in QUOTE.findall(text):
        ql = letters(q)
        if not ql:
            continue
        for start in range(i, len(L)):
            acc, j = '', start
            while j < len(L) and len(acc) < len(ql):
                acc += L[j]; j += 1
            if acc == ql:
                out.append((list(range(start, j)), expl.strip()))
                i = j
                break
    return out


ROLE_KEYS = ['نائب فاعل', 'فاعل', 'مفعول به', 'مفعول مطلق', 'مفعول لأجله', 'مفعول معه', 'مضاف إليه',
             'مبتدأ', 'خبر', 'صفة', 'نعت', 'حال', 'بدل', 'تمييز', 'ظرف', 'منادى', 'توكيد', 'مستثنى', 'معطوف']


def role_key(t):
    t = re.sub(r'(?:و?(?:نائب )?(?:ال)?فاعله? مستتر|وفاعله|ومفعوله(?: الأول| الثاني)?|والجملة[^«]*|مضاف إلى[^«]*)', ' ', t or '')
    hits = [(t.find(k), k) for k in ROLE_KEYS if k in t]
    return min(hits)[1] if hits else None


def same(daas_role, masaq_role):
    if not daas_role or not masaq_role:
        return None
    eq = {'صفة': 'نعت', 'ظرف': 'ظرف'}
    d = eq.get(daas_role, daas_role)
    if masaq_role in VERB:
        return None
    return d in masaq_role or (d == 'نعت' and 'نعت' in masaq_role) or \
        (d == 'خبر' and 'خبر' in masaq_role) or (d == 'معطوف' and 'معطوف' in masaq_role)


def gen(surah):
    q = sqlite3.connect(os.path.join(DATA, 'quran_local.db'))
    d = sqlite3.connect(os.path.join(DATA, 'quran_sciences.db'))
    m = sqlite3.connect(MASAQ)
    words = []
    for a, txt in q.execute('select ayah_number, text_uthmani from ayahs where surah_id=? order by ayah_number', (surah,)):
        toks = [t for t in txt.split() if AR.search(t)]
        sec = [t for (t,) in d.execute('select text from irab_daas where surah=? and ayah_from<=? and ayah_to>=?', (surah, a, a))]
        notes = daas_notes(' '.join(sec), toks) if sec else []
        by_tok = {}
        for idxs, expl in notes:
            for k in idxs:
                by_tok.setdefault(k, []).append(expl)
        for n, w in enumerate(toks, 1):
            segs = list(m.execute('select Segmented_Word, Morph_tag, Morph_type, Invariable_Declinable, Syntactic_Role, '
                                  'Case_Mood, Case_Mood_Marker, Phrase, Phrasal_Function, Notes from MASAQcsv '
                                  'where Sura_No=? and Verse_No=? and Column5=? order by ID', (surah, a, n)))
            expl = ' '.join(by_tok.get(n - 1, []))
            texts = [(sg, seg_text(sg[:7])) for sg in segs]
            texts = [(sg, t) for sg, t in texts if t]
            pref = ''.join(sg[0] for sg in segs if sg[1] == 'IMPERF_PREF')
            bare = re.sub('[\u0610-\u061a\u064b-\u065f\u0670\u06d6-\u06ed]', '', w)
            where = ' على الألف للتعذر' if bare[-1:] in ('ى', 'ا') else (' على الياء للثقل' if bare[-1:] == 'ي' else '')
            parts = []
            for i, (sg, t) in enumerate(texts):
                if where:
                    t = re.sub(r'(المقدرة|المقدر)(?! على)', r'\1' + where, t)
                form, tag, kind = sg[0], sg[1], sg[2]
                if kind == 'Prefix' and form in ('و', 'ف', 'ل'):
                    lab = {'و': 'الواو', 'ف': 'الفاء', 'ل': 'اللام'}[form]
                    mo = re.search(lab + r' ((?:حرف|حالية|اعتراضية|استئنافية|رابطة|الفصيحة|زائدة|واقعة|المزحلقة|موطئة|لام)[^«،.]*?)(?= و[ا-ي]|$|«|\.|،)', expl)
                    if mo:
                        t = mo.group(1).strip()
                if len(texts) == 1:
                    parts.append(t)
                    continue
                det = 'ال' if any(x[1] == 'DET' for x in segs) else ''
                label = (f'«{det}{pref}{form}»' if kind == 'Stem' else name(form))
                parts.append(('' if i == 0 else 'و') + f'{label} {t}')
            stem_role = next((s[4] for s in segs if s[2] == 'Stem' and s[4]), None)
            if stem_role == 'اسم معطوف':
                mo = re.search(r'معطوف على ([^«.،]+?)(?= والجملة| وجملة|$|\\.|،|«)', expl)
                tgt = ('«' + mo.group(1).strip() + '»') if mo and mo.group(1).strip() not in ('ما قبله', 'ما قبلها') else 'ما قبله'
                parts = [re.sub(r'معطوف(?! على)( معطوف)?', f'معطوف على {tgt}', p, count=1) for p in parts]
            for s in segs:
                if s[7] == 'شبه جملة' and s[8]:
                    parts.append(f'وشبه الجملة متعلق بمحذوف {s[8]}')
                elif s[7] and s[7].startswith('جملة') and s[8]:
                    parts.append(f'و{s[7]} في محل {s[8]}')
            if 'متعلقان' in expl and not any('متعلق' in p for p in parts):
                mt = re.search(r'متعلقان ([^«.]*)', expl)
                if mt:
                    parts.append('والجار والمجرور متعلقان ' + mt.group(1).strip(' ،'))
            hidden = False
            if stem_role in VERB and 'ناسخ' not in stem_role and not any(x[1] in ('SUBJ_PRON',) or (x[1] or '').startswith('PVSUFF_SUBJ:3MP') for x in segs):
                hidden = True
                for k in range(n, len(toks)):
                    roles = [r[0] for r in m.execute('select Syntactic_Role from MASAQcsv where Sura_No=? and Verse_No=? and Column5=? and Morph_type=?', (surah, a, k + 1, 'Stem'))]
                    if any(r in VERB for r in roles):
                        break
                    if any(r in ('فاعل', 'نائب فاعل') for r in roles):
                        hidden = False
                        break
            if hidden or re.search(r'فاعله مستتر|والفاعل مستتر|نائب الفاعل مستتر', expl):
                who = 'نائب الفاعل' if 'نائب' in expl or (stem_role and 'للمجهول' in stem_role) else 'الفاعل'
                if stem_role and 'أمر' in stem_role:
                    parts.append(f'و{who} ضمير مستتر وجوبًا تقديره أنت')
                else:
                    est = {'ي': 'هو', 'ن': 'نحن', 'أ': 'أنا'}.get(pref)
                    if not pref and stem_role and 'ماض' in stem_role:
                        est = 'هي' if any(x[1] in ('SUFF_FEM_TA', 'PVSUFF_SUBJ:3FS') for x in segs) else 'هو'
                    parts.append(f'و{who} ضمير مستتر' + (f' تقديره {est}' if est else ''))
            for idxs, ex in notes:
                if idxs and idxs[-1] == n - 1:
                    for js in re.findall(r'(والجملة [^«.]*|وجملة [^«.]*|والمصدر المؤول [^«.]*)', ex):
                        js = js.strip(' ،')
                        js = re.sub(r'^(والجملة) صلة$', r'\1 صلة الموصول لا محل لها', js)
                        js = re.sub(r'(مستأنفة|ابتدائية|تعليلية|مفسرة|اعتراضية)$', r'\1 لا محل لها', js)
                        js = js.replace('لا محل لها', 'لا محل لها من الإعراب').replace('من الإعراب من الإعراب', 'من الإعراب')
                        if js not in parts:
                            parts.append(js)
            dr, mr = role_key(expl), stem_role
            ok = same(dr, mr)
            if mr in VERB and expl:
                vk = 'أمر' if 'أمر' in mr else ('مضارع' if 'مضارع' in mr else 'ماض')
                ok = vk in expl or 'معطوف' in expl or 'معطوفة' in expl
            check = 'fuller' if ok is None else ('agree' if ok else 'differ')
            note = next((s[9] for s in segs if s[9]), None)
            words.append({'a': a, 'w': w, 'irab': '، '.join(parts) + '.', 'check': check,
                          'masaq_role': mr, 'daas': expl or None, 'masaq_note': note})
    return words


if __name__ == '__main__':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
    s = int(sys.argv[1])
    ws = gen(s)
    os.makedirs(OUTD, exist_ok=True)
    json.dump({'surah': s, 'source': 'MASAQ (CC BY 4.0) + al-Da\'as', 'words': ws},
              open(os.path.join(OUTD, f'{s:03d}.json'), 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
    gold = os.path.join(H, f'{s:03d}.json')
    g = json.load(open(gold, encoding='utf-8'))['words'] if os.path.exists(gold) and '--compare' in sys.argv else None
    from collections import Counter
    print(s, len(ws), 'words', dict(Counter(w['check'] for w in ws)))
    for i, w in enumerate(ws):
        if g or w['check'] == 'differ':
            print(f"{w['a']}:{w['w']} [{w['check']}] GEN: {w['irab']}")
            if w['check'] == 'differ':
                print(f"     MASAQ={w['masaq_role']} | DAAS: {w['daas']}")
            if g:
                print(f"     OURS: {g[i]['irab']}")
