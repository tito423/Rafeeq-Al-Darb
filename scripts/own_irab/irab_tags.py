"""Short grammar tags for non-Arabic readers (owner, 2026-11-12: every
content in all seven languages, §1.7c).

The tags are READ from our Arabic i'rab, never inferred: each clause of a
word's i'rab is scanned for the first term of a fixed glossary (the role) and
its case or mood word (مرفوع / في محل نصب / مبني ...). A clause that names no
glossary term gives no tag, so a word may show fewer tags than its i'rab
holds - never one it does not. Clauses about the sentence (والجملة ...), the
attachment of a jar-majrur, or a cross-reference are skipped.

The English names follow the Quranic Arabic Corpus (corpus.quran.com
documentation/tagset.jsp and grammar.jsp, read 2026-11-12); the app holds
the names in all seven locales under `irab_tag.<key>`.

    py -3 irab_tags.py          coverage report + a sample
"""
import re

# (regex, key) - the earliest match in a clause wins; at the same position the
# longer pattern wins. Order here does not matter.
ROLES = [
    (r'فعل ماض', 'v_past'), (r'فعل مضارع', 'v_impf'), (r'فعل أمر', 'v_impv'),
    (r'نائب (?:ال)?فاعل', 'pass_subj'), (r'فاعل', 'subj'), (r'مبتدأ', 'mubtada'),
    (r'اسم «?(?:إن|إنّ|أن|أنّ|لكن|لكنّ|ليت|لعل|لعلّ|كأن|كأنّ)»?', 'ism_inna'),
    (r'خبر «?(?:إن|إنّ|أن|أنّ|لكن|لكنّ|ليت|لعل|لعلّ|كأن|كأنّ)»?', 'khabar_inna'),
    (r'اسم «?(?:كان|يكون|تكون|كانت|كانوا|يكن|تكن|ليس|أصبح|صار|ظل|بات|أمسى|أضحى|مازال|ما زال|ما دام|زال)»?', 'ism_kana'),
    (r'خبر «?(?:كان|يكون|تكون|كانت|كانوا|يكن|تكن|ليس|أصبح|صار|ظل|بات|أمسى|أضحى|مازال|ما زال|ما دام|زال)»?', 'khabar_kana'),
    (r'خبر', 'khabar'),
    (r'مفعول به', 'obj'), (r'نائب عن المفعول المطلق|مفعول مطلق', 'cognate'), (r'مفعول لأجله|مفعول له', 'purpose'),
    (r'مفعول معه', 'comitative'), (r'مفعول فيه|ظرف', 'adverb'),
    (r'حال(?!ي)', 'hal'), (r'(?:الواو|الفاء) حالية|واو الحال|حرف حال', 'p_circ'), (r'تمييز', 'tamyiz'), (r'مضاف إليه', 'mudaf_ilayh'),
    (r'اسم مجرور', 'gen_noun'), (r'بدل', 'badal'), (r'نعت|صفة', 'naat'),
    (r'معطوف', 'matuf'), (r'توكيد', 'tawkid'), (r'مستثنى', 'excepted'),
    (r'منادى', 'munada'), (r'مقسم به', 'oath_noun'), (r'ضمير فصل', 'fasl'),
    (r'حروف مقطعة|حروف مقطّعة', 'initials'),
    # particles
    (r'حرف جر', 'p_prep'), (r'حرف عطف', 'p_conj'),
    (r'حرف (?:نفي و)?جزم|حرف نفي وجزم', 'p_jussive'),
    (r'حرف نهي', 'p_prohib'), (r'حرف نفي', 'p_neg'),
    (r'حرف استئناف|استئنافية', 'p_resump'),
    (r'حرف توكيد ونصب|مشبه بالفعل', 'p_inna'),
    (r'حرف مصدري ونصب|حرف نصب', 'p_acc'), (r'حرف مصدري', 'p_sub'),
    (r'حرف شرط|اسم شرط', 'p_cond'), (r'حرف استفهام|اسم استفهام', 'p_interrog'),
    (r'حرف نداء', 'p_voc'), (r'حرف تحقيق', 'p_cert'), (r'زائدة?', 'p_supp'),
    (r'أداة حصر', 'p_restr'), (r'أداة استثناء', 'p_except'),
    (r'حرف استقبال|حرف تنفيس', 'p_fut'), (r'حرف جواب', 'p_ans'),
    (r'حرف تنبيه', 'p_attn'), (r'حرف قسم', 'p_oath'),
    (r'لام الأمر', 'p_impv_lam'), (r'لام التعليل|لام كي', 'p_prp'), (r'جواب (?:ال)?قسم', 'p_oath_ans'),
]
# a term starts a word: «بخبر محذوف» (an attachment) is not the role «خبر»
ROLES = [(re.compile(r'(?<![ء-ي])[وف]?(?:ال)?(?:' + p + ')'), k) for p, k in ROLES]

