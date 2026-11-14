# الرجوع إلى نسخة تعمل

هذا الملف موجود لسبب واحد: **لو خرّب أي عميل (أو أنا) شيئًا، ترجع من هنا.**

النقطة الآمنة المعتمدة من 2026-11-14 هي **v5.0.0** (أمر المالك: «امسح وامسح
اللي كنا حطينه احتياطي وسمي ده 5.0.0 وثبته بعد كدة نقطة رجوع»). فيها التسميع
بنموذج quran-asr-small، منشورة وموقّعة، ولا تُحذف مع الإصدارات القادمة.

| | |
|---|---|
| الوسم | `v5.0.0` → الكوميت `30cbea3280b38b37bde2efac724af2c160423676` |
| الـAPK | https://github.com/tito423/Rafeeq-Al-Darb/releases/tag/v5.0.0 (`RafeeqAlDarb-v5.0.0.apk`، 318,252,939 بايت، sha256 `48ab6f9e…7e3e5a44`) |
| Flutter المطلوب | 3.47.7 (`E:\DevEnv\flutter-3.47.7`) |

نقطة الرجوع السابقة v3.87.0 حُذفت من GitHub بأمر المالك (2026-11-14). كودها
باقٍ في تاريخ master (الكوميت `6563e3e79660959c12cc453b4cdd63474dcefabf`)،
والـAPK محفوظ على اللابتوب في
`E:\My Projects\Rafeeq-Backups\RafeeqAlDarb-v3.87.0.apk` (316,072,368 بايت)،
ويحتاج Flutter 3.38.7 (`C:\Users\Asus\flutter`) لو اتبنى من جديد.
والأقدم v3.51.0 محفوظة في
`E:\My Projects\Rafeeq-Backups\release-v1.2.0-and-v3.51.0.bundle`
(`git clone <bundle>` يرجّعها).

---

## ١) ترجّع الكود

```bash
cd "E:\My Projects\Rafiq-Al-Darb"
git fetch origin --tags
git switch -c rescue-$(date +%Y%m%d) v5.0.0
```

## ٢) ترجّع التطبيق على الجهاز

نزّل الـAPK من صفحة الإصدار أعلاه. لو على الجهاز نسخة أحدث من 5.0.0 يلزم حذف
التطبيق أولًا، لأن Android لا يقبل رقم إصدار أقدم فوق الأحدث (تضيع البيانات
المحلية غير المزامَنة):

```bash
adb uninstall com.tito.rafeeq_aldarb
adb install RafeeqAlDarb-v5.0.0.apk
```
