"""Ibrahim (14), written 2026-11-04 word by word against al-Da'as
(sheet.py 14); every doubt read in al-Jadwal and Darwish (sheet.py).
Two books against al-Da'as -> ours follows them, al-Da'as named.
One book against -> ours = al-Da'as, the other named.
Written in short codes (irab_dsl.py, phrasebook_sheet.txt).
Run once: fills 016.json in mushaf order."""
from write_surah import write, tokens


def alt(text, *alts):
    return {'text': text, 'check': 'alt', 'alts': [{'book': b, 'text': t} for b, t in alts]}


AMANNA = 'vpn:نا,W:نا pfa'
SILA = 'vpw,ww,alf,jsl'
IDHA = 'ظرف لما يستقبل من الزمان متضمن معنى الشرط غير جازم مبني على السكون في محل نصب'

I = [
 # 1
 'حروف من الحروف المقطعة لا محل لها من الإعراب.',
 alt('خبر لمبتدأ محذوف تقديره: هذا مرفوع وعلامة رفعه الضمة الظاهرة,jist', ('daas', '«كِتابٌ» خبر لمبتدأ محذوف تقديره هو والجملة مستأنفة')),
 'vpn:نا,W:نا pfa,hd_mf,والجملة في محل رفع صفة لـ«كتاب»',
 'Xj:إلى,والكاف ضمير متصل مبني على الفتح في محل جر بـ«إلى»,tf:أنزل',
 'اللام لام التعليل,vnl:أن,ant,والمصدر المؤول من «أن» المضمرة وما بعدها في محل جر باللام,tf:أنزل',
 'mf',
 'Xj:من',
 'mj:من,tf:تخرج',
 'Xj:إلى',
 'mj:إلى,tf:تخرج',
 alt('bj,mjb,mud,th', ('daas', '«بِإِذْنِ» متعلقان بتخرج')),
 'md,mud,W:هم pmd',
 'Xj:إلى',
 'mj:إلى,mud,والجار والمجرور بدل من «إلى النور» بإعادة الجار',
 'md',
 'sfj:العزيز',
 # 2
 'لفظ الجلالة بدل من «العزيز» مجرور وعلامة جره الكسرة الظاهرة',
 'اسم موصول مبني على السكون في محل جر صفة للفظ الجلالة',
 'lj,hd_jl,tkm',
 'اسم موصول مبني على السكون في محل رفع مبتدأ مؤخر,والجملة الاسمية صلة الموصول لا محل لها من الإعراب',
 'Xj:في',
 'mj:في,tsl',
 'wa,اسم موصول مبني على السكون في محل رفع معطوف على «ما» الأولى',
 'Xj:في',
 'mj:في,tsl',
 'ws,mb',
 'lj,mjly,tkhm,jist',
 'Xj:من',
 alt('mj:من,والجار والمجرور متعلقان بمحذوف صفة لـ«ويل»', ('daas', '«مِنْ عَذابٍ» متعلقان بويل')),
 'sfj:عذاب',
 # 3
 'اسم موصول مبني على الفتح في محل رفع مبتدأ',
 'v5,ww,jsl',
 'mf',
 'صفة لـ«الحياة» منصوبة وعلامة نصبها الفتحة المقدرة على الألف للتعذر',
 'Xj:على',
 'mj:على,tf:يستحب',
 'wa,v5,ww,jmsl',
 'Xj:عن',
 'mj:عن,mud,tf:يصد',
 'Am',
 alt('wa,v5,ww,W:ها pmf1,jmsl', ('darwish', 'والهاء نصب بنزع الخافض أي يبغون لها')),
 alt('mf2', ('jadwal', '(عوجا) مصدر في موضع الحال أي معوجّة')),
 'اسم إشارة مبني على الكسر في محل رفع مبتدأ,ksh',
 'Xj:في',
 'mj:في,tkhm',
 'sfj:ضلال,والجملة الاسمية في محل رفع خبر «الذين»',
 # 4
 'ws,ln',
 'vpn:نا,W:نا pfa,jsti',
 'jz',
 'اسم مجرور لفظا منصوب محلا على أنه مفعول به',
 'ahsr',
 'bj,mjb,mud,th',
 'md,mud,hk_md',
 alt('اللام لام التعليل,vnl:أن,hs,والمصدر المؤول من «أن» المضمرة وما بعدها في محل جر باللام,tf:أرسل', ('daas', '«لِيُبَيِّنَ» اللام للتعليل ومضارع منصوب بأن مضمرة بعد لام التعليل ومتعلقان بيبين')),
 'lj,W:هم pjl,tf:يبين',
 'fs,vm',
 'Af,jsti',
 'اسم موصول مبني على السكون في محل نصب مفعول به',
 'vm,hs,jsl',
 'wa,vmy,hs,jm',
 'اسم موصول مبني على السكون في محل نصب مفعول به',
 'vm,hs,jsl',
 alt('wh,dmf', ('jadwal', 'وجملة: «هو العزيز ... » لا محلّ لها استئنافيّة')),
 'kh1',
 'kh2,jihal',
]

if __name__ == '__main__':
    toks = tokens(14)
    if len(I) == len(toks):
        write(14, I, "written 2026-11-04, every word checked against al-Da'as (sheet.py 14); doubts read in al-Jadwal and Darwish (sheet.py), the named views shown under the word")
    else:  # WIP: report how far the entries reach, by ayah
        done = toks[:len(I)]
        print('WIP', len(I), 'of', len(toks), 'tokens; last', done[-1] if done else None,
              'next', toks[len(I)] if len(I) < len(toks) else None)
