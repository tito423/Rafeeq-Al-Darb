"""al-An'am (6), written 2026-11-04 word by word against al-Da'as
(sheet.py 6); every doubt read in al-Jadwal and Darwish (sheet.py).
Two books against al-Da'as -> ours follows them, al-Da'as named.
One book against -> ours = al-Da'as, the other named.
Written in short codes (irab_dsl.py, phrasebook_sheet.txt).
Run once: fills 006.json in mushaf order."""
from write_surah import write, tokens


def alt(text, *alts):
    return {'text': text, 'check': 'alt', 'alts': [{'book': b, 'text': t} for b, t in alts]}


AMANNA = 'vpn:نا,W:نا pfa'
SILA = 'vpw,ww,alf,jsl'
IDHA = 'ظرف لما يستقبل من الزمان متضمن معنى الشرط غير جازم مبني على السكون في محل نصب'

I = [
 # 1
 'مبتدأ مرفوع وعلامة رفعه الضمة الظاهرة,jibt',
 'lj,لفظ الجلالة اسم مجرور باللام وعلامة جره الكسرة الظاهرة,والجار والمجرور متعلقان بمحذوف خبر',
 'اسم موصول مبني على السكون في محل جر صفة للفظ الجلالة',
 'vp,hs,jsl',
 'مفعول به منصوب وعلامة نصبه الكسرة نيابة عن الفتحة لأنه جمع مؤنث سالم',
 'wa,اسم معطوف على «السماوات» منصوب وعلامة نصبه الفتحة الظاهرة',
 'wa,vp,hs,jm',
 'مفعول به منصوب وعلامة نصبه الكسرة نيابة عن الفتحة لأنه جمع مؤنث سالم',
 'wa,اسم معطوف على «الظلمات» منصوب وعلامة نصبه الفتحة الظاهرة',
 'حرف عطف مبني على الفتح',
 'اسم موصول مبني على الفتح في محل رفع مبتدأ,والجملة الاسمية معطوفة على جملة «الحمد لله»',
 'فعل ماض مبني على الضم لاتصاله بواو الجماعة,ww,alf,jsl',
 'bj,mjb,mud,والهاء ضمير متصل مبني على الكسر في محل جر مضاف إليه,mim,tf:كفروا',
 'v5,ww,والجملة في محل رفع خبر المبتدأ «الذين»',
 # 2
 'ضمير منفصل مبني على الفتح في محل رفع مبتدأ',
 'اسم موصول مبني على السكون في محل رفع خبر,jist',
 'vp,hs,والكاف ضمير متصل مبني على الضم في محل نصب مفعول به,mim,jsl',
 'j',
 'mj:من,tf:خلق',
 'حرف عطف مبني على الفتح',
 'vpa,hs,jm',
 'mf',
 'ws,مبتدأ مرفوع وعلامة رفعه الضمة الظاهرة',
 'صفة لـ«أجل» مرفوعة وعلامة رفعها الضمة المقدرة على الألف المحذوفة للتعذر',
 'zk,mud,والهاء ضمير متصل مبني على الضم في محل جر مضاف إليه,والظرف متعلق بمحذوف خبر المبتدأ,jist',
 'حرف عطف مبني على الفتح',
 'ضمير منفصل مبني على السكون في محل رفع مبتدأ',
 'v5,ww,والجملة في محل رفع خبر المبتدأ «أنتم»,والجملة الاسمية معطوفة على ما قبلها',
 # 3
 'wa,ضمير منفصل مبني على الفتح في محل رفع مبتدأ',
 'لفظ الجلالة خبر مرفوع وعلامة رفعه الضمة الظاهرة,jist',
 'j',
 'mj:في,وعلامة جره الكسرة الظاهرة,والجار والمجرور متعلقان بلفظ الجلالة لتضمنه معنى المعبود',
 'wa,Xj:في',
 'اسم مجرور بـ«في» وعلامة جره الكسرة الظاهرة,والجار والمجرور معطوفان على «في السماوات»',
 'vm,hs,والجملة في محل نصب حال',
 'mf,mud,والكاف ضمير متصل مبني على الضم في محل جر مضاف إليه,mim',
 'wa,اسم معطوف على «سركم» منصوب وعلامة نصبه الفتحة الظاهرة,mud,والكاف ضمير متصل مبني على الضم في محل جر مضاف إليه,mim',
 'wa,vm,hs,jm',
 'اسم موصول مبني على السكون في محل نصب مفعول به',
 'v5,ww,jsl,ayd',
]

if __name__ == '__main__':
    toks = tokens(6)
    if len(I) == len(toks):
        write(6, I, "written 2026-11-04, every word checked against al-Da'as (sheet.py 6); doubts read in al-Jadwal and Darwish (sheet.py), the named views shown under the word")
    else:  # WIP: report how far the entries reach, by ayah
        done = toks[:len(I)]
        print('WIP', len(I), 'of', len(toks), 'tokens; last', done[-1] if done else None,
              'next', toks[len(I)] if len(I) < len(toks) else None)
