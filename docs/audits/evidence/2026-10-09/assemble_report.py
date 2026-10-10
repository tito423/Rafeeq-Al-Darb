from pathlib import Path
import collections
import hashlib
import json
import re
import subprocess

ev = Path('docs/audits/evidence/2026-10-09')
report = Path('docs/audits/AUDIT_2026-10-09.md')
s = report.read_text(encoding='utf-8')
(ev / 'interim-audit-notes.md').write_text(s, encoding='utf-8')
rows = [line for line in s.splitlines() if re.match(r'^\| A-\d+ \|', line)]
assert len(rows) == 48
rank = {'Critical': 0, 'High': 1, 'Medium': 2, 'Low': 3}
rows.sort(key=lambda x: (rank[x.split('|')[2].strip()], int(x.split('|')[1].strip()[2:])))
counts = collections.Counter(x.split('|')[2].strip() for x in rows)
checks = s[s.index('| الأمر |'):s.index('## نتائج مؤكدة')].strip()
prior = s[s.index('| التاريخ / ID |'):s.index('## نطاق المراجعة')].strip()
prior = prior.replace('تكلفة queries لم تكتمل', 'الاستعلامات مقاسة الآن على المضيف: db-census-query-timings.json')
prior = prior.replace('تحليل zip الحالي قيد الاستكمال', 'التحليل مكتمل: APK315956036B، native190797816B، assets121147472B')
prior = prior.replace('Still open، sweep لم يكتمل', 'Still open')
prior = prior.replace('لازم إعادة قياس الأزرار المحددة وfont scaling؛ لا ادعاء أنها اتصلحت', 'A-22/A-23 مثبتتان بالقياس الفعلي؛ فحص TalkBack الكامل على الهاتف مطلوب')
prior = prior.replace('المحاكي الحالي بدأ مع audio واستمر', 'سطر التشغيل الحالي بلا -no-audio، ومشغّل فعلي وصل PLAYING')
old = next(x for x in prior.splitlines() if x.startswith('| 09-27 / stages1'))
stages = [('1', '1a31331e', 'تنظيم الملفات؛ الفحص الحالي CLEAN'), ('2', '7cd000ce', 'layering ضمن الاختبارات الناجحة'), ('3', '0973c03a', 'قواعد lints موجودة وanalyze الحالي بلا مشاكل'), ('4', '895349ae', 'حذف الكود السابق ونقل probe موثقان؛ المصدر الحالي مقروء'), ('5', '895349ae / 4511141b / 7919c6da', 'CI تحليل واختبارات فعلي؛ c5911503 أخضر؛ تغطية الباك إند ناقصة A-08'), ('6', '4511141b', 'ARCHITECTURE.md محدث سابقًا؛ لا نساوي التوثيق باختبار كل ميزة على هاتف')]
prior = prior.replace(old, '\n'.join(f'| 09-27 / stage{n} | Fixed `{commit}` | {detail} |' for n, commit, detail in stages))
review = json.loads((ev / 'review-checklist.json').read_text(encoding='utf-8'))
assert len(review) == 563
changed = [r['path'] for r in review if hashlib.sha256(Path(r['path']).read_bytes()).hexdigest() != r['sha256']]
assert not changed, changed

