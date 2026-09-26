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

## Dorar in depth (measured 2026-09-26 ~19:30)

Sections on dorar.net's home page (each a path): `hadith`, `aqeeda`
(الموسوعة العقدية), `feqhia` (الموسوعة الفقهية), `qfiqhia` (القواعد الفقهية),
`osolfeqh`, `tafseer`, `history`, `adyan`, `frq` (الفرق), `alakhlaq`,
`aadab`, `arabia`, `azkar`, `fake-hadith` (الأحاديث المنتشرة التي لا تصح),
`article`, `gsearch` (search across all), `refs/<section>` (each
encyclopedia's bibliography).

- **Only `dorar_api.json` (hadith) is JSON.** The encyclopedias are HTML.
- **Each encyclopedia's front page holds its whole table of contents:**
  `/aqeeda` -> 1,469 section links `/aqeeda/N`; `/feqhia` -> 5,419 links
  `/feqhia/N` (counted from the HTML: 532,971 B and 1,878,474 B).
- A section page, e.g. `/aqeeda/10` (175,373 B): title «الفَرْعُ الثَّاني:
  تعريفُ العَقيدةِ اصطِلاحًا - الموسوعة العقدية - الدرر السنية»; content in
  `amiri_custom_content` cards.
- Footer on every page: «جميع الحقوق محفوظة لمؤسسة الدرر السنية 1421-1448 هـ».

## Design: «الدرر السنية» hub (GitHub build only)
1. Hub screen listing the encyclopedias (aqeeda, feqhia, qfiqhia, osolfeqh,
   tafseer, history, adyan, frq, akhlaq, aadab, arabia, azkar, fake-hadith)
   + hadith grading (done in code: DorarScreen).
2. Each encyclopedia: its TOC read live from its front page (tree), a
   section opens in an in-app reader (text parsed from the section page),
   credited with a link back. Read on demand; a section read is cached for
   offline re-reading (like a browser cache) - no bulk copy of the site,
   because «جميع الحقوق محفوظة».
3. `gsearch` for search across Dorar; `fake-hadith` as its own entry
   (checks a widespread saying).
4. Before building each parser: fetch 3+ real section pages and read them
   (CLAUDE.md §1.4); verify against pages read by hand.
