# برومبت الجلسة الجاية — رفيق الدرب (Rafiq Al-Darb)

انسخ ده كله وابعته للـ agent اللي هيكمّل.

---

مشروع **Rafiq Al-Darb** — تطبيق إسلامي Flutter في `E:\My Projects\Rafiq-Al-Darb`.
متفترضش أي حاجة عن الحالة من الرسالة دي — استنتج كل حاجة من الريبو.

## ORIENT الأول (من PowerShell/cmd، مش Git Bash)

```
git -C "E:\My Projects\Rafiq-Al-Darb" log --oneline -25
git -C "E:\My Projects\Rafiq-Al-Darb" status --short
.\cp.bat /s
```

بعدين اقرأ كامل بالترتيب:

1. **PHASE2.md** — البرومبت الأساسي. جدول المراحل فوق + قسم لكل مرحلة.
   المراحل ✅ عليها بلوك "DONE" بيوصف اللي اتعمل فعلاً؛ P2‑7 عليها بلوك
   "WIP" بحالة الوقوف بالظبط.
2. **HANDOVER.md** — بلوك "Current work in progress" فوق (resume here)،
   جدول "PHASE 2 progress"، §3 قواعد ملزمة، §5 قرارات ممنوع تلغيها
   (§5.7 = نص الكتب من الشاملة)، §7 تحقق + آخر التحديثات، §11 أخطاء
   اتعملت قبل كده (اقراها قبل ما تكتب كود).
3. **WORK_QUEUE.md · RAFEEQ_PIPELINE.md** — سجل المرحلة 1 (T1–T20، كلها ✅).

## الحالة (اتأكد من git)

- **Phase 1 (T1–T20)** ✅ خلصت ومتحققة على المحاكي.
- **P2‑1 / P2‑2 / P2‑3 / P2‑4 (structural)** ✅ خلصوا ومتحققين.
- **P2‑4b** ✅ نسخة نصية لكل كتاب من المكتبة الشاملة (5 كتب) — مرفوعة على
  `tito423/rafeeq-api/books/text/*.json`، `book_text_reader_screen.dart`،
  مفتاح `مصوّر | نص` في كل كارت. `printReliable` بيتحكّم في عرض أرقام
  الصفحات (false لرياض الصالحين/كتاب 12014 لأن ترقيمه في الشاملة مش مرتّب).
- **P2‑5** ✅ مدير تحميل موحّد: تبويب "نظرة عامة" (إجمالي التخزين + تفريغ لكل
  قسم + قائمة العناصر المنزَّلة)، `downloads_controller.dart` (aggregator)،
  **إشعار تقدّم حي لكل نوع تحميل** (اتعمّم `DownloadNotifications` واتوصّل
  في `MushafPageService.prefetchEdition` + `AyahAudioService.downloadSurah`)،
  **إيقاف/استئناف** للمصاحف والتلاوات. متبقّي بسيط: 3 تبويبات مش 5 أقسام.
- **P2‑6** ✅ إشعار الصلاة الثابت: `prayer_status_notification.dart` — بطاقة
  status دائمة (الصلاة القادمة + الساعة + عدّاد تنازلي native chronometer
  بيشتغل حتى والتطبيق مقفول + التاريخ الهجري من `times.hijriDate` بتاع
  AlAdhan)، مفتاح opt‑in في إعدادات الأذان (افتراضي off)، مزامنة من
  `AppShell`. متحقق على المحاكي.
- **P2‑7** 🔶 **نص الوقوف — كمّل من هنا** (تحت).

## P2‑7 — أذان صوت/فيديو (نص الوقوف بالظبط)

**قرار الأونر (2026‑09‑02):** مفيش يوتيوب/محتوى محمي. فيديو **مرخّص حر بس**.
اتجاب **5 مقاطع من Pixabay** (رخصة Pixabay — استخدام تجاري حر بلا نسب)،
مخزّنين محلياً في `scripts/adhan_video_build/` (مضاف لـ .gitignore):
`haram_makkah.mp4` (2.3MB) · `kaaba.mp4` (4.0MB) · `madina_nabawi.mp4` (5.5MB)
· `mosque_prayer.mp4` (1.0MB) · `mosque_ottoman.mp4` (1.7MB).

### اللي اتعمل

- `pubspec.yaml` — أضيف `video_player: ^2.9.2` (`pub get` تمام).
- `lib/features/adhan/data/adhan_video_catalog.dart` — `AdhanVideoOption`
  (id/nameAr/nameEn/approxSizeBytes) + `adhanVideoCatalog` (الـ5) +
  `adhanVideoSourceLabel` + `adhanVideoById()`. الـ`url` =
  `${AppConfig.contentBaseUrl}/adhan/video/<id>.mp4`.
- `lib/features/adhan/data/adhan_presentation_provider.dart` —
  `enum AdhanPresentation {audioOnly, video}`، `AdhanPresentationState
  {mode, videoId}`، provider persisted (`adhan_presentation_v1` /
  `adhan_video_id_v1`)، افتراضي audioOnly + أول مقطع.
- `scripts/upload_adhan_videos.py` — رفع الـ5 على
  `rafeeq-api/adhan/video/<name>.mp4` عبر `gh api --input` (زي
  `upload_book_text.py`). **لسه ماترفعش** — الـ classifier حجب أمر الرفع؛
  محتاج تأكيد الأونر أو تشغيله يدوي: `python scripts/upload_adhan_videos.py`.
- `adhan_catalog_service.dart` — سقف 30 أذان (`maxTotalAdhans`) +
  `AdhanLimitReached` exception؛ `adhan_settings_screen._pickCustomAdhan`
  بيمسك الـ exception ويعرض `prayer.adhan_limit_reached` (المفتاح لسه
  محتاج يتضاف ×5).
