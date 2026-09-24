# كمّل رفيق الدرب من حيث وقفنا

اقرأ بالترتيب: `CLAUDE.md` كاملًا، ثم `TASK_FOLLOWUP.md` (قسم «Next step»)، ثم `TRAPS.md` للمنطقة.
ردّ بالعربي. في أول رد: الكوتة حيّة (`get_usage`) + Remote Control (`ListAgents`).

## أين وقفنا بالضبط (2026-09-25 ~02:10 دبي)
`master` فيه أمرين من المالك، **الاثنين في الكود، وآخر إصلاح لم يُبنَ ولم يُرَ على جهاز:**

**A. التباين (نص غير واضح):** أداة قياس `scripts/contrast_scan.py` + زاحف شاشات `scripts/ui_crawl.py`.
دوال `readableOn` / `fillForWhiteText` / `goldText` في `core/theme/app_colors.dart`
(مختبرة: `test/contrast_helpers_test.dart`). طُبّقت على ~30 ملفًا (الذهبي المسطّح على سطح فاتح،
حبوب المسبحة، التاريخ في الرئيسية، تبويبات المكتبة، الشرائح الجانبية...).
**لم يُرَ على جهاز بعد.** أعد: ابنِ، ثم `py -3 scripts/ui_crawl.py %TEMP%\crawl light` (المحاكي
إنجليزي، فاتح)، ثم `py -3 scripts/contrast_scan.py %TEMP%\cscan %TEMP%\crawl\light_*.png`
وافحص كل علامة بالعين (حواف أيقونات كروت «المزيد» والستارة خلف الـ sheet إنذار كاذب).
ثم نفس الشيء داكن و RGB. الأهداف التي لم يصلها الزاحف: Categories/Audio/My library/Ibn Kathir،
مشغّل التلاوة، Theme — صلّح التسميات في `TARGETS`.

**B. الموقع اليدوي للصلاة:** الإعدادات ← الأذان ← «موقع الصلاة»
(`features/adhan/presentation/screens/prayer_location_screen.dart`): تلقائي / بحث بالاسم
(قائمة العالم أوفلاين أو جيوكودر الهاتف أونلاين) / إحداثيات. القائمة **مستضافة لا مضمّنة**
(طلب المالك: بلا زيادة حجم): GeoNames cities1000، 171,075 مكان، 5,080,747 بايت على R2
`geo/cities.tsv.gz` + مرآة GitHub `content-mirror` (الاثنان 206). البناء: `scripts/build_cities.py`.
`LocationService` يفضّل المكان اليدوي (`manual_location.dart`). GeoNames مذكور في المصادر.
- **رُئي على البناء 9:** الشاشة، البحث أونلاين «Tanta» → «Tanta Qism 2, Egypt».
- **فشل على البناء 9:** تنزيل القائمة وصل 46% ثم رجع «تنزيل» — السبب المرجّح: `Isolate.run`
  يرسل نطاق الإغلاق كله (فيه State الشاشة). **أُصلح في الكود ولم يُبنَ:** نُقل إلى دوال
  top-level (`_prepareOffThread` / `_searchOffThread` في `city_catalog.dart`). **لا تثق به
  قبل أن تراه.**

## الخطوة التالية بالضبط
1. `flutter analyze lib test` + `flutter test` (كان 582 ناجحًا قبل آخر تعديل).
2. أطفئ المحاكي (trap 24) ← `build_github_release.bat` ← شغّل المحاكي (بعد الإقلاع البارد:
   `accelerometer_rotation 0`) ← `adb install -r`.
3. الموقع اليدوي: نزّل القائمة حتى «جاهزة»، ثم وضع الطيران + GPS مطفأ، ابحث «Tanta» و«Dubai»
   (العربي لا يُكتب بـ adb — trap: انسخ/الصق)، اختر مدينة ← الرئيسية تعرض مواقيتها واسمها،
   القبلة تتغير. جرّب الإحداثيات، ثم الرجوع لـ«تلقائي». وقِس زمن البحث على الجهاز.
4. التباين: الزحف + القياس كما فوق، في الثيمات الثلاثة، وصلّح ما تبقى.
5. حدّث `HANDOVER.md`، بلّغ المالك. **لا تنشر 3.63.0 إلا لو طلب.**

## معلّق من قبل (لا يزال)
- موقع مقفول ← زر ← إعدادات ← تشغيل ← المواقيت: الخطوة الأخيرة لم تُرَ (GPS المحاكي لا يسلّم
  fix بعد `cmd location set-location-enabled`) — جرّبه على هاتف المالك.
