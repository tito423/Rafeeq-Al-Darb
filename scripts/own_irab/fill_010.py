"""Yunus (10), written 2026-11-04 word by word against al-Da'as
(sheet.py 10); every doubt read in al-Jadwal and Darwish (sheet.py).
Two books against al-Da'as -> ours follows them, al-Da'as named.
One book against -> ours = al-Da'as, the other named.
Written in short codes (irab_dsl.py, phrasebook_sheet.txt).
Run once: fills 010.json in mushaf order."""
from write_surah import write, tokens


def alt(text, *alts):
    return {'text': text, 'check': 'alt', 'alts': [{'book': b, 'text': t} for b, t in alts]}


AMANNA = 'vpn:نا,W:نا pfa'
SILA = 'vpw,ww,alf,jsl'
IDHA = 'ظرف لما يستقبل من الزمان متضمن معنى الشرط غير جازم مبني على السكون في محل نصب'

I = [
 # 1
 'حروف من الحروف المقطعة لا محل لها من الإعراب',
 'اسم إشارة مبني على السكون في محل رفع مبتدأ,lb,ksh',
 'kh,mud,jist',
 'md',
 'sfj:الكتاب',
 # 2
 'الهمزة حرف استفهام,vk',
 'lj,mjl,th',
 'خبر «كان» مقدم منصوب وعلامة نصبه الفتحة الظاهرة',
 'msd',
 'vpn:نا,W:نا pfa,و«أن» وما بعدها في تأويل مصدر في محل رفع اسم «كان» مؤخر',
 'Xj:إلى',
 'mj:إلى,tf:أوحى',
 '«من» حرف جر,والهاء ضمير متصل مبني على الضم في محل جر بـ«من»,mim,ts:رجل',
 'حرف تفسير مبني على السكون',
 'va,hk,ant',
 'mf,والجملة تفسيرية لا محل لها من الإعراب',
 'wa,va,hk,ant,jm',
 'اسم موصول مبني على الفتح في محل نصب مفعول به',
 'vpw,ww,alf,jsl',
 '«أنّ» حرف توكيد ونصب مشبه بالفعل',
 'lj,hd_jl,mim,tkhq:أنّ',
 'اسم «أنّ» مؤخر منصوب وعلامة نصبه الفتحة الظاهرة,mud',
 'md',
 'zk,mud,والظرف متعلق بالخبر المحذوف',
 'md,mud,والهاء ضمير متصل مبني على الكسر في محل جر مضاف إليه,mim',
 'vp',
 'فاعل مرفوع وعلامة رفعه الواو لأنه جمع مذكر سالم,jst',
 'Xin:إنّ',
 'الهاء حرف تنبيه,و«ذا» اسم إشارة مبني على السكون في محل نصب اسم «إنّ»',
 'lz,khi:إنّ',
 'sfr:ساحر,jmq',
 # 3
 'Xin:إنّ',
 'is:إنّ,mud,kd_md,mim,hmd,jist',
 'لفظ الجلالة خبر «إنّ» مرفوع وعلامة رفعه الضمة الظاهرة',
 'اسم موصول مبني على السكون في محل رفع صفة للفظ الجلالة',
 'vp,hs,jsl',
 'mfk',
 'wa,man:السماوات',
 'Xj:في',
 'mj:في,mud,tf:خلق',
 'md',
 'atf',
 'vpa,hs,jmsl',
 'Xj:على',
 'mj:على,tf:استوى',
 'vm,hs',
 'mf,jst',
 'ln',
 'jz',
 'اسم مجرور لفظا مرفوع محلا على أنه مبتدأ',
 'ahsr',
 'Xj:من',
 'mj:من,mud,tkhm',
 'md,mud,hk_md,jist',
 'اسم إشارة مبني على السكون في محل رفع مبتدأ,lb,والكاف حرف خطاب,mim,hmd',
 'بدل من اسم الإشارة مرفوع وعلامة رفعه الضمة الظاهرة',
 'kh,mud,kd_md,mim,jist',
 'ff,van,ww,hd_mf,والجملة جواب شرط غير جازم لا محل لها من الإعراب',
 'الهمزة حرف استفهام,والفاء استئنافية,ln',
 'v5,وأصله: تتذكّرون,ww,jst',
 # 4
 'Xj:إلى,hk_jb:إلى,tkm',
 'mbm,mud,kd_md,mim,jist',
 'hal',
 'مفعول مطلق لفعل محذوف منصوب وعلامة نصبه الفتحة الظاهرة,mud',
 'Am',
 'مفعول مطلق لفعل محذوف منصوب وعلامة نصبه الفتحة الظاهرة',
 'Xin:إنّ,hd_is:إنّ,jitl',
 'vm,hs',
 'mf,jkh:إنّ',
 'atf',
 'vm,hd_mf,hs,jm',
 'ljt,vnl:أن,hs,و«أن» المضمرة وما بعدها في تأويل مصدر في محل جر باللام,tf:يعيد',
 'اسم موصول مبني على الفتح في محل نصب مفعول به',
 'vpw,ww,alf,jsl',
 'wa,vpw,ww,alf,jmsl',
 'mfk',
 'bj,mjb,tf:يجزي',
 'ws,اسم موصول مبني على الفتح في محل رفع مبتدأ',
 'vpw,ww,alf,jsl',
 'lj,hd_jl,mim,tkm',
 'mbm,والجملة الاسمية في محل رفع خبر «الذين»',
 'Xj:من',
 'mj:من,ts:شراب',
 'wa,mar:شراب',
 'sfr:عذاب',
 'الباء حرف جر,و«ما» حرف مصدري مبني على السكون',
 'vkw,wwis:كان,alf,و«ما» وما بعدها في تأويل مصدر في محل جر بالباء,والجار والمجرور متعلقان بمحذوف صفة ثانية لـ«عذاب»',
 'v5,ww,jkhn:كان',
]

if __name__ == '__main__':
    toks = tokens(10)
    if len(I) == len(toks):
        write(10, I, "written 2026-11-04, every word checked against al-Da'as (sheet.py 10); doubts read in al-Jadwal and Darwish (sheet.py), the named views shown under the word")
    else:  # WIP: report how far the entries reach, by ayah
        done = toks[:len(I)]
        print('WIP', len(I), 'of', len(toks), 'tokens; last', done[-1] if done else None,
              'next', toks[len(I)] if len(I) < len(toks) else None)
