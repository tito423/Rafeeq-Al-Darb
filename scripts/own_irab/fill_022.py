"""al-Hajj (22), written 2026-11-01 word by word against al-Da'as
(sheet.py 22); every doubt read in al-Jadwal and Darwish (sheet.py).
Two books against al-Da'as -> ours follows them, al-Da'as named.
One book against -> ours = al-Da'as, the other named.
Written in short codes (irab_dsl.py, phrasebook_sheet.txt).
Run once: fills 022.json in mushaf order."""
from write_surah import write, tokens


def alt(text, *alts):
    return {'text': text, 'check': 'alt', 'alts': [{'book': b, 'text': t} for b, t in alts]}


AMANNA = 'vpn:نا,W:نا pfa'
SILA = 'vpw,ww,alf,jsl'
IDHA = 'ظرف لما يستقبل من الزمان متضمن معنى الشرط غير جازم مبني على السكون في محل نصب'

I = [
 # 1
 '«يا» حرف نداء مبني على السكون,و«أي» منادى نكرة مقصودة مبني على الضم في محل نصب,و«ها» حرف تنبيه',
 'بدل من «أي» مرفوع وعلامة رفعه الضمة الظاهرة,وجملة النداء ابتدائية لا محل لها من الإعراب',
 'van5,ww,alf,وجملة «اتقوا ربكم» جواب النداء لا محل لها من الإعراب',
 'mf,mud,W:كم pmd,mim',
 'in',
 'is:إن,mud',
 'md',
 'khi:إن',
 'sfr:شيء,jtl',
 # 2
 'zm,mud,zt:تذهل',
 'v5,ww,W:ها pmf,jid',
 'vm',
 'fa,mud',
 'md,jst',
 'Xj:عن,W:ما musj:عن,tf:تذهل',
 alt('vp,tt,hi,jsl,ayd', ('daas', '«أَرْضَعَتْ» ماض وفاعل والجملة معطوفة')),
 'wa,W:تضع vm',
 'fa,mud',
 'md,mud',
 'md',
 'mf,mud,W:ها pmd,jm',
 'wa,W:ترى vma,ant',
 'mf',
 'حال منصوبة وعلامة نصبها الفتحة المقدرة على الألف للتعذر,jm',
 'wh,W:ما نافية حجازية تعمل عمل «ليس» مبنية على السكون',
 'ضمير منفصل مبني على السكون في محل رفع اسم «ما»',
 'bjz,W:سكارى اسم مجرور لفظا بالباء الزائدة وعلامة جره الكسرة المقدرة على الألف للتعذر في محل نصب خبر «ما»,jhal',
 'wa,W:لكن حرف استدراك ونصب مشبه بالفعل مبني على الفتح',
 'is:لكن,mud',
 'Am',
 alt('khi:لكن,والجملة معطوفة على جملة مقدرة', ('daas', '«وَلكِنَّ عَذابَ اللَّهِ شَدِيدٌ» ... والجملة معطوفة على جملة الحال وهي في محل نصب مثلها')),
 # 3
 'ws,W:من حرف جر,hf',
 'mj:من,tkm',
 alt('اسم موصول مبني على السكون في محل رفع مبتدأ مؤخر,jist', ('darwish', 'ومن نكرة موصوفة حتما وهي مبتدأ مؤخر ... وجملة يجادل في الله صفة لمن')),
 'vm,hs,jsl',
 'Xj:في',
 'Amj:في,tf:يجادل',
 'bj,W:غير mjb,mud,th',
 'md',
 'wa,W:يتبع vm,hs,jm',
 'mf,mud',
 'md',
 'sfj:شيطان',
 # 4
 'vpm',
 'Xj:على,hk_jb:على,tf:كتب',
 'Xin:أن,والهاء ضمير الشأن مبني على الضم في محل نصب اسم «أن»,والمصدر المؤول من «أن» وما بعدها في محل رفع نائب فاعل',
 'ishm',
 'فعل ماض مبني على الفتح المقدر على الألف للتعذر في محل جزم فعل الشرط,hs,hd_mf',
 'fr,W:أن حرف توكيد ونصب مشبه بالفعل,hd_is:أن',
 alt('vm,hs,hd_mf,jkh:أن,وجملة «فأنه يضله» في محل جزم جواب الشرط', ('jadwal', 'والمصدر المؤوّل (أنّه يضلّه..) في محلّ رفع مبتدأ خبره محذوف أي فإضلاله واقع أو حاصل')),
 'wa,W:يهدي vmy2,hs,hd_mf,jm',
 'Xj:إلى',
 'mj:إلى,mud,tf:يهدي',
 'md,وجملة الشرط وجوابه في محل رفع خبر المبتدأ «من»,وجملة «من تولاه ...» في محل رفع خبر «أن»',
]

if __name__ == '__main__':
    toks = tokens(22)
    if len(I) == len(toks):
        write(22, I, "written 2026-11-01, every word checked against al-Da'as (sheet.py 22); doubts read in al-Jadwal and Darwish (sheet.py), the named views shown under the word")
    else:  # WIP: report how far the entries reach, by ayah
        done = toks[:len(I)]
        print('WIP', len(I), 'of', len(toks), 'tokens; last', done[-1] if done else None,
              'next', toks[len(I)] if len(I) < len(toks) else None)
