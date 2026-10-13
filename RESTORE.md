# الرجوع إلى نسخة تعمل

هذا الملف موجود لسبب واحد: **لو خرّب أي عميل (أو أنا) شيئًا، ترجع من هنا.**

النقطة الآمنة المعتمدة من 2026-10-13 هي **v3.87.0** (اختيار المالك: «سيب ٣.٨٧
وامسح ٣.٥١»). هي آخر إصدار قبل تعديلات الأوديت الكبيرة (3.88)، منشورة وموقّعة.

| | |
|---|---|
| الوسم | `v3.87.0` → الكوميت `6563e3e79660959c12cc453b4cdd63474dcefabf` |
| الـAPK | https://github.com/tito423/Rafeeq-Al-Darb/releases/tag/v3.87.0 (`RafeeqAlDarb-v3.87.0.apk`، 316,072,368 بايت) |
| Flutter المطلوب | 3.38.7 (محفوظ في `C:\Users\Asus\flutter`)؛ 3.88 وما بعدها على 3.47.7 |

نقطة الرجوع القديمة v3.51.0 حُذفت من GitHub بأمر المالك، ونسخة منها (مع فرع
`release-v1.2.0` القديم) محفوظة على اللابتوب في
`E:\My Projects\Rafeeq-Backups\release-v1.2.0-and-v3.51.0.bundle`
(`git clone <bundle>` يرجّعها).

---

## ١) ترجّع الكود

```bash
cd "E:\My Projects\Rafiq-Al-Darb"
git fetch origin --tags
git switch -c rescue-$(date +%Y%m%d) v3.87.0
```

## ٢) ترجّع التطبيق على الجهاز

نزّل الـAPK من صفحة الإصدار أعلاه. لو على الجهاز نسخة أحدث (3.88.x) يلزم حذف
التطبيق أولًا، لأن Android لا يقبل رقم إصدار أقدم فوق الأحدث (تضيع البيانات
المحلية غير المزامَنة):

```bash
adb uninstall com.tito.rafeeq_aldarb
adb install RafeeqAlDarb-v3.87.0.apk
```