NOUN_CASE = {'رفع': 'nom', 'نصب': 'acc', 'جر': 'gen', 'جزم': 'jus'}
VERB_MOOD = {'رفع': 'ind', 'نصب': 'subj', 'جزم': 'jus'}
CASE = re.compile(r'(مرفوع|منصوب|مجرور|مجزوم)|(?:في )?محل (رفع|نصب|جر|جزم)')
WORD = {'مرفوع': 'رفع', 'منصوب': 'نصب', 'مجرور': 'جر', 'مجزوم': 'جزم'}
SKIP = re.compile(r'^(?:والظرف|و?الجملة|و?جملة|والجار|والمصدر|وهو مضاف|كما في|وعند|والتقدير|وتقدير|أي|والتنوين|ومفعوله|ومفعولاه|متعلق|والمقسم به محذوف|أو )')
# «مجرور لفظًا مرفوع محلًا»: the role's case is the one of the place
LAFZ = re.compile(r'(مرفوع|منصوب|مجرور) محلا()')


def _clauses(irab):
    t = re.sub('[ً-ْ]', '', irab)  # «محلًّا» = «محلا»
    return [c.strip() for c in re.split(r'[،؛.]', t) if c.strip()]


def tags(irab):
    out = []
    for c in _clauses(irab):
        if SKIP.match(c):
            continue
        best = None
        for rx, k in ROLES:
            m = rx.search(c)
            if m and (best is None or m.start() < best[0] or (m.start() == best[0] and m.end() > best[1])):
                best = (m.start(), m.end(), k)
        if not best:
            continue
        k = best[2]
        tag = k
        if not k.startswith('p_') and k not in ('initials', 'fasl'):
            m = CASE.search(c[best[0]:]) or CASE.search(c)
            lafz = LAFZ.search(c)
            if k.startswith('v_') and m and not m.group(1):
                m = None  # a verb has no place of its own; «في محل» is its sentence's
            if lafz and not k.startswith('v_'):
                tag = f'{k}:{NOUN_CASE[WORD[lafz.group(1) or lafz.group(2)]]}~'
            elif m:
                case = WORD[m.group(1)] if m.group(1) else m.group(2)
                table = VERB_MOOD if k.startswith('v_') else NOUN_CASE
                if case in table:
                    # «في محل رفع»: the case of the place, not a written sign
                    tag = f'{k}:{table[case]}' + ('' if m.group(1) else '~')
            elif 'مبني' in c:
                tag = f'{k}:mabni'
        if 'مستتر' in c and k in ('subj', 'pass_subj'):
            tag = f'{k}:hidden'
        found = [tag]
        # «اسم شرط ... في محل نصب مفعول به»: the place names a second role
        m2 = re.search(r'في محل (رفع|نصب|جر) (.{0,20})', c)
        if m2 and k.startswith('p_'):
            for rx, k2 in ROLES:
                if not k2.startswith('p_') and rx.match(m2.group(2)):
                    found.append(f'{k2}:{NOUN_CASE[m2.group(1)]}~')
                    break
        for tag in found:
            if not out or out[-1] != tag:
                out.append(tag)
    return out


if __name__ == '__main__':
    import glob, json, os, sys, collections, random
    sys.stdout.reconfigure(encoding='utf-8')
    H = os.path.dirname(os.path.abspath(__file__))
    n = none = 0
    c = collections.Counter()
    words = []
    for f in sorted(glob.glob(os.path.join(H, '[0-9][0-9][0-9].json'))):
        for w in json.load(open(f, encoding='utf-8'))['words']:
            t = tags(w['irab'])
            n += 1
            none += not t
            c.update(x.split(':')[0] for x in t)
            words.append((w['w'], w['irab'], t))
    print(f'{n} words, {none} with no tag ({100 * none / n:.1f}%)')
    print(len(c), 'keys:', ' '.join(f'{k}={v}' for k, v in c.most_common()))
    random.seed(int(sys.argv[1]) if len(sys.argv) > 1 else 1)
    for w, ir, t in random.sample(words, 25):
        print(f'{w}\t{t}\t{ir[:150]}')