- **ملاحظة:** `assets/data/catalogs/adhans.json` نضيف (مفيش mojibake — اتصلّح
  في STAGE 1)؛ `adhan_text.dart` كامل (كل السطور + التثويب للفجر) — مش
  محتاجين تعديل.

### اللي لسه (كمّل)

1. **ارفع الـ5 فيديوهات** على rafeeq-api (اسأل الأونر أو شغّل السكربت).
   اتأكد كل URL يرجّع 200 + `video/mp4` + الحجم المظبوط.
2. **`AdhanFullScreenScreen`** — أضيف param اختياري `String? videoPath`. لو
   موجود → اعرض `VideoPlayer` (muted + looped) كخلفية بدل التدرّج المتحرّك،
   مع scrim غامق تحت النص عشان يفضل مقروء. كل منطق الكاريوكي (`_lineStarts`,
   `_activeLine`, ticker) زي ما هو. لو الفيديو مش منزّل → رجوع تلقائي
   للتدرّج (أمين).
3. **الـ payload** — `buildAdhanPayload` + `AdhanPayload` ياخدوا `video`
   (مسار الملف المحلي)؛ `adhan_navigation.dart` يمرّره لـ `AdhanFullScreenScreen`.
4. **`adhan_scheduler.dart`** — `rescheduleAdhans` + `fireAdhanTest` ياخدوا
   `String? adhanVideoPath` (المتصل بيحلّه من الـ provider + سجلّ
   `DownloadManager` لو `presentation==video` والملف منزّل). حطّه في الـ payload.
   المتصلين: `PrayerController._reschedule` و `adhan_settings_screen._test`.
5. **`adhan_settings_screen.dart`** — فوق قسم "الأذان الافتراضي": `SegmentedButton`
   **صوت | فيديو**؛ لما فيديو → صفّ الـ5 مقاطع (تنزيل/اختيار كل واحد عبر
   `DownloadManager` category `adhan_video`، سطر تقدّم زي كروت الكتب) + سطر
   المصدر `adhanVideoSourceLabel` + **ملاحظة أمينة**: «الفيديو يظهر والشاشة
   مفتوحة فقط؛ عند إغلاق التطبيق يُشغَّل صوت الأذان فقط (قيد Android).»
6. **مفاتيح ترجمة ×5** (parity test بيمسك): `prayer.adhan_limit_reached`،
   `prayer.presentation` / `.audio` / `.video`، `prayer.adhan_video` /
   `.video_note` / `.download_video` / `.video_source`، أي مفاتيح تانية
   للـUI. حدّث parity في HANDOVER §3 لو الرقم اتغيّر (كان 278).
7. **تحقّق على `emulator-5554`:** اختَر فيديو → ينزّل مرة واحدة → «تجربة»
   للظهر → الشاشة الكاملة تعرض الفيديو الصامت وراء النص الكاريوكي المتزامن
   مع صوت الأذان المختار؛ صوت‑فقط يفضل زي ما هو؛ استيراد أذان لحد 30
   والـ31 يترفض برسالة واضحة؛ الاختيار يفضل بعد إعادة تشغيل التطبيق.
   (المحاكي بطيء + مساحته بتخلص — `adb shell pm clear com.tito.rafeeq_aldarb`
   + `pm trim-caches` لو `INSTALL_FAILED_INSUFFICIENT_STORAGE`.)

**بعدها:** P2‑8 (مزيج ميزات المنافسين — check‑in) → P2‑9 (HOSTING.md —
OWNER‑BLOCKER كونسول) → P2‑10 (خفّة/أمان/إصدار — OWNER‑BLOCKER keystore) →
P2‑11/12/13 (إعادة تصميم الرئيسية: كارت ختمة / كارت سنن السور / كارت حديث
عشوائي — P2‑13 محتاج داتاست حديث مُدرَّج، Option A).

## قواعد ملزمة

- صفر mock/placeholder. مفيش داتا → empty state أمين.
- ممنوع أي حاجة من QuranFlash (أفكار UX بس).
- متقولش "متحقق" إلا لو شغّلته على جهاز، وقول شغّلت إيه ومشغّلتش إيه.
- Offline‑first. ممنوع أسرار في git. parity المفاتيح عبر الـ5 لغات
  (`flutter test` بيمسكها).
- **ممنوع سحب فيديو/صوت من يوتيوب أو أي تطبيق** — مصادر مرخّصة حرة بس
  (Pixabay/Pexels/CC0)، وسجّل المصدر ظاهر في الواجهة.
- الأونر بيتعلم برمجة وهيدرس الكود — كود نضيف موثَّق على نمط الملفات المجاورة.

## Checkpoint

بعد كل تعديل مهم: `.\cp.bat "اللي عملته"` · خلاص مرحلة: `.\cp.bat "..." -Done`
لو الكوتة قربت تخلص: قف واصرف آخر لفّات على تحديث HANDOVER.md + PHASE2.md
بحالة الوقوف بالظبط والخطوة الجاية. متسبش ملف نصّه مكتوب ومش بيكومبايل من
غير ملاحظة صريحة.

## التحقق

`emulator-5554` غالباً شغّال (بطيء). package = `com.tito.rafeeq_aldarb`.
`.\check.bat` = pub get + analyze. كل التحقق لحد دلوقتي على محاكي — لسه
محتاج تشغيلة على موبايل Android حقيقي قبل ما Phase 2 يتقفل.
`gh` مسجَّل دخول كـ `tito423` (scope repo) — الرفع على `tito423/rafeeq-api`
شغّال (books/text + adhan/video).
