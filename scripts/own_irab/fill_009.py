"""al-Tawba (9), written 2026-11-04 word by word against al-Da'as
(sheet.py 9); every doubt read in al-Jadwal and Darwish (sheet.py).
Two books against al-Da'as -> ours follows them, al-Da'as named.
One book against -> ours = al-Da'as, the other named.
Written in short codes (irab_dsl.py, phrasebook_sheet.txt).
Run once: fills 009.json in mushaf order."""
from write_surah import write, tokens


def alt(text, *alts):
    return {'text': text, 'check': 'alt', 'alts': [{'book': b, 'text': t} for b, t in alts]}


AMANNA = 'vpn:نا,W:نا pfa'
SILA = 'vpw,ww,alf,jsl'
IDHA = 'ظرف لما يستقبل من الزمان متضمن معنى الشرط غير جازم مبني على السكون في محل نصب'

I = [
 # 1
 'خبر لمبتدأ محذوف تقديره: هذه مرفوع وعلامة رفعه الضمة الظاهرة,jibt',
 'Xj:من',
 'Amj:من,ts:براءة',
 'wa,معطوف على لفظ الجلالة مجرور وعلامة جره الكسرة الظاهرة,mud,hk_md',
 'Xj:إلى',
 'اسم موصول مبني على الفتح في محل جر بـ«إلى»,ts:براءة',
 'vpt,t_fa,mim,jsl',
 'Xj:من',
 'mjy:من,tf:عاهد',
 # 2
 'fs,van,ww,alf,jst',
 'Xj:في',
 'mj:في,tf:سيحوا',
 'zm,mud,zt:سيحوا',
 'md',
 'wa,van,ww,alf,jm',
 '«أنّ» حرف توكيد ونصب مشبه بالفعل,والكاف ضمير متصل مبني على الضم في محل نصب اسم «أنّ»,mim',
 'khi:أنّ,mud',
 alt('مضاف إليه مجرور وعلامة جره الياء لأنه جمع مذكر سالم,hn,mud', ('daas', '«مُعْجِزِي» مضاف إليه مجرور وعلامة جره الياء لأنه جمع مذكر سالم، وحذفت النون للإضافة، والياء ضمير متصل في محل جر بالإضافة')),
 'Am,و«أنّ» وما بعدها في تأويل مصدر سدّ مسدّ مفعولي «اعلموا»',
 'wa,«أنّ» حرف توكيد ونصب مشبه بالفعل',
 'Ais:أنّ',
 'خبر «أنّ» مرفوع وعلامة رفعه الضمة المقدرة على الياء للثقل,mud',
 'مضاف إليه مجرور وعلامة جره الياء لأنه جمع مذكر سالم,و«أنّ» وما بعدها في تأويل مصدر معطوف على المصدر السابق',
 # 3
 'wa,خبر لمبتدأ محذوف تقديره: هذا مرفوع وعلامة رفعه الضمة الظاهرة,jm',
 'Xj:من',
 'Amj:من,tb:أذان',
 'wa,معطوف على لفظ الجلالة مجرور وعلامة جره الكسرة الظاهرة,mud,hk_md',
 'Xj:إلى',
 'mj:إلى,tb:أذان',
 'zm,mud,متعلق بـ«أذان»',
 'md',
 'sfj:الحج',
 '«أنّ» حرف توكيد ونصب مشبه بالفعل',
 'Ais:أنّ',
 'khi:أنّ',
 'Xj:من',
 'mjy:من,tb:بريء,و«أنّ» وما بعدها في تأويل مصدر مجرور بالباء المحذوفة والجار والمجرور متعلقان بـ«أذان»',
 'wa,مبتدأ مرفوع وعلامة رفعه الضمة الظاهرة,وخبره محذوف تقديره: بريء,mud,hd_md,jm',
 'fs,sh',
 'vpt,t_fa,mim,وهو في محل جزم فعل الشرط,jibt',
 'fr,dmf',
 'kh',
 'lj,والكاف ضمير متصل مبني على الضم في محل جر باللام,mim,tb:خير,jjz',
 'wa,sh',
 'vpt,t_fa,mim,وهو في محل جزم فعل الشرط,jm',
 'fr,van,ww,alf,jjz',
 '«أنّ» حرف توكيد ونصب مشبه بالفعل,والكاف ضمير متصل مبني على الضم في محل نصب اسم «أنّ»,mim',
 'khi:أنّ,mud',
 'مضاف إليه مجرور وعلامة جره الياء لأنه جمع مذكر سالم,hn,mud',
 'Am,و«أنّ» وما بعدها في تأويل مصدر سدّ مسدّ مفعولي «اعلموا»',
 'ws,va,hk,ant,jst',
 'اسم موصول مبني على الفتح في محل نصب مفعول به',
 'vpw,ww,alf,jsl',
 alt('bj,mjb,tf:بشّر', ('daas', '«بِعَذابٍ» متعلقان بالفعل كفروا')),
 'sfj:عذاب',
]

if __name__ == '__main__':
    toks = tokens(9)
    if len(I) == len(toks):
        write(9, I, "written 2026-11-04, every word checked against al-Da'as (sheet.py 9); doubts read in al-Jadwal and Darwish (sheet.py), the named views shown under the word")
    else:  # WIP: report how far the entries reach, by ayah
        done = toks[:len(I)]
        print('WIP', len(I), 'of', len(toks), 'tokens; last', done[-1] if done else None,
              'next', toks[len(I)] if len(I) < len(toks) else None)
