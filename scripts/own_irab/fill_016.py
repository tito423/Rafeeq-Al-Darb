"""al-Nahl (16), written 2026-11-02 word by word against al-Da'as
(sheet.py 16); every doubt read in al-Jadwal and Darwish (sheet.py).
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
 'vpa,jst',
 'fa,mud',
 'Am',
 alt('fw,W:لا nah', ('jadwal', '(الفاء) رابطة لجواب شرط مقدّر … وجملة: «لا تستعجلوه ...» في محلّ جزم جواب شرط مقدّر أي: إن طلبتم الأمر فلا تستعجلوه')),
 'فعل مضارع مجزوم بـ«لا» الناهية وعلامة جزمه حذف النون,ww,hd_mf,jm',
 'مفعول مطلق لفعل محذوف تقديره: أسبح منصوب وعلامة نصبه الفتحة الظاهرة,mud,hd_md,jst',
 'wa,vpa,hs,jm',
 alt('عن حرف جر و«ما» اسم موصول مبني على السكون في محل جر بـ«عن»,tf:تعالى', ('daas', '«عَمَّا» ما موصولية ومتعلقان بسبحان'), ('darwish', 'وعما تنازعه كل من سبحانه وتعالى وما يحتمل أن تكون مصدرية فلا تحتاج إلى عائد ويحتمل أن تكون موصولة فتحتاج إلى تقدير عائد')),
 'v5,ww,jsl,والعائد محذوف تقديره: يشركونه',
 # 2
 'vm,hs,jst',
 'mf',
 alt('bj,mjb,tf:ينزل', ('jadwal', '(بالروح) جارّ ومجرور حال من الملائكة أي مصحوبة بالوحي')),
 'Xj:من',
 'mj:من,mud,hk_md,th',
 'Xj:على',
 'musj:على,tf:ينزل',
 'vm,hs,jsl',
 'Xj:من',
 'mj:من,mud,hk_md,th',
 alt('«أن» مخففة من الثقيلة مبنية على السكون واسمها ضمير الشأن محذوف,والمصدر المؤول من «أن» وما بعدها في محل جر بدل من «الروح»', ('jadwal', '(أن) حرف مصدريّ … والمصدر المؤوّل (أن أنذروا ...) في محلّ جرّ بدل من الروح')),
 'van,ww,alf,jkh:أن',
 alt('Xin:أنّ,hd_is:أنّ,والمصدر المؤول من «أنّ» وما بعدها في محل نصب مفعول به لـ«أنذروا»', ('jadwal', 'والمصدر المؤوّل (أنّه لا إله إلّا أنا..) في محلّ جرّ بحرف جرّ محذوف أي بأنه لا إله إلّا أنا.. متعلّق ب (أنذروا..)')),
 'نافية للجنس تعمل عمل «إنّ» مبنية على السكون',
 'اسم «لا» مبني على الفتح في محل نصب,وخبرها محذوف تقديره: موجود,والجملة في محل رفع خبر «أنّ»',
 'ahsr',
 'ضمير منفصل مبني على السكون في محل رفع بدل من الضمير المستتر في الخبر المحذوف',
 'ff,van,ww,wq,والياء المحذوفة للتخفيف ضمير متصل مبني على السكون في محل نصب مفعول به,jjm',
 # 3
 'vp,hs,jst',
 'mfk',
 'wa,man:السماوات',
 'bj,mjb,th',
 'vpa,hs,jst',
 'عن حرف جر و«ما» اسم موصول مبني على السكون في محل جر بـ«عن»,tf:تعالى',
 'v5,ww,jsl,والعائد محذوف تقديره: يشركونه',
 # 4
 'vp,hs,jst',
 'mf',
 'Xj:من',
 'mj:من,tf:خلق',
 alt('fw,«إذا» الفجائية حرف مبني على السكون', ('daas', '«فَإِذا» الفاء زائدة وإذا الفجائية')),
 'dmf',
 'kh,jma:خلق',
 'sfr:خصيم',
]

if __name__ == '__main__':
    toks = tokens(16)
    if len(I) == len(toks):
        write(16, I, "written 2026-11-02, every word checked against al-Da'as (sheet.py 16); doubts read in al-Jadwal and Darwish (sheet.py), the named views shown under the word")
    else:  # WIP: report how far the entries reach, by ayah
        done = toks[:len(I)]
        print('WIP', len(I), 'of', len(toks), 'tokens; last', done[-1] if done else None,
              'next', toks[len(I)] if len(I) < len(toks) else None)
