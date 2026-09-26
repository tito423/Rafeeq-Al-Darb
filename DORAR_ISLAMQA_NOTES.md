# Dorar (الدرر السنية) and IslamQA (الإسلام سؤال وجواب) - what the app can do

Measured live from this PC, 2026-09-26 ~19:00 Dubai.

## dorar.net
- **Public JSON hadith API**: `GET https://dorar.net/dorar_api.json?skey=<words>`
  -> 200 `application/json`, `{"ahadith":{"result":"<html>"}}`. Each result
  carries: the hadith text, الراوي, **المحدث (the grader, by name)**, المصدر,
  الصفحة أو الرقم, خلاصة حكم المحدث. Sample: «إنما الأعمال» returned
  12,249 B, first hit graded by الدارقطني in علل الدارقطني 2269.
- Web search page `https://dorar.net/hadith/search?q=` (HTML, 614 KB).
- robots.txt: `Disallow:` empty (everything allowed).
- Fits the project rule «grade must come with a named grader» exactly.

## islamqa.info
- Answers are server-rendered HTML: `https://islamqa.info/ar/answers/<n>`.
- No public API (`/api/` = 404). No `__NEXT_DATA__` JSON in the page.
- robots.txt allows all but `/_next/`; **sitemap index** lists 39 sitemaps
  (`/sitemaps/ar/answers/1..`, articles, books, researches) - a full,
  official list of every answer URL.
- Footer: «جميع الحقوق محفوظة لموقع الإسلام سؤال وجواب 1997-2025 ©».

## What that allows (proposal)
1. Dorar: **live تخريج inside the app** - long-press a hadith (library,
   daily hadith, adhkar) or type one -> Dorar's API -> list of gradings, each
   with the grader's name and source. Live query, no copying of their DB.
2. IslamQA: **search + read answers live** (the sitemap gives the answer list;
   each answer fetched and shown on demand, credited, with a link back).
   Not a bulk import: the site is «جميع الحقوق محفوظة».
3. Both: GitHub build only, like the Shamela import.
