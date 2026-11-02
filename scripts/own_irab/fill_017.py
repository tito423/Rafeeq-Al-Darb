"""al-Isra (17), written 2026-11-02 word by word against al-Da'as
(sheet.py 17); every doubt read in al-Jadwal and Darwish (sheet.py).
Two books against al-Da'as -> ours follows them, al-Da'as named.
One book against -> ours = al-Da'as, the other named.
Written in short codes (irab_dsl.py, phrasebook_sheet.txt).
Run once: fills 017.json in mushaf order."""
from write_surah import write, tokens


def alt(text, *alts):
    return {'text': text, 'check': 'alt', 'alts': [{'book': b, 'text': t} for b, t in alts]}


AMANNA = 'vpn:نا,W:نا pfa'
SILA = 'vpw,ww,alf,jsl'
IDHA = 'ظرف لما يستقبل من الزمان متضمن معنى الشرط غير جازم مبني على السكون في محل نصب'

I = [
 # 1
 'مفعول مطلق لفعل محذوف تقديره: أسبح منصوب وعلامة نصبه الفتحة الظاهرة,mud,jibt',
 'اسم موصول مبني على السكون في محل جر مضاف إليه',
 'vpa,hs,jsl',
 'bj,mjb,mud,hk_md,tf:أسرى',
 'zm,zt:أسرى',
 'Xj:من',
 alt('mj:من,tf:أسرى', ('darwish', 'ومن المسجد جار ومجرور متعلقان بمحذوف حال أي مبتدئا')),
 'sfj:المسجد',
 'Xj:إلى',
 alt('mj:إلى,tf:أسرى', ('darwish', 'وإلى المسجد الأقصى حال أيضا أي منتهيا إلى المسجد')),
 'صفة لـ«المسجد» مجرورة وعلامة جرها الكسرة المقدرة على الألف للتعذر',
 'اسم موصول مبني على السكون في محل جر صفة ثانية لـ«المسجد»',
 'vpn:نا,W:نا pfa,jsl',
 'zk,mud,hd_md,zt:باركنا',
 alt('ljt,W:نري vnl:أن,nhn,hd_mf,والمصدر المؤول من «أن» المضمرة وما بعدها في محل جر باللام,والجار والمجرور متعلقان بمحذوف خبر لمبتدأ محذوف تقديره: ذلك', ('jadwal', 'والمصدر المؤوّل (أن نريه) في محلّ جرّ باللام متعلّق ب (أسرى)')),
 'Xj:من',
 'mj:من,mud,W:نا pmd,tf:نريه',
 'Xin:إنّ,hd_is:إنّ,jsti',
 'dmf',
 'kh,jismkh:إنّ',
 'kh2',
 # 2
 'wst,W:آتى vpn:نا,W:نا pfa,jst',
 'مفعول به أول منصوب وعلامة نصبه الفتحة المقدرة على الألف للتعذر',
 'mf2',
 'wa,W:جعل vpn:نا,W:نا pfa,والهاء ضمير متصل مبني على الضم في محل نصب مفعول به أول,jm',
 'مفعول به ثان منصوب وعلامة نصبه الفتحة المقدرة على الألف للتعذر',
 'lj,W:بني اسم مجرور باللام وعلامة جره الياء لأنه ملحق بجمع المذكر السالم,hn,tb:هدى',
 'مضاف إليه مجرور وعلامة جره الفتحة نيابة عن الكسرة لأنه ممنوع من الصرف',
 '«أن» حرف تفسير مبني على السكون,W:لا nah',
 'فعل مضارع مجزوم بـ«لا» الناهية وعلامة جزمه حذف النون,ww,alf,والجملة تفسيرية لا محل لها من الإعراب',
 'Xj:من',
 'اسم مجرور بـ«من» وعلامة جره الكسرة المقدرة على ما قبل ياء المتكلم منع من ظهورها اشتغال المحل بالحركة المناسبة,mud,y_md,والجار والمجرور متعلقان بمحذوف مفعول به ثان',
 'mf1',
 # 3
 'بدل من «وكيلا» منصوب وعلامة نصبه الفتحة الظاهرة,mud',
 'اسم موصول مبني على السكون في محل جر مضاف إليه',
 'vpn:نا,W:نا pfa,jsl,والعائد محذوف تقديره: حملناهم',
 'zk,mud,zt:حملنا',
 'md',
 'Xin:إنّ,hd_is:إنّ,jtl',
 'vk,ismhs,jkh:إنّ',
 'khn:كان',
 'sfn:عبدا',
 # 4
 'wa,W:قضى vpn:نا,W:نا pfa,jm',
 'Xj:إلى',
 'اسم مجرور بـ«إلى» وعلامة جره الياء لأنه ملحق بجمع المذكر السالم,hn,tf:قضينا',
 'مضاف إليه مجرور وعلامة جره الفتحة نيابة عن الكسرة لأنه ممنوع من الصرف',
 'Xj:في',
 alt('mj:في,tf:قضينا', ('darwish', 'وفي الكتاب حال والمراد به التوراة')),
 'اللام واقعة في جواب قسم محذوف,W:تفسدن فعل مضارع مرفوع وعلامة رفعه ثبوت النون المحذوفة لتوالي الأمثال,وواو الجماعة المحذوفة لالتقاء الساكنين ضمير متصل في محل رفع فاعل,والنون للتوكيد,jjq',
 'Xj:في',
 'mj:في,tf:تفسدن',
 alt('مفعول مطلق منصوب وعلامة نصبه الياء لأنه مثنى', ('darwish', 'ومرتين نصب على الظرفية')),
 'wa,W:لتعلن معطوفة على «لتفسدن» وإعرابها مثلها',
 'mt',
 'sfn:علوا',
]

if __name__ == '__main__':
    toks = tokens(17)
    if len(I) == len(toks):
        write(17, I, "written 2026-11-02, every word checked against al-Da'as (sheet.py 17); doubts read in al-Jadwal and Darwish (sheet.py), the named views shown under the word")
    else:  # WIP: report how far the entries reach, by ayah
        done = toks[:len(I)]
        print('WIP', len(I), 'of', len(toks), 'tokens; last', done[-1] if done else None,
              'next', toks[len(I)] if len(I) < len(toks) else None)
