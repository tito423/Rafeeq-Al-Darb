"""al-Ra'd (13), written 2026-11-04 word by word against al-Da'as
(sheet.py 13); every doubt read in al-Jadwal and Darwish (sheet.py).
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
 'ish,lb,ksh',
 'kh,mud,والجملة الاسمية ابتدائية لا محل لها من الإعراب',
 'md',
 'wa,اسم موصول مبني على السكون في محل رفع مبتدأ',
 'vpm,nhs,jsl',
 'Xj:إلى,والكاف ضمير متصل مبني على الفتح في محل جر بـ«إلى»,tf:أنزل',
 'Xj:من',
 'mj:من,mud,kf_md,tf:أنزل',
 'خبر «الذي» مرفوع وعلامة رفعه الضمة الظاهرة,jim',
 'wh,«لكنّ» حرف استدراك ونصب مشبه بالفعل',
 'اسم «لكنّ» منصوب وعلامة نصبه الفتحة الظاهرة,mud',
 'md',
 'ln',
 alt('v5,ww,jfkh:لكنّ,وجملة «لكنّ» وما بعدها في محل نصب حال', ('jadwal', 'وجملة: «لكنّ أكثر ... » لا محلّ لها معطوفة على جملة الذي أنزل ... الحقّ')),
 # 2
 'لفظ الجلالة مبتدأ مرفوع وعلامة رفعه الضمة الظاهرة',
 'اسم موصول مبني على السكون في محل رفع خبر,والجملة الاسمية ابتدائية لا محل لها من الإعراب',
 'vp,hs,jsl',
 'mfk',
 'bj,mjb,mud,th',
 'md',
 alt('v5,ww,W:ها pmf,والجملة في محل جر صفة لـ«عمد»', ('jadwal', 'وجملة: «ترونها ... » في محلّ نصب حال من السموات')),
 'atf',
 'vpa,hs,jm',
 'Xj:على',
 'mj:على,tf:استوى',
 'wa,vp,hs,jm',
 'mf',
 'wa,man:الشمس',
 'mb',
 alt('vmy,hs,jfkhm,والجملة الاسمية ابتدائية لا محل لها من الإعراب', ('jadwal', 'وجملة: «كلّ يجري ... » في محلّ نصب حال من مفعول سخّر')),
 'lj,mjl,tf:يجري',
 'صفة لـ«أجل» مجرورة وعلامة جرها الكسرة المقدرة على الألف للتعذر',
 'vm,hs',
 'mf,jst',
 'vm,hs',
 'mfk,jst',
 '«لعلّ» حرف ترجّ ونصب مشبه بالفعل,والكاف ضمير متصل مبني على الضم في محل نصب اسم «لعلّ»,mim,jtl',
 'bj,mjb,mud,tb:توقنون',
 'md,mud,والكاف ضمير متصل مبني على الضم في محل جر مضاف إليه,mim',
 'v5,ww,jfkh:لعلّ',
 # 3
 alt('wa,dmf', ('daas', '«وَهُوَ» الواو استئنافية هو مبتدأ')),
 'اسم موصول مبني على السكون في محل رفع خبر',
 'vp,hs,jsl',
 'mf',
 'wa,vp,hs,jmsl',
 'Xj:في,W:ها pj:في,tf:جعل',
 'mf',
 'wa,man:رواسي',
 'wa,Xj:من',
 'mj:من,mud,والجار والمجرور متعلقان بالفعل «جعل» بعدهما',
 'md',
 'vp,hs,jst',
 'Xj:في,W:ها pj:في,tf:جعل',
 'مفعول به منصوب وعلامة نصبه الياء لأنه مثنى',
 'صفة لـ«زوجين» منصوبة وعلامة نصبها الياء لأنه ملحق بالمثنى',
 'vmy,hs',
 'mf1',
 'mf2,jst',
 'Xin:إنّ',
 'Xj:في',
 'اسم إشارة مبني على السكون في محل جر بـ«في»,lb,ksh,tkhq:إنّ',
 'lz,اسم «إنّ» مؤخر منصوب وعلامة نصبه الكسرة نيابة عن الفتحة لأنه جمع مؤنث سالم,jist',
 'lj,mjl,ts:آيات',
 'v5,ww,والجملة في محل جر صفة لـ«قوم»',
 # 4
 alt('wa,Xj:في', ('daas', '«وَفِي الْأَرْضِ» الواو استئنافية ومتعلقان بخبر مقدم')),
 'mj:في,tkm',
 'mbm',
 'sfr:قطع',
 'wa,mar:قطع',
 'Xj:من',
 'mj:من,ts:جنات',
 alt('wa,mar:جنات', ('daas', '«وَزَرْعٌ» معطوف على أعناب')),
 'wa,mar:جنات',
 'sfr:نخيل',
 'wa,معطوف على «صنوان» مرفوع وعلامة رفعه الضمة الظاهرة,mud',
 'md',
 'فعل مضارع مبني للمجهول مرفوع وعلامة رفعه الضمة المقدرة على الألف للتعذر,nhs',
 'bj,mjb,tf:يسقى',
 alt('sfj:ماء,والجملة في محل رفع صفة لما ذكر', ('daas', 'والجملة صفة لنخيل')),
 'wa,vm,nhn,jm',
 'mf,mud,W:ها pmd',
 'Xj:على',
 'mj:على,tf:نفضل',
 'Xj:في',
 alt('mj:في,thm:بعضها', ('daas', '«فِي الْأُكُلِ» متعلقان بنفضل')),
 'Xin:إنّ',
 'Xj:في',
 'اسم إشارة مبني على السكون في محل جر بـ«في»,lb,ksh,tkhq:إنّ',
 'lz,اسم «إنّ» مؤخر منصوب وعلامة نصبه الكسرة نيابة عن الفتحة لأنه جمع مؤنث سالم,jist',
 'lj,mjl,ts:آيات',
 'v5,ww,والجملة في محل جر صفة لـ«قوم»',
]

if __name__ == '__main__':
    toks = tokens(13)
    if len(I) == len(toks):
        write(13, I, "written 2026-11-04, every word checked against al-Da'as (sheet.py 13); doubts read in al-Jadwal and Darwish (sheet.py), the named views shown under the word")
    else:  # WIP: report how far the entries reach, by ayah
        done = toks[:len(I)]
        print('WIP', len(I), 'of', len(toks), 'tokens; last', done[-1] if done else None,
              'next', toks[len(I)] if len(I) < len(toks) else None)