h = '''# أوديت رفيق الدرب — 2026-10-09

اكتملت المرحلة الأولى في **2026-10-10** على نسخة المصدر `4a3f0b82`، مع حفظ الأدلة أثناء الاستكمال. اسم التقرير ثابت حسب طلب المالك. لم يتغير كود التطبيق أو الباك إند أو نص ديني أو إصدار منشور. تجارب الجهاز تستخدم APK الأصلي الموقع **3.87.0+102**؛ APK بناء الأوديت لم يُنشر ولم يُثبت فوقه.

## الملخص التنفيذي

قُرئت ملفات النطاق الأصلي كلها: **563 ملفًا، 125820 سطرًا، منها 502 ملف في lib**. بصماتها لم تتغير. القائمة كاملة في نهاية التقرير، والبصمات وحدود القراءة في `review-checklist.json`. روجعت أيضًا أداة توليد مرجع الصلاة خارج هذا الحصر عند ظهور مسارها القديم.

النتائج **48**: **1 Critical، 9 High، 34 Medium، 4 Low**. الرقم يتضمن فجوة صيانة Flutter A-48؛ توافق الإصدار الجديد محتاج تأكيد، ولا يُعتبر كراشًا مثبتًا. القراءة المصدرية والاختبارات المعزولة واللقطات على الجهاز مميزة في عمود الحالة. لم تُصلح أي نتيجة في هذه المرحلة.

أخطر خمس مشاكل:

1. **A-01:** بيانات وصول R2 منشورة في تاريخ المستودع وما زالت تقبل طلب قراءة مصادقًا؛ تدويرها إجراء المالك الأول.
2. **A-02:** المزامنة تحذف أحداثًا محلية لم يحفظها الخادم؛ إثبات 1001 عدادًا → 1000 مع HTTP200.
3. **A-03:** واجهة مراجعة المحتوى تسمح بالكتابة والحذف باسم أي مراجع دون اعتماد.
4. **A-09:** IDs إشعارات الختمة تتداخل مع الصلاة والإقامة والأقوال؛ يمكن استبدال أو إلغاء تنبيه آخر.
5. **A-37:** القارئ المحدود يحجب الصفحة المشتركة الأخيرة لـ5 سور؛ مجموع 48 آية لا يمكن الوصول إليه بهذه المسارات.

الأدلة داخل [evidence/2026-10-09](evidence/2026-10-09/). القياسات لا تُعد شهادة لصحة كل النصوص الدينية أو أداء هاتف المالك. كل ما يحتاج هاتفًا أو حسابًا محدد في قسم الحدود.

## نتائج الفحوصات الفعلية

'''
h += checks + '''

سجلات الأوامر تحمل الأمر ومجلد التشغيل وكود الخروج والتوقيت. الـ776 اختبارًا الناجح هي مجموعة التطبيق الأصلية؛ اختبارات الأوديت الإضافية في مجلد الأدلة ولا تدخل هذا الرقم. مدة المجموعة 94.58 ثانية. `pub get` لم يغير القفل.

CI مرّ فعليًا بنجاح على `c5911503`، run38042597878. ويوجد فشل حقيقي في خطوة `Run flutter test` في run37748135654؛ لا محاكاة بإفساد المصدر. الأدلة `ci-recent-runs.json` و`ci-failure-detail.json`.

**فحص صلاة إضافي فشل ولا نخفيه:** نجح 400 طلب حي لـAlAdhan. مقارنة 2400 وقت باستخدام حساب التطبيق وجدت 2360 داخل حد دقيقتين، وتجاوزته 40 حالة لعصر لندن STANDARD فقط: 3 دقائق يوم 10 أكتوبر و4 يوم 25 أكتوبر. مطابقة معلمات 20 طريقة وعدم تكرار IDs نجحتا (2pass/1fail). اختبار التطبيق الأصلي بمرجعي مارس/يونيو نجح ضمن776؛ لا خلط بين المرجع القديم والحي.

تتبعنا الفرق بحساب شمسي مستقل PyEphem4.2.1 مع pressure=0/elevation=0 وعبور ظل الشمس بعد الزوال: لندن 10 أكتوبر 14:40:45 و25 أكتوبر 14:16:16 UTC؛ التطبيق 14:40/14:15 وAlAdhan 14:43/14:19. هذا يدعم حساب التطبيق في هاتين الحالتين؛ لا نضيف «المواقيت خاطئة» أو دقائق بلا مصدر. الاختبار الفاشل محفوظ في `prayer-calculation-live.log` والحساب المستقل في `prayer-independent-solar.json`. [مرجع AlAdhan](https://aladhan.com/prayer-times-api)، [حساب ظل Adhan الأصلي](https://github.com/batoulapps/adhan-js/blob/develop/src/SolarTime.ts)، [توثيق PyEphem](https://rhodesmill.org/pyephem/quick.html).

## حالة الأوديتين السابقين

كل commit للإصلاح المذكور تم حله والتحقق أنه ancestor للشجرة الحالية؛ `previous-audit-commit-ancestors.json`. الأرقام القديمة لا تستعمل كقياسات اليوم.

'''
h += prior + '\n\n## جدول النتائج، مرتب بالخطورة\n\n| ID | الخطورة | التصنيف | file:line | المشكلة والسيناريو | التأثير | الحل المقترح | الحالة والدليل |\n|---|---|---|---|---|---|---|---|\n' + '\n'.join(rows) + '\n'
proof = {
    'A-01': ('credential-history.json؛ generic-history-secrets.json؛ credential-live-readonly.json', 'المسح شمل12357blob نصيًا و1110382443بايت؛ تطابق بالقيم المحلية دون إخراجها. طلب ListObjectsV2 MaxKeys1 رجع200. لم نختبر الكتابة أو نطاقًا آخر للصلاحيات. حذف الملف الحالي لا يسحب سرًا من تاريخ عام.', 'تدوير Cloudflare وتحديث scripts/.env وإبطال القديم ثم طلب قراءة للتحقق. إجراء المالك مطلوب.'),
    'A-02': ('backend-reproduction.json', 'الحدود100updates/1000counters تقص المدخلات بينما نجاح200 يمسح كامل الطابور المحلي. إثبات Worker والخدمة الفعليين في بيئة معزولة؛ لا تعديل لحساب حي.', 'دفعات ضمن الحدود وحذف IDs الدفعة فقط، وإبقاء غير المرسل. إصلاح عميل محلي يحافظ على API.'),
    'A-03': ('backend-reproduction.json', 'المسار يقبل هوية المراجع من المدخلات دون ربطها باعتماد. إثبات الكتابة والحذف محلي؛ الإنتاج اقتصر على GET العام دون كتابة باسم شخص.', 'اعتماد للمراجع وربط اسمه به؛ تغيير عقد API يحتاج موافقة.'),
    'A-04': ('sync_service.dart:327 ومسارات init/signIn/flush/pull المقروءة', 'pull يكتب فوق التفضيلات دون مقارنة بالطابور أو تاريخ الحالة المحلية؛ بعض notifiers تقرأ مرة واحدة. المسار ثابت من المصدر، وتجربة حساب Google حي لم تُنفذ.', 'سياسة تعارض تحفظ الحالة المحلية الأحدث وتحدث المستهلكين؛ الطوابع أو مهاجرة الحالة يحتاجان موافقة بحسب الحل.'),
    'A-09': ('notification-id-collisions.json؛ fasting-iqama-ids.log', 'معادلة Dart صنعت اصطدامات7100/7200/7500. إلغاء الصيام7300–7349 يتداخل مع الإقامة7300–7304. هذه IDs إضافة الإشعارات المشتركة؛ لم ندع اصطدام receiver أو PendingIntent مختلف لم نثبته.', 'نطاقات منفصلة وتوزيع مركزي، مع تنظيف IDs القديمة وإعادة تسليح التنبيهات والتحقق على الجهاز.'),
    'A-11': ('مسارات إعادة التسليح المحددة في الجدول', 'التكرار يعيد ساعة ودقيقة يوم واحد بدل حساب صلاة اليوم التالي وفق المكان والمنطقة. حفظ الساعة لا يحسب اختلاف الشمس في اليوم التالي.', 'حساب يوم التقويم التالي بمعلمات المكان والمنطقة. تجربة يومين وتغيير منطقة على الهاتف مطلوبة.'),
    'A-12': ('AndroidManifest.xml؛ AdhanBootReceiver.kt؛ AdhanScheduler.kt', 'directBootAware وحده لا يسجل LOCKED_BOOT_COMPLETED ولا يتيح SharedPreferences الافتراضية قبل فتح PIN. لا نساوي reboot بلا PIN بهذه الحالة.', 'مسار locked boot وتخزين الجدول الضروري في device-protected storage؛ مهاجرة التخزين تحتاج حسمًا، واختبار هاتف بقفل PIN مطلوب.'),
    'A-13': ('DownloadForegroundService.kt:191 وminSdk24', 'NotificationChannel وNotification.Builder ذي channel يطلبان API26، دون حارس للـ24/25. دليلنا المصدر وحد النظام؛ لم ندع أن هذا الكراش رُصد علىAPI36.', 'SDK guard وNotificationCompat.Builder؛ تحقق جهاز API24/25 بعد الإصلاح.'),
    'A-37': ('single-surah-bounds.json؛ single-surah-bounds.log', 'الملك27–30، مريم96–98، الرحمن68–78، الواقعة77–96، ق36–45. استعلام فعلي يثبت MAX(page_number)؛ الشاشة الفعلية تعرض الملك562–563 وتحجب564.', 'استعمال surahEndPages للسورة نفسها مع ترشيح آياتها في النص. حدود عرض محلية دون تغيير حرف قرآني.'),
    'A-46': ('quran-restore-page.log؛ device-quran-controls.png؛ device-quran-jump541.png', 'APK الموقع عرض الحديد/541 فوق صورة الفاتحة؛ الانتقال الصريح541 أعاد صورة الحديد. اختبار الشاشة الفعلية وSQLite الحقيقية: badge541/controller0/آيات1:1–7. إعادة الفتح لاحقًا صحيحة؛ السباق يعتمد على ترتيب اكتمال Prefs/data وليس كل تشغيل.', 'مواءمة PageController مع الصفحة المسترجعة بعد اتصاله، وحماية callbacks من dispose. لا تغيير الصور أو النص.')}
