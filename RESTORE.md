# الرجوع إلى نسخة تعمل

هذا الملف موجود لسبب واحد: **لو خرّب أي عميل (أو أنا) شيئًا، ترجع من هنا.**

النقطة الآمنة المعتمدة هي **v3.51.0** — آخر إصدار بُني ووُقّع ورُكّب وفُتح على
جهاز بلا انهيار، بتاريخ 2026-09-21.

| | |
|---|---|
| الوسم | `v3.51.0` |
| الفرع الثابت | `known-good/v3.51.0` — **لا يُحرّك ولا يُحذف** |
| الوسم الاحتياطي | `backup-2026-09-21c` — نفس الكوميت، اسم يسهل تذكّره |
| الـAPK | `dist/RafeeqAlDarb-v3.51.0.apk` وعلى GitHub Releases |

---

## ١) ترجّع الكود كله

```bash
cd "E:\My Projects\Rafiq-Al-Darb"
git fetch --all --tags
git switch -c rescue-$(date +%Y%m%d) known-good/v3.51.0
```

فرع جديد من النقطة الآمنة، **بلا مسح أي شيء**. راجعه، وإن أردته هو الأساس:

```bash
git switch master
git reset --hard known-good/v3.51.0
git push --force-with-lease origin master
```

> `--force-with-lease` لا `--force`: يرفض الدفع لو أحد غيّر الفرع بعدك.

## ٢) ترجّع التطبيق على التليفون

```bash
adb install -r "E:\My Projects\Rafiq-Al-Darb\dist\RafeeqAlDarb-v3.51.0.apk"
```

`-r` تحديث فوق المثبّت، فلا يضيع ما نزّلته. والتوقيع يحمل السلسلة (lineage)
فيُقبل التثبيت فوق أي إصدار سابق دون إلغاء التثبيت.

أو نزّله من:
https://github.com/tito423/Rafeeq-Al-Darb/releases/tag/v3.51.0

## ٣) نسخة كاملة خارج GitHub

لو المستودع نفسه خرب أو ضاع الوصول إليه، هناك حزمة git تحمل **كل التاريخ**
وكل الفروع والوسوم في ملف واحد، خارج المستودع:

    ../Rafeeq-Backups/Rafeeq-Al-Darb-2026-09-21.bundle      (661 ميجابايت)

تحقّق منها ثم استنسخ منها:

```bash
git bundle verify "E:\My Projects\Rafeeq-Backups\Rafeeq-Al-Darb-2026-09-21.bundle"
git clone "E:\My Projects\Rafeeq-Backups\Rafeeq-Al-Darb-2026-09-21.bundle" Rafeeq-Al-Darb-restored
```

تخرج نسخة كاملة تعمل، بكل الفروع والوسوم، دون شبكة. **انسخ هذا الملف على
قرص خارجي** — هو والمفتاح، فهما الشيئان اللذان لا يعوّضهما شيء.

## ٤) ما لا يُغطّيه هذا

* **مفتاح التوقيع** في `../Rafeeq-Keys/` **خارج المستودع**، وهو مسؤوليتك أنت.
  لو ضاع فلن يُثبَّت أي تحديث فوق التطبيق بعد اليوم إلا بإلغاء تثبيته — وهذا
  يمحو مئات الميجابايت من المحتوى المنزَّل. **خذ نسخة منه الآن.**
* **محتوى R2** (`rafeeq-content`) ليس في git. الحالة وقتها: **909** كائنًا،
  **860.61** ميجابايت. وقائمة ما حُذف يوم 2026-09-20 في
  `docs/r2/deleted_2026-09-20.txt`.
* **قواعد البيانات المولَّدة** (`rafeeq_app/assets/data/*.db`) مستثناة من git
  لأنها تُبنى من `scripts/`.

## ٥) كيف تعرف أنك رجعت صح

```bash
cd rafeeq_app
flutter analyze lib test     # No issues found
flutter test                 # 453 passed, 2 skipped
```

ثم `grep "^version:" rafeeq_app/pubspec.yaml` ← `3.51.0+53`.
