# Shamela import inside the app (GitHub build only)

Owner, 2026-09-26: «عاوز تدمج في التطبيق آلية تتعامل مع موقع الشاملة ونقدر
نبحث باسم كتاب وندمجه في تطبيقنا … الجزء ده بالذات في تطبيقنا احنا بس مش
البلاي ستور». Search Shamela by book title from inside the app, and import the
chosen book into the library, readable offline like any other.

## Measured live (2026-09-26, from this PC)

| What | Endpoint | Result |
|---|---|---|
| Whole book catalogue | `GET https://shamela.ws/ajax/books/` (the site's own select2 autocomplete; the `q` parameter is IGNORED) | JSON `{"results":{"items":[{"id","text"}...]}}` - **8,599 books**, ids 1..151203, 1,679,477 B raw, **195,186 B gzip** |
| Whole author list | `GET https://shamela.ws/ajax/authors/` | 3,191 authors, 344,128 B raw |
| One page of a book | `GET https://shamela.ws/ajax/pageContent/{book}/{page}` with `X-Requested-With: XMLHttpRequest` | JSON with `nass` = the page's HTML (the pipeline's `fetch_shamela_pages.py` has used this for months) |
| Book card + TOC | `GET https://shamela.ws/book/{id}` (HTML) | title, author (link `/author/{id}`), publisher, edition, parts, «[ترقيم الكتاب موافق للمطبوع]», TOC headings |
| Reader page | `GET https://shamela.ws/book/{id}/1` | TOC links carry page ids; e.g. صيد الخاطر (12028) max linked page 893 |
| Page number -> id | `GET https://shamela.ws/ajax/pagenum2id/{book}/{part}/{page}` | from custom.js |
| Sub-TOC | `GET https://shamela.ws/ajax/titlechilds/{book}/{id}` | from custom.js |

Samples found in the catalogue: صيد الخاطر = 12028, الفقه المنهجي = 6369.
Shamela's own `/search` searches INSIDE books, not titles (trap #17) - the
catalogue list above is the title search.

## Shamela's official MCP service (found 2026-09-26)

`POST https://mcp.shamela.ws` (JSON-RPC, MCP protocol 2025-06-18; `GET`
answers `{"error":"method_not_allowed"}`; `https://shamela.ws/mcp` is a 404
for POST). Terms: https://shamela.ws/page/terms («شروط استخدام خدمة الشاملة
MCP», updated 19 Sep 2026) - read-only; allowed: search, reading, lawful
documentation; forbidden: getting around request limits, rebuilding the whole
index, harming availability; rights stay with the rights holders.
Four tools: `shamela_find` (2-6 query variants, whole library),
`shamela_find_scoped` (book_ids / book_names / author / category / pages,
field body|footnotes|both), `shamela_open` (one page, max 16,000 chars,
citable=false), `shamela_open_many` (up to 8 pages, 64,000 chars).

Use: it is for bounded reading, so it is NOT the import path (a whole book
through it is what the terms forbid). It IS the right engine for a later
feature: «ابحث في الشاملة كلها» - full-text search across the whole library
from inside the app, results opened page by page. Stage E below.

## Design

1. **Catalogue on the phone.** Download `ajax/books/` once (195 KB gzip),
   cache it with its date, refresh weekly or on pull. Search it locally with
   the app's own Arabic matching (`normalizeArabic`, `nameMatchesExact`
   first, then starts-of-words) - instant, offline, and better than the
   site's. A book already in our catalogue shows «موجود في المكتبة» instead
   of an import button.
2. **Book card before import.** Tap a result -> fetch `/book/{id}`: title,
   author, publisher, parts, page count. The owner's standing exclusion
   (memory `library-content-policy-2026-09-22`): the named five
   (ابن باز، ابن عثيمين، ابن جبرين، ابن عبد الوهاب، الألباني) are not
   offered.
3. **Import.** Find the last page (binary search on `pageContent`, as the
   pipeline does), fetch pages with a small worker pool (the pipeline's 12 is
   for a PC; the phone uses ~4, polite and battery-kind), parse each `nass`
   with a Dart port of `scripts/build_book_text.py:parse_nass` (paragraphs
   `{t, k: body|aya|ref|head}`), write the app's book JSON
   `{meta:{titleAr, authorAr, pageCount, source:"shamela:{id}"}, pages:[{p, paras}]}`
   and hand it to `LibraryApiService.installBookBytes` - the reader, search
   and «مكتبتي» then treat it like any other book. Resumable: pages are kept
   as they arrive; a killed app continues where it stopped. Progress in the
   Downloads panel and a notification (same pattern as the ayah downloads).
4. **Imported books registry.** A local table of imported ids + metadata so
   they appear in the library (a «من الشاملة» shelf) and can be deleted.
5. **GitHub build only.** Behind a `--dart-define` set by
   `build_github_release.bat` (like the support link); a build without it has
   no Shamela screen at all.
6. **Credit.** Sources screen: «المكتبة الشاملة - shamela.ws» with the link.

## Stages

A. Catalogue service + search screen (Dart, tests on a saved copy of the
   real list). B. Book card + page fetch + `parse_nass` port, verified
   against the pipeline's output for 2 books (byte-compare the paragraphs).
C. Import flow + registry + library shelf + progress/notification.
D. dart-define gate, Sources credit, device verification (phone + TV).
E. (after A-D) Full-text search across all of Shamela through its official
   MCP service, results opened with `shamela_open`, within its limits.

## Open, to verify before relying on it
- Shamela's terms page (`/page/terms`) - read before shipping (the owner has
  ruled Shamela text is fine for his personal build).
- Rate limits: none seen at 12 workers from the PC pipeline; the phone uses
  fewer.
