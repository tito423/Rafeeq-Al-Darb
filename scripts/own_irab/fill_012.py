"""Yusuf (12), written 2026-11-04 word by word against al-Da'as
(sheet.py 12); every doubt read in al-Jadwal and Darwish (sheet.py).
Two books against al-Da'as -> ours follows them, al-Da'as named.
One book against -> ours = al-Da'as, the other named.
Written in short codes (irab_dsl.py, phrasebook_sheet.txt).
Run once: fills 012.json in mushaf order."""
from write_surah import write, tokens


def alt(text, *alts):
    return {'text': text, 'check': 'alt', 'alts': [{'book': b, 'text': t} for b, t in alts]}


AMANNA = 'vpn:نا,W:نا pfa'
SILA = 'vpw,ww,alf,jsl'
IDHA = 'ظرف لما يستقبل من الزمان متضمن معنى الشرط غير جازم مبني على السكون في محل نصب'

I = [
 # 1
 'حروف من الحروف المقطعة لا محل لها من الإعراب.',
 'اسم إشارة مبني على السكون في محل رفع مبتدأ,lb,ksh',
 'kh,mud,jist',
 'md',
 'sfj:الكتاب',
 # 2
 'Xin:إنّ,W:نا pis:إنّ',
 'vpn:نا,W:نا pfa,hd_mf,jkh:إنّ',
 alt('hal', ('daas', '«قُرْآناً» مفعول به ثان أو حال')),
 'sfn:قرآنا,jist',
 '«لعلّ» حرف ترجّ ونصب مشبه بالفعل,والكاف ضمير متصل مبني على الضم في محل نصب اسم «لعلّ»,mim,jtl',
 'v5,ww,jfkh:لعلّ',
 # 3
 'ضمير منفصل مبني على الضم في محل رفع مبتدأ,jist',
 'vm,nhn,jfkhm',
 'Xj:على,kf_jb:على,tf:نقص',
 alt('mf,mud', ('jadwal', '(أحسن) مفعول مطلق نائب عن المصدر لأنه أضيف إلى المصدر')),
 'md',
 'bj,«ما» حرف مصدري مبني على السكون,والمصدر المؤول من «ما» وما بعدها في محل جر بالباء,tf:نقص',
 'vpn:نا,W:نا pfa,والجملة صلة الموصول الحرفي لا محل لها من الإعراب',
 'Xj:إلى,kf_jb:إلى,tf:أوحينا',
 'الهاء حرف تنبيه,و«ذا» اسم إشارة مبني على السكون في محل نصب مفعول به',
 'بدل من «هذا» منصوب وعلامة نصبه الفتحة الظاهرة',
 'wh,«إن» مخففة من الثقيلة مبنية على السكون,واسمها ضمير الشأن محذوف',
 'فعل ماض ناقص مبني على السكون لاتصاله بضمير الرفع المتحرك,والتاء ضمير متصل مبني على الفتح في محل رفع اسم «كان»',
 'Xj:من',
 alt('mj:من,mud,hk_md,th', ('jadwal', '(من قبل) جارّ ومجرور متعلّق بالغافلين')),
 'اللام الفارقة,Xj:من,hf',
 'mjy:من,والجار والمجرور متعلقان بمحذوف خبر «كان»,والجملة في محل رفع خبر «إن» المخففة,وجملة «إن كنت» في محل نصب حال',
 # 4
 alt('zmd,متعلق بفعل محذوف تقديره: اذكر', ('daas', '«إِذْ» ظرف زمان يتضمن معنى الشرط متعلق بفعل محذوف تقديره اذكر'), ('jadwal', '(إذ) ظرف للزمن الماضي مبنيّ في محلّ نصب متعلّق بالغافلين')),
 'vp,jidX:إذ',
 'فاعل مرفوع وعلامة رفعه الضمة الظاهرة,وامتنع من التنوين للعلمية والعجمة',
 'lj,اسم مجرور باللام وعلامة جره الياء لأنه من الأسماء الخمسة,mud,hk_md,tf:قال',
 '«يا» حرف نداء,منادى مضاف منصوب وعلامة نصبه الفتحة المقدرة على ما قبل ياء المتكلم المحذوفة,والتاء عوض عن ياء المتكلم,jmq',
 'Xin:إنّ,y_is:إنّ',
 'vptf,t_fa,jkh:إنّ',
 'جزء من العدد المركب,وهو مع «عشر» مبني على فتح الجزأين في محل نصب مفعول به',
 'الجزء الثاني من العدد المركب مبني على الفتح',
 'tm',
 'wa,معطوف على «أحد عشر» منصوب وعلامة نصبه الفتحة الظاهرة',
 'wa,man:الشمس',
 'vptf,t_fa,W:هم pmf1,jst',
 'lj,pjl,tb:ساجدين',
 alt('مفعول به ثان منصوب وعلامة نصبه الياء لأنه جمع مذكر سالم', ('jadwal', 'وهو حال من مفعول رأيت لأن الرؤية بصريّة وإن كانت في النوم')),
]

if __name__ == '__main__':
    toks = tokens(12)
    if len(I) == len(toks):
        write(12, I, "written 2026-11-04, every word checked against al-Da'as (sheet.py 12); doubts read in al-Jadwal and Darwish (sheet.py), the named views shown under the word")
    else:  # WIP: report how far the entries reach, by ayah
        done = toks[:len(I)]
        print('WIP', len(I), 'of', len(toks), 'tokens; last', done[-1] if done else None,
              'next', toks[len(I)] if len(I) < len(toks) else None)
