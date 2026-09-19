# Google Play listing kit — رفيق الدرب

Everything the Play Console asks for on the store-listing page, ready for the
day the app is published there. Prepared 2026-09-19 at the owner's request:
«جهّز صور لشاشات التطبيق وعليها نبذة عن كل شاشة … وحطه مع شرح التطبيق …
بحيث يبقى جاهز لما نيجي نعمل إصدار تاني ونرفعه على البلاي ستور».

| File | Play Console field | Spec |
|---|---|---|
| `listing_ar.md` | Arabic (primary) name, short and full description | 30 / 80 / 4000 characters |
| `listing_en.md` | English translation of the same | same limits |
| `screenshots/phone/01…08_*.png` | Phone screenshots | 8 images (Play's maximum), 1080×1920 PNG, 9:16 |
| `feature_graphic.png` | Feature graphic | 1024×500 PNG |
| `rafeeq_app/assets/icon/app_icon.png` | App icon | 1024×1024 — Play wants **512×512**, resize it on upload |
| `screenshots/raw/` | The untouched captures the screenshots are built from | 1080×2400, emulator-5554 |

## The eight screenshots, in upload order

1. **رفيقك في يومك** — Home: prayer times, Hijri date, next prayer.
2. **المصحف الشريف** — a Madinah mushaf page (image mode).
3. **الأذان في وقته** — the adhan screen.
4. **أذكار اليوم والليلة** — the adhkar grid.
5. **الكتب التسعة داخل التطبيق** — the nine hadith books.
6. **تعلّم التجويد من المتون** — a Jazariyya lesson with its listen button and the ayah example.
7. **مناسك الحج والعمرة** — the Hajj route and steps.
8. **كل ما تحتاجه في مكان واحد** — the «المزيد» cards.

Spare captures in `raw/` (prayer/qibla, tasbih, library authors, tajweed
levels) can replace any of these — edit `SHOTS` in the script.

## Rebuilding after the app changes

    py -3 scripts/build_store_screenshots.py

It frames `screenshots/raw/*.png` with the captions in `SHOTS` and renders
them through headless Chrome (this machine's Pillow cannot join Arabic
letters). To refresh a capture: put the emulator in demo mode for a clean
status bar —

    adb shell settings put global sysui_demo_allowed 1
    adb shell am broadcast -a com.android.systemui.demo -e command enter
    adb shell am broadcast -a com.android.systemui.demo -e command clock -e hhmm 0930
    adb shell am broadcast -a com.android.systemui.demo -e command notifications -e visible false

— then `adb exec-out screencap -p > store/google_play/screenshots/raw/<name>.png`,
and `-e command exit` afterwards.

## Before uploading — things that belong to the owner or to that day

* **The Play build carries no support link.** `AppConfig.supportUrl` is set
  only by `build_github_release.bat`; build the Play bundle
  (`flutter build appbundle --release`) **without** that define, as the owner
  asked. The listing says nothing about payments for the same reason.
* **Every number in the descriptions was measured on 2026-09-19** — 6 mushaf
  printings (`assets/data/mushaf/editions.json`), 45 translation languages
  (`quran_translations.json`), 67,153 hadiths (`hadith.db`), 213 library
  books and 83 readable aloud (`book_catalog.dart`), 7 interface languages,
  15 fonts. Re-check them if the content has changed since.
* The adhan screenshot shows the «معاينة» badge and a real clock that
  differs from the demo-mode status bar (9:30) — it is a genuine capture,
  left as it is.
* Play also asks for a privacy-policy URL (`AppConfig.privacyPolicyUrl`,
  source in `legal/privacy.html`) and the Data safety form
  (`legal/data_safety.md`); both already exist.
