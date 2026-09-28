# كمّل رفيق الدرب من حيث وقفنا

اقرأ بالترتيب: `AGENTS.md` ثم `CLAUDE.md` كاملًا (ملزم)، ثم أحدث سطور `TASK_FOLLOWUP.md`، ثم `TRAPS.md` للمنطقة التي ستعمل فيها. ردّ على المالك بالعربي.

## قواعد الشغل الملزمة

- بعد **كل خطوة صغيرة**: حدّث `TASK_FOLLOWUP.md` بأحدث نتيجة والتالي بالضبط، ثم شغّل `.\cp.bat "English measured description"` ليعمل commit + push. أي ملف جديد يحتاج `git add` أولًا (الفخ 55).
- لا تقل «خلص» قبل: `flutter analyze lib test` كامل، و`flutter test` كامل، ثم بناء موقّع وتثبيت ورؤية على المحاكي.
- البناء الموقّع فقط عبر `build_github_release.bat`، والمحاكي **مغلق أثناء البناء**. لا تشغّل analyze/test ولا تعدّل `lib/` بالتوازي مع البناء (الفخان 24 و54).
- لا إصدار ولا رفع Release إلا إذا طلب المالك صراحة.
- اترك الملفين غير المتتبعين الموجودين من قبل بلا لمس: `scripts/github_content_mirror_report.txt` و`scripts/out/`.

## الحالة الدقيقة الآن — 2026-09-28 ~12:17 دبي

- الفرع `master` مرفوع حتى `1a946651`:
  `checkpoint(wip): Item 4 step 4 add memorize-surah command`.
- المنشور ما زال `v3.69.2`؛ كل عمل رفيق أدناه غير منشور.
- آخر تحقق كامل كان بعد الخطوة 2: analyze نظيف، و641 اختبارًا ناجحًا + 4 متخطاة عمدًا.
- بعد تغييرات الخطوتين 3 و4 شُغّل التحقق المركز مرارًا: assistant analyze نظيف، و`assistant_intent_test.dart + code_layout_test.dart` = 15/15. **التحليل والاختبارات الكاملة ما زالت واجبة قبل البناء.**
- لا توجد تغييرات متتبعة غير محفوظة الآن؛ فقط الملفان غير المتتبعين المذكوران أعلاه.

## ما تم في بند المالك 4: رفيق يفهم العامية ويفتح أي شيء

1. فتح أقسام الإعدادات نفسها بالصوت تم وشوهد على المحاكي.
2. قاموس العامية المصرية وأوامر التشغيل/الإيقاف تم واختُبر بالصوت. أُصلح نطق ASR الملصوق `يار فيقطفيها...` وشوهد أنه عطّل فيديو البداية.
3. **جرد كل الشاشات العلوية انتهى في الكود:**
   - `scripts/inventory_assistant_screens.py` يجرد 60 `*Screen` عامة و49 وجهة `MaterialPageRoute` ويفشل عند أي شاشة جديدة/غير مصنفة.
   - `AssistantScreen` صار 44 قيمة.
   - كل الشاشات العلوية ذات المعنى للمستخدم مغطاة؛ `MISSING_TOP_LEVEL = set()`.
   - أضيفت مجموعات: عن التطبيق/المصادر/الدعم/الإهداءات/الختمة/بحث الكتب؛ شاشات الأذان والصلاة؛ علوم القرآن ومستويات التجويد؛ أربع شاشات للدرر؛ الرقية المقروءة والصوتية؛ التحميلات المبدئية؛ معاينة فيديو البداية؛ البحث الموضوعي.
   - فُصلت الرقية المقروءة عن الصوتية، ومركز الدرر عن تخريج الأحاديث، وحُفظ سلوك «افتح ضبط المواقيت والتاريخ» كقسم إعدادات مقابل «افتح شاشة...» كمحرر كامل.
   - منطق مطابقة الشاشات/الإعدادات نُقل بلا تغيير إلى `assistant_destination_match.dart`؛ ملف intent صار تحت سقف 800.
