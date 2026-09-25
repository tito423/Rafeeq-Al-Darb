"""The Arabic label of one word from its Quranic Arabic Corpus morphology.

One place for it, used by build_sciences_db.py and fix_word_grammar_labels.py.

What the first version got wrong (measured 2026-09-25 over all 75,973 rows,
after the owner saw «عَلَى» labelled «جمع»):

  * It searched the whole morphology string with `\\bP\\b`, `\\bACC\\b`,
    `\\bSUB\\b`. `POS:P` (preposition), `POS:ACC` (إنّ and her sisters) and
    `POS:SUB` (أنْ …) are PART-OF-SPEECH tags, and the word boundary after the
    colon matched them: every preposition read «جمع» (7,459), every إنّ
    «منصوب» (2,223), every أنْ «منصوب» (626).
  * It never read the person/gender/number token (`3MP`, `MS`, `FP` …), so
    verbs, pronouns and most nouns had no number or gender, and it read
    `PRON:3MP` - the ATTACHED pronoun - as if it described the word itself.
  * The subjunctive (`MOOD:SUBJ`) was never recognised.

Here a label is read only from the word's own feature tokens: whole tokens,
never substrings, and never a `KEY:value` token except MOOD.
"""
import re

# The corpus's own Arabic name for every part-of-speech tag, from its tagset
# page (corpus.quran.com/documentation/tagset.jsp, read 2026-09-25). The first
# table here had 16 tags missing - shown in English («COND», «SUB», «T» …,
# 4,516 rows) - and four named otherwise than the corpus names them, one of
# them wrongly: SUP is «حرف زائد», not «حرف (تفسير/عطف بيان)».
POS_AR = {
    "N": "اسم", "PN": "اسم علم", "ADJ": "صفة", "IMPN": "اسم فعل أمر",
    "PRON": "ضمير", "DEM": "اسم إشارة", "REL": "اسم موصول",
    "T": "ظرف زمان", "LOC": "ظرف مكان", "V": "فعل",
    "P": "حرف جر", "EMPH": "لام التوكيد", "IMPV": "لام الأمر",
    "PRP": "لام التعليل", "CONJ": "حرف عطف", "SUB": "حرف مصدري",
    "ACC": "حرف نصب", "AMD": "حرف استدراك", "ANS": "حرف جواب",
    "AVR": "حرف ردع", "CAUS": "حرف سببية", "CERT": "حرف تحقيق",
    "CIRC": "حرف حال", "COM": "واو المعية", "COND": "حرف شرط",
    "EQ": "حرف تسوية", "EXH": "حرف تحضيض", "EXL": "حرف تفصيل",
    "EXP": "أداة استثناء", "FUT": "حرف استقبال", "INC": "حرف ابتداء",
    "INT": "حرف تفسير", "INTG": "حرف استفهام", "NEG": "حرف نفي",
    "PREV": "حرف كاف", "PRO": "حرف نهي", "REM": "حرف استئنافية",
    "RES": "أداة حصر", "RET": "حرف إضراب", "RSLT": "حرف واقع في جواب الشرط",
    "SUP": "حرف زائد", "SUR": "حرف فجاءة", "VOC": "حرف نداء",
    "INL": "حروف مقطعة",
    # NUM is in the 0.x morphology file (سَبْعَ، أَرْبَعِينَ، أَلْفَ - 273 words)
    # but not on the current tagset page, so its name is ours: the grammar's
    # own term for a numeral noun.
    "NUM": "اسم عدد",
}


def pos_label(morph: str) -> str:
    m = re.search(r"POS:(\w+)", morph)
    tag = m.group(1) if m else ""
    return POS_AR.get(tag, tag or "حرف")


CASE_AR = {"NOM": "مرفوع", "GEN": "مجرور", "ACC": "منصوب"}
MOOD_AR = {"MOOD:JUS": "مجزوم", "MOOD:SUBJ": "منصوب"}
TAG_AR = {"PERF": "فعل ماضٍ", "IMPF": "فعل مضارع", "IMPV": "فعل أمر"}
NUM_AR = {"S": "مفرد", "D": "مثنى", "P": "جمع"}
GEN_AR = {"M": "مذكر", "F": "مؤنث"}
_PGN = re.compile(r'^([123])?([MF])?([SDP])?$')


def label(morph: str) -> str:
    """«مرفوع ، جمع ، مذكر», «مجزوم / فعل مضارع ، مفرد ، مذكر», or ''."""
    toks = morph.split()
    own = [t for t in toks if ':' not in t and not t.endswith('+')]
    # A POS tag is never a feature: `POS:ACC` is not the accusative.
    case = next((CASE_AR[t] for t in own if t in CASE_AR), '')
    case = case or next((MOOD_AR[t] for t in toks if t in MOOD_AR), '')
    tag = next((TAG_AR[t] for t in own if t in TAG_AR), '')
    if tag:
        case = case + ' / ' + tag if case else tag
    num = gen = ''
    for t in own:
        m = _PGN.match(t)
        if m and any(m.groups()):
            gen = gen or GEN_AR.get(m.group(2) or '', '')
            num = num or NUM_AR.get(m.group(3) or '', '')
    extra = ' ، '.join(x for x in (num, gen) if x)
    if case and extra:
        return case + ' ، ' + extra
    return case or extra
