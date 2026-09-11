# البرومبت الجاهز للسيشن الجاية

اقرأ `CLAUDE.md` الأول (المنهج الملزم)، وبعده **`WORK_QUEUE.md`** (أول قسمين:
الدفعة السادسة E1–E8 والخامسة D1–D6)، وبعدها `HANDOVER.md`.

**قبل ما تخطّط: اسأله عن الكوتة (§2.0).** مقدرتش أقراها من الواجهة.

---

## الحالة عند التوقف

- المُصدَر: **v3.17.1** على `master`. أول حاجة:
  `gh release view v3.17.1 --json tagName,targetCommitish,assets` وتأكد إن SHA
  التاج = `git rev-parse HEAD` وإن فيه إصدار واحد بس.
- `flutter analyze lib test` نضيف · `flutter test` **١٧٦ ناجحة**.
- الـAPK متوقّع بـ`scripts/sign_release.py`.

---

## أول حاجة: اللي اتعمل وماحدش شافه — اعمله تاني

1. **إشعار الصلاة بعد إعادة تشغيل التليفون وعند وقت الصلاة (الترحيل).** اللي
   اتشاف: السحب بيرجّعه في ٤٦ مللي ثانية. الترحيل عن طريق `PrayerCardReceiver`
   (إنذار عند `when`) ماتجرّبش — استخدم `adb shell cmd alarm set-time` (فخ ٢٨).
   وإعادة التشغيل: `adb reboot` وبعدين `dumpsys notification` على id 6100.
2. **زرار الإصلاح على تحميل متعلّق فعلًا** — اتضغط والدنيا سليمة بس. اعمل
   تحميل تلاوة كاملة واقطع النت (`adb shell svc wifi disable`) دقيقتين ورجّعه
   واضغط إصلاح.
3. **شاشة التنزيلات وهي بتتحدث أثناء تحميل شغّال** — الكود موجود
   (`_StorageAutoRefresh`)، ماتراقبش.
4. **حرف القارئ في القوائم نازل تحت شوية** عن النص (ارتفاع خط AmiriQuran) —
   اتشاف ومااتصلحش.
5. **تحميل تلاوة كاملة لآخرها + الإيقاف والاستكمال + مؤقت الإيقاف + ملفات
   الجهاز** — من الدفعة اللي قبلها، لسه ماتجرّبوش.
6. **كل ده على تليفونه.**

---

## حاجات لازم تعرفها

- **التلاوة المستمرة للمصحف النصي بس.** السبب: تظليل مصحف التجويد في صفحة ٧٧
  نازل سطر (4:3). لو حد طلب يرجّعها للمصور، لازم الأول تتصلّح مطابقة
  الـpolygons لكل صفحة في `editions.json` وتتشاف على صفحات كتير.
- **السورة اللي بتتلى محمّلة كلها في المشغّل**؛ التنقل جوّاها `seek`
  (`AyahAudioService.startContinuous` أول سطور). ماترجعش لتحميل من الآية بس.
- **إشعار الصلاة Native** (`PrayerCard.kt`، قناة
  `com.tito.rafeeq_aldarb/prayer_card`). ماترجعش لـ`startForegroundService`
  بتاع flutter_local_notifications — مابيسمعش لما الإشعار يتشال.
- **الإيموليتر بـ`-no-snapshot-save` بيرجع لحالة 3.15.0 كل إقلاع** — أي
  تحميل أو إعداد عملته بيضيع. ده مش bug في التطبيق.
- مشغّل واحد بس في التطبيق (`AyahAudioService.player` / `claimForMusic`).

## ما تعملهاش تاني

- `flutter build apk --release` بيقتل الإيموليتر (فخ ٢٤).
- `Set-Content -Encoding utf8` في PowerShell 5.1 بيكتب BOM.
- heredoc في bash مع عربي وعلامات تنصيص بيفشل — اكتب السكربت بـWrite.
- `adb shell input text` مابيكتبش في حقول Flutter هنا.
- **`Positioned` جوّه `errorWidget`/`placeholder` بتاع صورة غلط** — مش جوّه Stack.
- بعد `flutter build apk --release` لازم `py -3 scripts/sign_release.py`.
