# ترتيب التطبيق — سجل الشغل

> «نظم الكود، الشاشات، الباك اند، الفرونت اند، العمليات، الميثود كولينج…
> خليه سلس وسهل في الصيانة ميبقاش معقد ومكلكع.»

## ما هو الوضع فعلاً — مقاس، مش مفترض

`201` ملف دارت، `55,148` سطر.

**الطبقات سليمة أصلاً.** عشرين feature من اتنين وعشرين عندهم `data/` و
`presentation/` مفصولين. مفيش «باك اند متلخبط في فرونت اند» على مستوى البنية.

**الفوضى الحقيقية في أربع حاجات:**

### ١. ملفات عملاقة فيها شاشات كاملة مكدّسة

| الملف | سطور | كلاسات في ملف واحد |
|---|---|---|
| `library/presentation/screens/library_screen.dart` | 1,625 | **25** |
| `quran/presentation/screens/quran_screen.dart` | 1,700 | 11 (منهم State بـ1,170 سطر) |
| `quran/presentation/widgets/ayah_sciences_sheet.dart` | 1,543 | **20** |
| `library/presentation/screens/book_text_reader_screen.dart` | 1,156 | — |
| `quran/presentation/widgets/mushaf_text_page.dart` | 991 | — |
| `quran_audio/presentation/player_screen.dart` | 949 | — |
| `downloads/presentation/screens/downloads_screen.dart` | 870 | — |
| `khatma/presentation/khatma_screen.dart` | 859 | — |
| `adhan/presentation/screens/adhan_settings_screen.dart` | 855 | — |

`library_screen.dart` لوحده فيه **خمس تبويبات** بكل شاشاتها الفرعية **وكتالوج
مواقع** — كله في ملف واحد.

### ٢. بيانات ساكنة جوّه ملفات الشاشات

تسع حالات كتالوج/ليستة بيانات متكتوبة جوّه ملف `presentation`. دي اللي خلّت
ليستة القنوات تتكرر مرتين، وواحدة منهم متشافش في التطبيق أصلاً.

### ٣. قنوات النظام (method channels) متناثرة

تمن قنوات، خمسة منهم متعرّفين **جوّه دالة واحدة** طولها ٣٠٠ سطر في
`MainActivity.configureFlutterEngine`.

### ٤. ملف ميت

`quran/presentation/widgets/mushaf_page_thumbnail.dart` — محدش بيستورده.

---

## الخطة

كل مرحلة بتنتهي على: `analyze` نضيف + الاختبارات خضرا + **اتشغّل على الجهاز**
+ commit. ومفيش مرحلة بتغيّر سلوك — ده ترتيب، مش إعادة كتابة.

- [ ] **١. `library_screen.dart`** → تبويب لكل ملف + الكتالوج لـ`data/`
- [ ] **٢. `ayah_sciences_sheet.dart`** → هيدر / لوحة الآية / تبويباتها / حوارات
- [ ] **٣. `quran_screen.dart`** → الويدجتس تطلع برّه
- [ ] **٤. البيانات تطلع من `presentation` في الأماكن التسعة**
- [ ] **٥. قنوات النظام** → مُسجِّل لكل اهتمام بدل دالة واحدة
- [ ] **٦. اختبار حارس** — سقف لطول الملف، ومنع البيانات في `presentation`
