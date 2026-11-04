"""Hud (11), written 2026-11-04 word by word against al-Da'as
(sheet.py 11); every doubt read in al-Jadwal and Darwish (sheet.py).
Two books against al-Da'as -> ours follows them, al-Da'as named.
One book against -> ours = al-Da'as, the other named.
Written in short codes (irab_dsl.py, phrasebook_sheet.txt).
Run once: fills 011.json in mushaf order."""
from write_surah import write, tokens


def alt(text, *alts):
    return {'text': text, 'check': 'alt', 'alts': [{'book': b, 'text': t} for b, t in alts]}


AMANNA = 'vpn:نا,W:نا pfa'
SILA = 'vpw,ww,alf,jsl'
IDHA = 'ظرف لما يستقبل من الزمان متضمن معنى الشرط غير جازم مبني على السكون في محل نصب'

I = [
 # 1
 'حروف من الحروف المقطعة لا محل لها من الإعراب',
 'خبر لمبتدأ محذوف تقديره: هذا مرفوع وعلامة رفعه الضمة الظاهرة,jibt',
 'vpm,tt',
 'nf,mud,hd_md,والجملة في محل رفع صفة لـ«كتاب»',
 'atf',
 'vpm,tt,ونائب الفاعل ضمير مستتر تقديره: هي,jm',
 'Xj:من',
 'اسم مبني على السكون في محل جر بـ«من»,mud,tf:أحكم',
 'md',
 'بدل من «حكيم» مجرور وعلامة جره الكسرة الظاهرة',
 # 2
 '«أن» حرف مصدري ونصب مبني على السكون أدغمت نونه في لام «لا»,و«لا» حرف نفي مبني على السكون',
 'فعل مضارع منصوب بـ«أن» وعلامة نصبه حذف النون لأنه من الأفعال الخمسة,ww,alf,و«أن» وما بعدها في تأويل مصدر في محل جر بحرف جر محذوف,والجار والمجرور متعلقان بالفعل «فصّلت»',
 'ahsr',
 'Ao',
 '«إنّ» حرف توكيد ونصب مشبه بالفعل,wq,y_is:إنّ',
 'lj,والكاف ضمير متصل مبني على الضم في محل جر باللام,mim,tb:نذير',
 'Xj:من,والهاء ضمير متصل مبني على الكسر في محل جر بـ«من»,tb:نذير',
 'khi:إنّ',
 'wa,mar:نذير,jist',
 # 3
 'wa,msd,hk',
 'van,ww,alf',
 'mf,mud,kd_md,mim,و«أن» وما بعدها في تأويل مصدر معطوف على المصدر السابق',
 'atf',
 'van,ww,alf,jm',
 'Xj:إلى,hk_jb:إلى,tf:توبوا',
 'فعل مضارع مجزوم لأنه جواب الطلب وعلامة جزمه السكون,والكاف ضمير متصل مبني على الضم في محل نصب مفعول به,mim,hs',
 'mt',
 'sfn:متاعا',
 'Xj:إلى',
 'mj:إلى,tf:يمتّع',
 'صفة لـ«أجل» مجرورة وعلامة جرها الكسرة المقدرة على الألف للتعذر',
 'wa,فعل مضارع معطوف على «يمتّعكم» مجزوم وعلامة جزمه حذف حرف العلة,hs,jm',
 'mf1,mud',
 'مضاف إليه مجرور وعلامة جره الياء لأنه من الأسماء الخمسة,mud',
 'md',
 'mf2,mud,hd_md',
 'ws,sh',
 'فعل مضارع مجزوم بـ«إن» وعلامة جزمه حذف النون لأنه من الأفعال الخمسة,وأصله: تتولّوا,ww,alf,وهو فعل الشرط,jibt',
 'fr,Xin:إنّ,y_is:إنّ',
 'vm,ana,jkh:إنّ,وجملة «إنّ» وما بعدها في محل جزم جواب الشرط',
 '«على» حرف جر,والكاف ضمير متصل مبني على الضم في محل جر بـ«على»,mim,tf:أخاف',
 'mf,mud',
 'md',
 'sfj:يوم',
 # 4
 'Xj:إلى',
 'Amj:إلى,tkm',
 'mbm,mud,kd_md,mim,jist',
 alt('wh,dmf', ('jadwal', '(الواو) عاطفة')),
 'Xj:على',
 'mj:على,mud,tb:قدير',
 'md',
 'kh,jihal',
]

if __name__ == '__main__':
    toks = tokens(11)
    if len(I) == len(toks):
        write(11, I, "written 2026-11-04, every word checked against al-Da'as (sheet.py 11); doubts read in al-Jadwal and Darwish (sheet.py), the named views shown under the word")
    else:  # WIP: report how far the entries reach, by ayah
        done = toks[:len(I)]
        print('WIP', len(I), 'of', len(toks), 'tokens; last', done[-1] if done else None,
              'next', toks[len(I)] if len(I) < len(toks) else None)
