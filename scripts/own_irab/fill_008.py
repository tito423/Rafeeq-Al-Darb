"""al-Anfal (8), written 2026-11-04 word by word against al-Da'as
(sheet.py 8); every doubt read in al-Jadwal and Darwish (sheet.py).
Two books against al-Da'as -> ours follows them, al-Da'as named.
One book against -> ours = al-Da'as, the other named.
Written in short codes (irab_dsl.py, phrasebook_sheet.txt).
Run once: fills 008.json in mushaf order."""
from write_surah import write, tokens


def alt(text, *alts):
    return {'text': text, 'check': 'alt', 'alts': [{'book': b, 'text': t} for b, t in alts]}


AMANNA = 'vpn:نا,W:نا pfa'
SILA = 'vpw,ww,alf,jsl'
IDHA = 'ظرف لما يستقبل من الزمان متضمن معنى الشرط غير جازم مبني على السكون في محل نصب'

I = [
 # 1
 'v5,ww,والكاف ضمير متصل مبني على الفتح في محل نصب مفعول به,jst',
 'j,hk',
 'mj:عن,tf:يسألون',
 'va,hk,ant,jst',
 'mb',
 'lj,Amj:اللام,tkhm,jimq',
 'wa,معطوف على لفظ الجلالة مجرور وعلامة جره الكسرة الظاهرة',
 'ff,van,ww,alf,jjg',
 'Ao',
 'wa,van,ww,alf,jm',
 'mf,mud',
 'md,mud,kd_md,mim',
 'wa,van,ww,alf,jm',
 'Ao',
 'wa,معطوف على لفظ الجلالة منصوب وعلامة نصبه الفتحة الظاهرة,mud,hd_md',
 'sh',
 'فعل ماض ناقص مبني على السكون لاتصاله بضمير الرفع المتحرك في محل جزم فعل الشرط,t_is:كان,mim,وجواب الشرط محذوف دل عليه ما قبله',
 'khny:كان',
 # 2
 '«إنّ» حرف توكيد مكفوف عن العمل,و«ما» كافة',
 'مبتدأ مرفوع وعلامة رفعه الواو لأنه جمع مذكر سالم',
 'اسم موصول مبني على الفتح في محل رفع خبر,jist',
 'ظرف لما يستقبل من الزمان متضمن معنى الشرط مبني على السكون في محل نصب',
 'فعل ماض مبني للمجهول مبني على الفتح',
 'لفظ الجلالة نائب فاعل مرفوع وعلامة رفعه الضمة الظاهرة,jid',
 'vp,tt',
 'fa,mud,hd_md,mim,jjg,وجملة الشرط وجوابه صلة الموصول لا محل لها من الإعراب',
 'wa,ظرف لما يستقبل من الزمان متضمن معنى الشرط مبني على السكون في محل نصب',
 'فعل ماض مبني للمجهول مبني على الفتح,tt',
 'Xj:على,والهاء ضمير متصل مبني على الكسر في محل جر بـ«على»,mim,tf:تليت',
 'nf,mud,hd_md,jid',
 'vp,tt,hi,والهاء ضمير متصل مبني على الضم في محل نصب مفعول به,mim,jjg',
 alt('tm', ('jadwal', '(إيمانا) مفعول به ثان منصوب')),
 'wa,Xj:على',
 'mj:على,mud,hd_md,mim,tf:يتوكلون',
 'v5,ww,jm',
 # 3
 'اسم موصول مبني على الفتح في محل رفع بدل من «الذين»',
 'v5,ww,jsl',
 'mf',
 'wa,«من» حرف جر,و«ما» اسم موصول مبني على السكون في محل جر بـ«من»,tf:ينفقون',
 'vpn:نا,و«نا» ضمير متصل مبني على السكون في محل رفع فاعل,والهاء ضمير متصل مبني على الضم في محل نصب مفعول به,mim,jsl,ayd',
 'v5,ww,jmsl',
 # 4
 'ishk,ksh',
 'ضمير فصل مبني على السكون وحُرّك بالضم لالتقاء الساكنين لا محل له من الإعراب',
 'khw,jist',
 'صفة لمفعول مطلق محذوف منصوبة وعلامة نصبها الفتحة الظاهرة',
 'lj,hd_jl,mim,tkm',
 'mbm,jist',
 'zk,والظرف متعلق بمحذوف صفة لـ«درجات»,mud',
 'md,mud,hd_md,mim',
 'wa,mar:درجات',
 'wa,mar:درجات',
 'sfr:رزق',
]

if __name__ == '__main__':
    toks = tokens(8)
    if len(I) == len(toks):
        write(8, I, "written 2026-11-04, every word checked against al-Da'as (sheet.py 8); doubts read in al-Jadwal and Darwish (sheet.py), the named views shown under the word")
    else:  # WIP: report how far the entries reach, by ayah
        done = toks[:len(I)]
        print('WIP', len(I), 'of', len(toks), 'tokens; last', done[-1] if done else None,
              'next', toks[len(I)] if len(I) < len(toks) else None)
