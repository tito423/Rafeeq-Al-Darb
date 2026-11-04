"""al-A'raf (7), written 2026-11-04 word by word against al-Da'as
(sheet.py 7); every doubt read in al-Jadwal and Darwish (sheet.py).
Two books against al-Da'as -> ours follows them, al-Da'as named.
One book against -> ours = al-Da'as, the other named.
Written in short codes (irab_dsl.py, phrasebook_sheet.txt).
Run once: fills 007.json in mushaf order."""
from write_surah import write, tokens


def alt(text, *alts):
    return {'text': text, 'check': 'alt', 'alts': [{'book': b, 'text': t} for b, t in alts]}


AMANNA = 'vpn:نا,W:نا pfa'
SILA = 'vpw,ww,alf,jsl'
IDHA = 'ظرف لما يستقبل من الزمان متضمن معنى الشرط غير جازم مبني على السكون في محل نصب'

I = [
 # 1
 'حروف من الحروف المقطعة لا محل لها من الإعراب',
 # 2
 'خبر لمبتدأ محذوف تقديره: هذا، مرفوع وعلامة رفعه الضمة الظاهرة,jibt',
 'فعل ماض مبني للمجهول مبني على الفتح,nhs,والجملة في محل رفع صفة لـ«كتاب»',
 'Xj:إلى,والكاف ضمير متصل مبني على الفتح في محل جر بـ«إلى»,tf:أنزل',
 'fs,nah',
 'فعل مضارع ناقص مجزوم بـ«لا» الناهية وعلامة جزمه السكون,jst',
 'j',
 'mj:في,mud,kf_md,tkhq:يكن',
 'اسم «يكن» مؤخر مرفوع وعلامة رفعه الضمة الظاهرة',
 'Xj:من,والهاء ضمير متصل مبني على الضم في محل جر بـ«من»,ts:حرج',
 'ljt,فعل مضارع منصوب بـ«أن» مضمرة بعد لام التعليل وعلامة نصبه الفتحة الظاهرة,ant,والمصدر المؤول من «أن» المضمرة والفعل في محل جر باللام,tf:أنزل',
 'bj,hk_jbb,tf:تنذر',
 'wa,اسم معطوف على المصدر المؤول مجرور وعلامة جره الكسرة المقدرة على الألف للتعذر',
 'lj,mjly,tb:ذكرى',
 # 3
 'van,ww,alf,jst',
 'musmf',
 'فعل ماض مبني للمجهول مبني على الفتح,nhs,jsl',
 'Xj:إلى,والكاف ضمير متصل مبني على الضم في محل جر بـ«إلى»,mim,tf:أنزل',
 'j',
 alt('mj:من,mud,kd_md,mim,والجار والمجرور متعلقان بمحذوف حال من نائب الفاعل', ('jadwal', '(من ربّ) جارّ ومجرور متعلّق ب (أنزل)')),
 'wa,nah',
 'فعل مضارع مجزوم بـ«لا» الناهية وعلامة جزمه حذف النون لأنه من الأفعال الخمسة,ww,alf,jm',
 'j',
 'mj:من,mud,hk_md,tf:تتبعوا',
 'mf',
 'صفة لمصدر محذوف منصوبة وعلامة نصبها الفتحة الظاهرة',
 'حرف زائد مبني على السكون',
 'فعل مضارع مرفوع وعلامة رفعه ثبوت النون لأنه من الأفعال الخمسة وحذفت منه إحدى التاءين,ww,jtl',
 # 4
 'ws,«كم» خبرية مبنية على السكون في محل رفع مبتدأ',
 'jz',
 'اسم مجرور لفظا منصوب محلا على أنه تمييز',
 'vpn:نا,و«نا» ضمير متصل مبني على السكون في محل رفع فاعل,والهاء ضمير متصل مبني على السكون في محل نصب مفعول به,jfkhm',
 'fw,vp,والهاء ضمير متصل مبني على السكون في محل نصب مفعول به مقدم,jm',
 'fam,mud,و«نا» ضمير متصل مبني على السكون في محل جر مضاف إليه',
 'hal',
 'حرف عطف مبني على السكون',
 'dms',
 'khw,والجملة الاسمية في محل نصب معطوفة على «بياتا»',
]

if __name__ == '__main__':
    toks = tokens(7)
    if len(I) == len(toks):
        write(7, I, "written 2026-11-04, every word checked against al-Da'as (sheet.py 7); doubts read in al-Jadwal and Darwish (sheet.py), the named views shown under the word")
    else:  # WIP: report how far the entries reach, by ayah
        done = toks[:len(I)]
        print('WIP', len(I), 'of', len(toks), 'tokens; last', done[-1] if done else None,
              'next', toks[len(I)] if len(I) < len(toks) else None)
