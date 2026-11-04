"""al-Hijr (15), written 2026-11-04 word by word against al-Da'as
(sheet.py 15); every doubt read in al-Jadwal and Darwish (sheet.py).
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
 'wa,maj:الكتاب',
 'sfj:قرآن',
 # 2
 '«ربما» كافة ومكفوفة لا عمل لها',
 'vm,jst',
 'musf_fa',
 SILA,
 'msd0',
 'vkw,wwis:كان',
 'khny:كان,والمصدر المؤول من «لو» وما بعدها في محل نصب مفعول به لـ«يود»',
 # 3
 'va,W:هم pmf,ant,jst',
 'فعل مضارع مجزوم لأنه جواب الطلب وعلامة جزمه حذف النون,ww,alf,والجملة جواب الطلب لا محل لها من الإعراب',
 'wa,فعل مضارع مجزوم معطوف على «يأكلوا» وعلامة جزمه حذف النون,ww,alf,jm',
 'wa,فعل مضارع مجزوم معطوف على «يأكلوا» وعلامة جزمه حذف حرف العلة,W:هم pmf,hmd,jm',
 'fa',
 alt('ff,«سوف» حرف استقبال مبني على الفتح', ('daas', '«فَسَوْفَ» الفاء استئنافية وسوف حرف استقبال')),
 'v5,ww,والمفعول محذوف تقديره: عاقبة أمرهم,jjm',
 # 4
 'ws,ln',
 AMANNA + ',jst',
 'jz',
 'اسم مجرور لفظا منصوب محلا على أنه مفعول به',
 'ahsr',
 'wh,lj,W:ها pjl,tkm',
 'mbm,والجملة الاسمية في محل نصب حال من «قرية»',
 'sfr:كتاب',
 # 5
 'ln',
 'vm,jst',
 'jz',
 'اسم مجرور لفظا مرفوع محلا على أنه فاعل',
 'mf,mud,W:ها pmd',
 'wa,ln',
 'v5,ww,jm',
]

if __name__ == '__main__':
    toks = tokens(15)
    if len(I) == len(toks):
        write(15, I, "written 2026-11-04, every word checked against al-Da'as (sheet.py 15); doubts read in al-Jadwal and Darwish (sheet.py), the named views shown under the word")
    else:  # WIP: report how far the entries reach, by ayah
        done = toks[:len(I)]
        print('WIP', len(I), 'of', len(toks), 'tokens; last', done[-1] if done else None,
              'next', toks[len(I)] if len(I) < len(toks) else None)
