# PLAN — رفيق الدرب (written 2026-09-24, the owner's order; work ONE stage at a time)

Rules for every stage: CLAUDE.md applies (verify on emulator-5554, 5 sources
for anything fetched — memory `five-backups-never-skip`, never skip an ayah,
analyze + test exit codes checked, commit + HANDOVER each step).

## Stage 1 — «التحميلات المبدئية» (NEXT, do first)
The screen after the permissions screen (today «اختر مصحفك» /
`lib/features/onboarding/presentation/screens/onboarding_screen.dart`).
1. Title «التحميلات المبدئية» + a short blurb: these downloads let the app
   work fully WITHOUT internet; recommend Wi-Fi.
2. FIX the jumping «علوم القرآن» row: the text/row height changes as the
   percentage changes (owner reported before, NOT fixed). Fixed-width digits,
   fixed height; verify with `adb shell screenrecord` + ffmpeg frames during a
   real download (a still screenshot does not show a jump).
3. Rows (each: what it is, exact size, download/cancel, progress):
   - المصحف الورقي (madinah_qc, 604 pages, 74.3 MB on R2)
   - علوم القرآن (33.2 MB)
   - تلاوة آية بآية: pick a reciter; offer the reciters whose hosts answered
     FASTEST (measure a range request per host at screen open); show the full
     size; RECOMMEND the smallest (R2 per-ayah folders: Maher 1,204 MB,
     Minshawi 1,657, Alafasy 1,707 — also measure the 64/32 kbps everyayah
     folders, e.g. Ibrahim_Akhdar_32kbps, as smaller options).
   - التلاوة الكاملة (whole surahs): recommend the smallest measured
     (basit_murattal 449 MB vs maher 709 MB on R2).
   - نموذج التسميع (whisper-tiny 77.7 MB)
   - صوت قارئ الكتب المحسّن (260.7 MB) — owner says he has a note about it; ask.
   - anything else needed offline (hadith.db is bundled; hadeethenc pack for
     the UI language; translations if not Arabic).
4. A total line: «المساحة المطلوبة للتجربة الكاملة: … MB» computed from the
   real sizes (from the catalogues / a HEAD, not typed by hand).
5. Verify on a FRESH install (`adb uninstall` then install) — an upgrade keeps
   onboarding done and hides the screen. Then release (bump pubspec +
   AboutScreen, build_github_release.bat, delete previous release+tag, keep
   v3.51.0 and the content-* prereleases).

## Stage 2 — finish the audit (docs/AUDIT_2026-09-24.md)
Easiest first: A1 accessibility labels; DB1 onUpgrade stubs; B2 verify the
Google ID token locally (JWKS, cached) in sync_backend; B3 rate limiting;
B4 review-site passphrase. OWNER: S1 rotate the R2 key; I1 custom domain.

## Stage 3 — Store builds and editions
Costs (checked on the web 2026-09-24):
- Google Play: US$25 one-time; a PERSONAL account must run a closed test
  with 12 testers for 14 days before production (organisation accounts are
  exempt); identity verification required.
- Apple App Store: US$99 per year.
- Microsoft Store: free registration (individuals and companies).
- Linux: Flathub / Snap — free.
Editions (one codebase, a build flag, e.g. `--dart-define=RAFEEQ_EDITION=github|play`):
- GitHub edition: everything, full library (as today).
- Play edition: NO full-text books whose redistribution rights are not
  clearly ours to grant (CONTENT-LICENSES.md decides); the library becomes
  quoted excerpts with source + link, or is removed. Support button must use
  Google Play Billing (donations/tips policy) — decide with the owner.
  Also: target API, Data safety form, privacy policy URL (exists on R2),
  exact-alarm permission justification (adhan), foreground-service types.
- Apple / Windows / Linux: later stage. iOS needs a Mac for builds (or a CI
  service), APNs for notifications, and reviews the same rights questions.

## Stage 4 — Tarteel-level tasmee (hardest; in sub-stages)
Do not state what Tarteel does without checking its current app first.
4a. DONE 2026-09-24 (scripts/measure_asr_tiny_vs_base.py, result in
    scripts/asr_tiny_vs_base_2026-09-24.txt): same whisper.cpp engine, 500
    words / 4 reciters / 661 s of audio. tiny 446/500 matched (89.2%), base
    446/500 (89.2%) - identical; exact 407 vs 409; base 3.2x slower (0.636 vs
    0.198 s per audio second) and 1.9x the size. Base does NOT win -> tiny
    stays. (The R2 "base" is ONNX for another engine; its ggml build is local
    only.) Both models are weaker on Alafasy (85%) and Minshawi (80%) than
    on Husary (98%) - a limit of the model family, noted for 4b.
4b. Live mode: transcribe 2–3 s windows while reciting; highlight the word on
    the mushaf page as it is said; stop at a missed/wrong word.
4c. Mistake history per ayah feeding «حفظي»'s review schedule.
4d. «من الذاكرة» mode: page hidden, words revealed as said correctly.
Tajweed judgement: parked by the owner; no free model judges it.

## Optional (not decided) — per-ABI APKs BESIDE the universal one
The universal APK stays (owner's rule: every Android 7+ phone, every ABI).
Publishing arm64-only / armv7-only builds next to it would shrink the
download; measure the real sizes first — no figure is claimed here.

## Standing owner actions
- Rotate the R2 API key (it is in public git history).
- Buy a domain when ready → R2 custom domain + Cache Rule (steps in the
  v3.60.0 report / AUDIT I1).