h += '\n## تفاصيل كل Critical وHigh\n\n'
for line in rows:
    cells = [x.strip() for x in line.strip('|').split('|')]
    if cells[1] not in ['Critical', 'High']:
        continue
    id, sev, cat, loc, scenario, impact, fix, status = cells
    evidence, detail, nextfix = proof[id]
    h += f'### {id} — {cat} ({sev})\n\n**الموضع:** {loc}.\n\n**السيناريو:** {scenario}.\n\n**الدليل وحدوده:** {detail} ملفات الإثبات: {evidence}.\n\n**الإصلاح والتحقق التالي:** {nextfix}\n\n'

h += '''## سلامة المحتوى والمصادر

- **1266HEAD، صفر فشل** للمصدر الأساسي، مع Content-Type واستبعاد HTML/soft404. يشمل289كتابًا،45ترجمة،28فيديو قصة وصورها،14تسجيل أذكار كاملًا،195URLفريدًا للأذكار الفردية، أول وآخر سورة/آية للقراء المتاحين، صفحات المصحف والحزم والنماذج. لا يعني فحص كل ملف آية لكل قارئ.
- **1039طلب مرآة:**1038نجحوا أول مرة، و500عابر واحد للكتابal_ikhwan رجع200/31448B عند الإعادة. وجود ملفاتASR علىGitHub لا يعني أن التطبيق سيحاولها A-15.
- **343مقارنة كاملة:**289كتابًا+45ترجمة+7حزمHadeethEnc+حزمتي الحديث والعلوم؛ SHA256 بعد فكgzip متطابقة كلها وZIPCRC نجح لكل مدخل. الكتب192634418B من المصدر. ليست مقارنة كاملة لكل صوت/فيديو.
- **930Range** حقيقي0–1023 نجحت. ملفا عبدالباسط001/114 ذوا بداية صفرية حملا كاملًا وفكهماffmpeg بلا خطأ؛ ONNX الخمسة protobuf ولا يشترط ترويسةMP3/ZIP. الأدلة `media-ranges-summary.json` و`zero-prefix-audio-decode.json`.
- **289كتابًا،297611صفحة،1765706فقرة** دون كتب فارغة أو أنواع خاطئة. مرشح15فهرسًا خارج rawJSON لم يكن bug: BookText.fromBytes الفعلي حوّلها داخل الحدود لكل الكتب. أربعة كتب بلاshamelaUrl لهاketabUrl/sourceLabel/editionCard، فلا نسميها «بلا مصدر».
- قاعدة القرآن114سورة/6236آية؛ الأعداد مطابقة وquick_check=ok. الترجمات45 تغطي6236مرجعًا دون زيادة/نقص/نص فارغ؛ هذا اكتمال بنيوي وليس تصديقًا لترجمة المعاني.
- اقتباسات القرآن الموسومة في غاية المريد وتيسير أحكام التجويد:1391+187=1578، كلها substrings حرفية للمرجع المشار إليه؛ دون normalization أو تعديل. ليس فحصًا لكل صفحة مطبوعة أو للاقتباسات غير الموسومة.
- Darussalam مقاسة في13149حديثًا؛ [Sunnah.com/About](https://sunnah.com/about) يسمي حافظ زبير علي زئي، بينما التطبيق يعرض المؤسسة دون الطبعة A-44. لا نغير اسمًا أو درجة دينية دون موافقة. قرار HadeethEnc المؤسسي الموثق سابقًا مميز عنه؛ لا نخترع عالمًا لكل مادة.
-9channelIDs وعناوينها تطابق الكتالوج في الطلب الحي و7avatars صحيحة؛ لا ادعاء بتحقق ملكيتها الرسمية المستقل.238إطارTourWEBP في7لغات فُحصت بنيتها وحدودها، وليست شهادة بصرية لكل إطار.

التفاصيل `endpoint-inventory.json` و`content-full-comparison-summary.json` و`content-structure.json` و`book-parser-census.json` و`channel-identities.json`.

## الأداء والحجم والأدوات

| القياس | النتيجة | الحدود |
|---|---|---|
| بدء العملية البارد `am start -W` ×3 |1694/1462/1412ms|بدء Activity، لا اكتمال كل المحتوى ولا زمن هاتف|
| Home بعد8ثوانٍ في كل تشغيل |PSS142266/142005/142417KB|محاكيx86_64/API36.1،Urdu/light|
| المصحف المصور في الزيارة الأولى |PSS179182KB؛RSS335416KB|بعد مشي لغات/إعدادات؛ ليست دلتا تخص القارئ وحده|
| صورة الحديد541 بعد تشغيل جديد |PSS142146KB؛RSS303748KB|الصورة شوهدت؛ اختلاف اللقطتين لا يثبت تسربًا|
| مشغل فارس عباد وهوPLAYING |PSS147711KB؛RSS311776KB|APK الموقع؛ لا إثبات للسماع أو Dartheap profile|
| الصوت خلفHome/قفل/Doze |PLAYING بعدforce-idle10s؛ UI1:08 عند العودة؛ pause137717ms لاحقًا|اختبار قصير لمحاكي، لا قياس OEM/6ساعات|
| APK الأوديت |315956036B، نحو301.319MiB|ثلاثABIs مقصودة؛ لم نحذف معمارية|
| الملفات الأصلية للمعماريات |190797816B،60.39٪ منAPK|libapp/Flutter/ORT؛ ليس تلقائيًا تضخمًا قابلًا للحذف|
| Flutterassets المضغوطة |121147472B،38.34٪ منAPK|136004314B قبل الضغط،453entry|

ORT فيAPK كله1.28.2 للمعماريات الثلاث. بناء الأوديت بتوقيعGradledebug مقصود للفحص؛ توقيع الإنتاج خارجGradle. لم نختبر تثبيت ترقية جديدة فوق مفتاح الإنتاج.

قواعد البيانات الفعلية read-only: Quran5611520B،hadith109731840B،azkar188416B،sciences138215424B؛ quick_check=ok للأربع.67153حديثًا و45219مع درجة، وصفر graded/null-grader؛ وجود مؤسسة لا يساوي شخصًا وطبعة A-44.

| استعلام SQLite المضيف،30تشغيلًا دافئًا |median ms|p95 ms|
|---|---|---|
| صفحة564،19آية |2.957|3.269|
| البقرة286آية |4.649|5.492|
| آية4:115 |0.074|0.097|
| ترقيم الصوت حتى4:115 |2.856|3.107|
| أول2000حديث للبحث |19.035|22.737|
| آخر1153حديثًا |7.796|9.053|
| حديث عشوائي يومي |10.386|14.664|
| lookupحديث4:1 |0.065|0.103|

هذه SQL دون Dartnormalization/AndroidIPC/UI. لا نستنتج jank أو فهرسًا واجبًا منها وحدها. القرآنSCAN؛ lookupالحديث يستخدمidx_hadiths_book_num؛ ترتيب البقرة/العشوائية يستعملtempB-tree. ملف `db-census-query-timings.json` يحملEXPLAIN والأرقام الخام.

المثبت Flutter3.38.7/Dart3.10.7/AGP8.11.1/Kotlin2.2.20/Gradle8.14؛ البناء الحالي نجح. GitHub الرسمي يوم10أكتوبر: stableSHA`abaf9c523780a608bd46686fd5e53740a07077f8` يطابق تمامًا وسم3.47.7. `releases/latest` أعادprerelease قديمًا وstorageJSON أعاد404؛ لم نستخدمهما كشهادة للأحدث. الأدلة `flutter-live-stable.json` و`flutter-347-tags.json`. [Flutterarchive](https://docs.flutter.dev/install/archive)، [وسم3.47.7](https://github.com/flutter/flutter/tree/3.47.7).

كل أرقام Current/Upgradable/Resolvable/Latest في `flutter-outdated.log`. إبقاءpermission_handler12.0.3 سببه AGP9 الموثق TRAPS52؛ background_downloader9.5.9 مثبتoverride. major يحتاج موافقة، وتوافق أي ترقية لا يثبت إلا بالبناء والتثبيت والميزات على الجهاز. A-48 لا يدعي أن3.38.7 غير متوافقة أو أن3.47.7 آمنة للمشروع.

## الواجهة وإمكانية الوصول والأمان

Home شوهد باللغاتar/en/fr/es/pt/ru/ur وبخط2.0 فيUrdu وبثيمDark؛ ثم أعيدUrdu/light/font1.0 وأوقف التشغيل. لاoverflow ظاهر بهذه اللقطات، ولا يعني ذلك اختبار أعلى خط لكل شاشة.

ListenCard بعرض328 مع خطوط التطبيق والآية4:115 تجاوزت422–452px عندscale1 و990–1051px عندscale2. زرLTR خرج عن الحدود في5لغات بينماRTL بقي داخلها A-43. A-22 تباين فعلي: primarySoft/white3.28067:1، goldalpha لزرToolbar1.9078:1، SourceBlock2.1028:1. TabBar المكتبة لهoverride فاستبعد. A-23 زر القارئ22×26 وبلاlabel؛48dp توجيهAndroid، ولا ننسبه لـWCAG2.1 لكل زر.

قُرئت AndroidManifest والأذونات/exported والخدمات/cleartext والتوقيع، وschema.sql وكلquery والاعتماد والمدخلات/CORS ومسارات الأخطاء. النتائج ذات الأثر المثبت في الجدول. CORS* وحده لا يثبت فقدًا؛ A-03 هو الكتابة دونauth. بياناتprefs/SQLite داخل sandbox لا تعني تشفيرًا إضافيًا؛ لا ندعيKeystore لم ينفذه المصدر.

المسح التاريخي12357blob/1110382443B بقيم المفاتيح الحية وأنماطprivate-key/GitHub/AWS وجد28تطابقR2 المعروف؛ شهادةMiniflaredevTLS العامة استبعدت بعد فحص المصدر. ZIPentries فيAPK فُكت وفحصت بنفس القيم/الأنماط: صفر تطابق. لا ندعي اكتشاف كل سر أوbinary غير مدعوم. بصمات الأوديت ليست دليلًا أن كل مسار تنزيل داخل التطبيق يتحققSHA256.

## حدود الإثبات وما يحتاج المالك

| المتبقي | ما يلزم للتحقق |
|---|---|
| السماع والبوصلة والميكروفون الحقيقي |هاتفUSB/USBdebugging؛ تشغيل الأصوات ومقاطعة الأذان والبوصلة بالحركة والموقع؛ لا اختبار صوت بشري في الأوديت الحالي|
| أذان قبل أول فتحPIN |هاتف بقفلPIN وإعادة تشغيل A-12، وقفل/Doze طويل وإعدادات بطاريةOEM|
| توافقAndroid7 |تنزيل مصحف علىAPI24/25 A-13؛ المحاكيAPI36.1 لا يثبت ذلك|
| مزامنة حساب حي |حسابGoogle اختبار مصرح به للسحب/الرفع والتعارض/sign-in/logout A-04/A-19؛ لا حساب متاح|
| sherpa/التسميع/قارئ الكتب |لم نقس زمن تحميل النموذج وheap بعده أو دقة التعرف من ميكروفون حقيقي؛ PCM وتوفر ملفات النماذج لا يثبتان ذلك|
| profile وجمود الإطارات |لم يُشغّل profileAPK على الهاتف؛ وقتActivity/PSS لا يشهد بعدمjank|
| الإشعارات على يومين وتغييرTZ |IDs وإعادة التسليح وDST مثبتة مصدرًا/اختبارًا؛ ظهور وإلغاء كل تنبيه على الهاتف مطلوب بعد الإصلاح|
| موافقات المالك |تدويرR2 A-01؛ API/auth A-03؛ schema/migrations بحسب حلولA-04/A-06/A-12/A-40؛ الدينيA-44؛ majorوبناءrelease للتحققA-07/A-48؛ لا نشر أو حذفميزة/كتالوج أو تعديل نص ديني دون موافقة|

«محتاج تأكيد» يشمل توافقSDK الجديد والحساب الحي والقياس المغناطيسي ومرشحات غير مثبتة في المخارج/Shamela والتنزيل. لم تتحول إلىbugs بالتخمين. قيودImpeller/Avast وقراراتlandscape/ثلاثABIs والمصدر المؤسسي الموثق روعيت وفقTRAPS، دون أخطاء وهمية. ملاحظات التجارب والمراجعة التاريخية محفوظة في `interim-audit-notes.md` وTASK_FOLLOWUP.

## قائمة كل الملفات المقروءة

النطاق الأصلي563/563؛ كلentry source-reviewed وread_through_line حتى نهاية الملف. مراجعة البصمات عند التجميع أعادت صفر اختلاف. هذه قراءة مصدرية وليست تشغيلًا لكل ملف. أدوات الأوديت الإضافية لا تدخل حصرlib/Android/backend/build.

| # | الملف | السطور المقروءة | الحالة |
|---|---|---|---|
'''
for i, r in enumerate(review, 1):
    h += f"| {i} | `{r['path']}` | 1–{r['read_through_line']} | مقروء كاملًا |\n"
h += '\nملف إضافي قُرئ كاملًا عند تجديد الفحص: `scripts/build_prayer_method_fixtures.py`، ' + str(len(Path('scripts/build_prayer_method_fixtures.py').read_text(encoding='utf-8').splitlines())) + ' سطرًا؛ A-47.\n'
report.write_text(h, encoding='utf-8')
validation = dict(findings=len(rows), severity_counts=dict(counts), source_reviewed=len(review), source_lines=sum(r['lines'] for r in review), changed_review_sha=changed, application_changes=subprocess.check_output(['git', 'diff', '4a3f0b82', '--name-only', '--', 'rafeeq_app', 'sync_backend', 'scripts', '.github'], text=True).splitlines(), report_bytes=len(h.encode()), scope='Report assembly validation; runtime evidence and phone limits remain explicit.')
(ev / 'final-report-validation.json').write_text(json.dumps(validation, indent=2), encoding='utf-8')
print(json.dumps(validation))
