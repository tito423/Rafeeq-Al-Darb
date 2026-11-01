"""al-Anbiya (21), written 2026-11-01 word by word against al-Da'as
(sheet.py 21); every doubt read in al-Jadwal and Darwish (sheet.py).
Two books against al-Da'as -> ours follows them, al-Da'as named.
One book against -> ours = al-Da'as, the other named.
Written in short codes (irab_dsl.py, phrasebook_sheet.txt).
Run once: fills 021.json in mushaf order."""
from write_surah import write, tokens


def alt(text, *alts):
    return {'text': text, 'check': 'alt', 'alts': [{'book': b, 'text': t} for b, t in alts]}


AMANNA = 'vpn:نا,W:نا pfa'
SILA = 'vpw,ww,alf,jsl'
IDHA = 'ظرف لما يستقبل من الزمان متضمن معنى الشرط غير جازم مبني على السكون في محل نصب'

I = [
 # 1
 'vp',
 'lj,W:الناس mjl,tf:اقترب',
 'fa,mud,W:هم pmd,jibt',
 'wh,W:هم dms',
 'Xj:في',
 alt('mj:في,tkhm', ('daas', '«فِي غَفْلَةٍ» متعلقان بمعرضون')),
 alt('خبر ثان مرفوع وعلامة رفعه الواو لأنه جمع مذكر سالم,jihal', ('daas', '«مُعْرِضُونَ» خبر والجملة حالية')),
 # 2
 'ln',
 'vmy2,W:هم pmf',
 'jz',
 'فاعل مجرور لفظا بـ«من» الزائدة مرفوع محلا',
 'Xj:من',
 'mj:من,mud,W:هم pmd,ts:ذكر',
 alt('صفة ثانية لـ«ذكر» مجرورة وعلامة جرها الكسرة الظاهرة,وجملة «ما يأتيهم ...» تعليلية لا محل لها من الإعراب', ('daas', '«ذِكْرٍ» اسم مجرور لفظا مرفوع محلا فاعل والجملة مستأنفة')),
 'ahsr',
 'vpw,ww,hd_mf,jhal',
 'wh,W:هم dms',
 'v5,ww,jkh:هم,jihal',
 # 3
 'حال من فاعل «يلعبون» منصوبة وعلامة نصبها الفتحة الظاهرة',
 'فاعل لاسم الفاعل «لاهية» مرفوع وعلامة رفعه الضمة الظاهرة,mud,W:هم pmd',
 alt('wa,W:أسروا vpw,ww,alf,jm', ('jadwal', '(الواو) استئنافيّة ... وجملة: «أسرّوا النجوى ... » لا محلّ لها استئنافيّة')),
 'مفعول به منصوب وعلامة نصبه الفتحة المقدرة على الألف للتعذر',
 'اسم موصول مبني على الفتح في محل رفع بدل من الواو في «أسروا»',
 'vpw,ww,alf,jsl',
 alt('حرف استفهام بمعنى النفي مبني على السكون', ('daas', '«هَلْ» اسم استفهام')),
 'اسم إشارة مبني على السكون في محل رفع مبتدأ,والهاء للتنبيه',
 'ahsr',
 'kh',
 alt('sfr:بشر,mud,W:كم pmd,mim,jst', ('jadwal', 'وجملة: «هل هذا إلّا بشر ... » في محلّ نصب مقول القول لقول مقدّر'), ('darwish', 'والجملة الاستفهامية في محل نصب بدل من النجوى لأنها بمثابة التفسير لها')),
 'hmzi,والفاء حرف عطف على محذوف يقتضيه السياق,W:تأتون v5,ww',
 'mf',
 'wh,W:أنتم ضمير منفصل مبني على السكون في محل رفع مبتدأ',
 'v5,ww,jkh:أنتم,jihal',
 # 4
 'vp,hs,jst',
 'مبتدأ مرفوع وعلامة رفعه الضمة المقدرة على ما قبل ياء المتكلم منع من ظهورها اشتغال المحل بالحركة المناسبة,mud,y_md',
 'vm,hs,jfkhm,jmq',
 'mf',
 'Xj:في',
 'mj:في,thm:القول',
 'wa,W:الأرض maj:السماء',
 'wa,W:هو dmf',
 'kh',
 'kh2,والجملة معطوفة على جملة مقول القول',
 # 5
 'حرف إضراب انتقالي مبني على السكون',
 'vpw,ww,alf,jst',
 'خبر لمبتدأ محذوف تقديره: هو، مرفوع وعلامة رفعه الضمة الظاهرة,mud,jmq',
 'md',
 'حرف إضراب انتقالي مبني على السكون,hk',
 'vpa,hs,hd_mf,jst',
 'حرف إضراب انتقالي مبني على السكون',
 'dmf',
 'kh,jst',
 alt('ff,واللام لام الأمر,W:يأت فعل مضارع مجزوم بلام الأمر وعلامة جزمه حذف حرف العلة,hs,W:نا pmf,jjg', ('jadwal', '(الفاء) رابطة لجواب شرط مقدّر ... وجملة: «يأتنا ... » في محلّ جزم جواب شرط مقدّر')),
 'bj,W:آية mjb,tf:يأت',
 alt('الكاف حرف جر,W:ما اسم موصول مبني على السكون في محل جر بالكاف,ts:آية', ('jadwal', '(الكاف) حرف جرّ وتشبيه ... (ما) حرف مصدريّ ... والمصدر المؤوّل (ما أرسل..) في محلّ جرّ بالكاف متعلّق بمحذوف مفعول مطلق')),
 'vpm',
 'نائب فاعل مرفوع وعلامة رفعه الواو لأنه جمع مذكر سالم,jsl',
 # 6
 'ln',
 'vp,tt,jst',
 'zm,mud,zt:آمنت,W:هم pmd',
 'jz',
 'فاعل مجرور لفظا بـ«من» الزائدة مرفوع محلا',
 'vpn:نا,W:نا pfa,W:ها pmf,والجملة في محل جر صفة لـ«قرية»',
 'hmzi,والفاء حرف عطف,W:هم dms',
 'v5,ww,jkh:هم,jm',
]

if __name__ == '__main__':
    toks = tokens(21)
    if len(I) == len(toks):
        write(21, I, "written 2026-11-01, every word checked against al-Da'as (sheet.py 21); doubts read in al-Jadwal and Darwish (sheet.py), the named views shown under the word")
    else:  # WIP: report how far the entries reach, by ayah
        done = toks[:len(I)]
        print('WIP', len(I), 'of', len(toks), 'tokens; last', done[-1] if done else None,
              'next', toks[len(I)] if len(I) < len(toks) else None)