4. **أوامر التفاصيل بدأت:**
   - `BookTextReaderScreen` كان مدعومًا أصلًا عبر اسم الكتاب.
   - `SearchScreen` اتضح أنه يحتاج dependency فقط، فأضيفت وجهة «البحث الموضوعي».
   - أضيف `MemorizeSurahIntent`: «احفظ سورة الكهف» و«حفظني البقرة» يفتحان `HifzSessionScreen.surah` من صف السورة الحقيقي في `QuranRepository`. قبل الإصلاح كان أمر الحفظ يسقط خطأً إلى تشغيل السورة.
   - الجرد الحالي: 39 شاشة supported مباشرة، 2 supported by detailed intent، 9 detail-command candidates، 6 context-only children، 4 internal/lifecycle.

## التالي بالضبط

### الخطوة الأولى فقط: «سنن سورة …»

أضف intent تفصيليًا لـ `SingleSurahScreen`:

- أمثلة: «افتح سنن سورة الكهف»، «وريني سنن سورة الملك».
- حل اسم السورة من كتالوج السور الحقيقي الموجود أصلًا في `AssistantParser`.
- **اقبل فقط** السور الأربع الموجودة فعلًا في `sunanSuwarCatalog`: البقرة 2، الكهف 18، السجدة 32، الملك 67. لا توهم أن لكل سورة مدخل فضائل.
- التنفيذ يفتح `SingleSurahScreen(surahId: id)`.
- أضف اختبارين ناجحين واختبارًا لسورة غير موجودة في كتالوج السنن يثبت أنها لا تتحول إلى intent سنن مزيف.
- انقل `SingleSurahScreen` من `DETAIL_COMMAND_CANDIDATES` إلى `DETAIL_INTENT_SUPPORTED` في سكربت الجرد.
- شغّل الجرد، focused analyze، وassistant + layout tests؛ حدّث `TASK_FOLLOWUP.md` واعمل checkpoint.

### بعدها — لا تنفذ الكل دفعة واحدة

راجع المرشحين الثمانية الباقين في مجموعات صغيرة، وببيانات حقيقية فقط:

- `AzkarSectionScreen`: اسم قسم أذكار موجود فعليًا.
- `AyahReciterScreen` و`ReciterScreen`: اسم قارئ يُحل من مزوّد القارئ المناسب؛ لا تخلط قارئ آية بآية بقارئ التلاوة الكاملة.
- `HadeethEncCategoryScreen/DetailScreen` و`HadithBook/Chapter/DetailScreen`: لا تفتح detail بلا عنصر حقيقي من المستودع.
- الشاشات الست السياقية تبقى غير مباشرة: `AzanPlayerScreen`، وثلاثة أبناء للدرر، و`LinkListManageScreen`، و`QuoteCardScreen`. هذه لا يصح اختراع state لها لمجرد زيادة العدد.

ثم نفّذ أوامر التفاصيل التي طلبها المالك صراحة، وأولها «كبّر/صغّر الخط» كـ action حقيقي مع اختبار، وليس كقاموس فقط.

## الإغلاق المطلوب قبل اعتبار الجولة منتهية

1. `flutter analyze lib test` كامل = No issues.
2. `flutter test` كامل = صفر فشل.
3. checkpoint.
4. أوقف المحاكي، ثم شغّل `build_github_release.bat` وحده.
5. شغّل المحاكي:
   `E:\DevEnv\Android\Sdk\emulator\emulator.exe -avd Medium_Phone_API_36.1 -no-window -no-audio -gpu swiftshader_indirect -no-snapshot-save`
6. ثبّت الـAPK الموقّع بـ `adb install -r` من `E:\DevEnv\Android\Sdk\platform-tools\adb.exe`.
7. جرّب بالصوت ممثلًا من كل مجموعة جديدة، واقرأ screenshot/UI semantics للشاشة المفتوحة، لا تكتفِ بسطر intent في logcat.
8. لا تنشر؛ فقط اكتب ما شوهد وما لم يُشاهد.

ملفات الصوت القديمة موجودة في `C:\Users\Asus\AppData\Local\Temp\rafeeq-step2\`، ومسار الاختبار داخل الجهاز:
`/sdcard/Android/data/com.tito.rafeeq_aldarb/files/rafeeq_test.wav`.
