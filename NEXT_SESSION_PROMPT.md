# Rafiq Al-Darb — next session brief

**Last written:** 2026-09-17, at the owner's «جهّز الدنيا», on a clean tree.

**Verified at this handover, not remembered:**

* `flutter analyze lib test` → **No issues found** (22.9 s)
* `flutter test` → **282 passed**
* **all 257** catalogued book paths answered a range request on the bucket —
  0 failures, the whole catalogue and not a sample
* one page of **each of the 6** mushaf printings → HTTP 206 with the right
  `Content-Type` (`image/svg+xml` for `hafs_kfqc`, `image/jpeg` for the five
  raster printings)
* `hadith/hadith.zip` → 206 `application/zip`; `quran/translations/en.json.gz`
  and `ur.json.gz` → 206
* `gh release view v3.30.0` → target `master`, asset
  `rafeeq-aldarb-3.30.0.apk` **212,462,925 bytes**; the tag's SHA
  `c0a08fd033b26d5c85c063303320d5ec322cd757` **equals** `git rev-parse HEAD`
* `apksigner verify --min-sdk-version 28` on the published bytes →
  `CN=Rafeeq Al-Darb, OU=Personal, O=tito423, L=Cairo, C=EG`

**Measured at this handover:** 7 locales × **1,479** keys · **257** catalogue entries =
**254** distinct books (see item 1) in **8** categories · **6** mushaf printings × 604 pages · `hadith.db`
109,731,840 bytes / **67,153** hadiths / **45,219** graded, each with a named
grader · **58** quotes × 7 languages · Hijri on-this-day **358 days / 5,747
events**, Gregorian **366 days** × 6 languages.

---

## Where the last session stopped

`v3.30.0` — "the translation release" — was published and reported, and the
reply ended by putting **one decision** to the owner and waiting for it. No
code work was started after that, deliberately.

## 1. Three books are in the library TWICE — found at the handover, not fixed

The handover sweep range-requested all 257 catalogued book paths and every one
answered; counting what came back showed that **three books are catalogued
twice**, under two ids each, pointing at two separate uploads of the same
Shamela book. Proven by fetching both copies and comparing page by page:

| book | ids | Shamela id | pages identical |
|---|---|---|---|
| «الأذكار» للنووي | `al_adhkar_lil_nawawi`, `al_adhkar_nawawi` | 1956 | **411 / 411** |
| «الأربعون النووية» | `al_arbaun_al_nawawiyyah`, `al_arbaun_an_nawawiyyah` | 12836 | **81 / 81** |
| «التبيان في آداب حملة القرآن» | `al_tibyan_fi_adab_hamalat_al_quran`, `at_tibyan_hamalat_al_quran` | 1969 | **224 / 224** |

The real book count is **254**, not 257. Worse than the duplication: the two
«الأذكار» entries **disagree about their own edition** — `al_adhkar_nawawi`
names تحقيق شعيب الأرنؤوط (d. 2016) and the file's internal id is
`aladhkar_llnwwy_t_alarnwwt`, while `al_adhkar_lil_nawawi`, the same 411 pages,
names only دار الفكر and no muhaqqiq. One label is wrong about a book whose
apparatus is still in copyright, and both ship.

**Do:** read both `sourceLabel`s against Shamela 1956 itself, keep the honest
one, delete the other entry, delete its object from R2, and **write a test**
that fails when two catalogue entries share a title+author or a Shamela id —
this is the «catalogue nobody opened» failure (trap #36) in a new form and
nothing in the suite noticed it.

Three further pairs share a title and author but are genuinely different
printings — `tahqiq_riyad_al_salihin_lil_albani`, `tahqiq_al_iman`,
`takhrij_al_kalim_al_tayyib`, all المكتب الإسلامي, i.e. al-Albani's editions —
whose **ids name a muhaqqiq their `sourceLabel` does not**. Read them before
deleting anything; they may be a labelling fix, or they may be three more books
that the v3.29.0 purge should have taken.

## 2. The decision — the azkar corpus

**Ask him, then act on the answer. Do not start before he answers.**

The azkar feature is built on **«حصن المسلم» لسعيد بن علي بن وهف القحطاني**
(d. 1439 AH / 2018). This is measured, not inferred: in
`rafeeq_app/assets/data/quran_sciences.db`, `azkar_items` row 2's footnote
reads «الؤلف: سعيد بن علي بن وهف القحطاني» (the typo is the source's) and row
1's reads «حرر في شهر صفر 1409هـ». The tables hold **134 sections and 298
items**.

The duas themselves are prophetic and free. What is his is **the selection,
the arrangement, the 134 chapter titles and the takhrij** — exactly the thing
23 books were removed from the library for in v3.29.0.

**The replacement is already in the library** — «الأذكار» للنووي (d. 676 AH),
with «الكلم الطيب» لابن تيمية and «عمل اليوم والليلة» لابن السني beside it.
**But it is in there twice** (item 1), and the copy whose label is honest about
the printing has to be settled BEFORE anything is cut out of it — the edition
Shamela 1956 actually is, is al-Arna'ut's, whose apparatus is in copyright, so
what the azkar are rebuilt from is an-Nawawi's own matn and not his notes.

If he says go:

1. Read real pages of «الأذكار» before writing any cutter (§1.4). It is
   arranged by باب like حصن المسلم but not in the same order, and it carries
   isnads that حصن المسلم does not — those need the §1.2 treatment, not a
   filter that silently drops them.
2. Keep every dua's **text** verbatim. Never normalise scripture-adjacent
   text (§1.2).
3. Rebuild `azkar_sections` / `azkar_items` in `quran_sciences.db` from it,
   and keep the ids stable enough that `azkarItemsByIds` (used by the
   Hisn-al-Muslim cross-section lists in `sciences_repository.dart:162`)
   still resolves — read that comment before touching the schema.
4. **Then** translate the new section titles into all 7 locales.

If he says leave it: say plainly in `HANDOVER.md` that the app ships a
copyrighted selection knowingly, so the record is honest.

## 3. The azkar screens show raw Arabic titles in every language

This is a live instance of his standing rule and it is **not fixed**:

* `rafeeq_app/lib/features/azkar/presentation/screens/azkar_screen.dart:307`
  → `Text(s.title, …)`
* `rafeeq_app/lib/features/azkar/presentation/screens/azkar_section_screen.dart:112`
  → `Text(widget.section.title)`

Both render the database's Arabic title directly, so an English/French/Russian
reader gets an Arabic list and an Arabic app bar. Fixing it means 134
translated titles — which is why it is tied to item 2 and should not be done
first: if the book changes, the titles change.

## 4. What has never been seen on hardware — redo it, do not trust it

**Nothing since v3.25.0 has run on the owner's phone.** Five releases:
v3.26.0, v3.27.0, v3.28.0, v3.29.0, v3.30.0.

And **no in-app download has ever been watched succeed on this machine.**
Avast's Web Shield re-signs TLS with a root that lives in the Windows store
and never in the emulator's, so every hosted download inside the app fails on
`emulator-5554` with `CERTIFICATE_VERIFY_FAILED` and the screen reads exactly
like a broken feature (CLAUDE.md trap #13). These three were proven present on
the bucket by a range request and then **pushed into the sandbox by hand**
through `run-as` so the screen could be seen — which is the bytes being there,
not the download working:

* the first-run **`hadith.db`** download (~16 MB zip; it left the APK in
  v3.27.0, so a fresh install now depends on it)
* the four **history books**, above all `al_bidaya_wan_nihaya` (5.0 MB gzip)
* **`al_idah_fi_manasik_al_hajj_wal_umrah`**, which the whole Hajj guide reads

**On a real phone: install v3.30.0, then download each of those three and
watch it finish and open.** Report what actually happened.

Also unheard on any device: the **splash sound** (off by default).

## 5. Smaller, open

* `AppConfig.donationUrl` is empty, so the donate button hides itself rather
  than being a dead control (trap #27). It appears the day he supplies a URL.
* **«رجال حول الرسول» is deliberately absent** although he asked for it by
  name: خالد محمد خالد died in 1996, so it is protected until 2046 under the
  author-death + 50 rule this project works to. It was **removed** by the
  v3.29.0 purge. Do not re-add it; if he asks again, say why.

---

## The rules this session must not relearn

* **`CLAUDE.md` is mandatory.** Read it before touching anything. Trap #47 is
  the newest and cost two whole tajweed levels.
* **Check the quota live in the first reply** (§2.0), and say whether Remote
  Control is on (§2.0b — `ListAgents`; it can only be switched on when a
  session *starts*, with `claude rc`).
* **Reply in Egyptian Arabic.** Code, comments and commit messages in English.
* **«اعلى معايير الجودة والكفاءة والمنطقية والدقة والموضوعية والاحترافية» is a
  standing rule**, not a one-off — prefer a smaller verified deliverable to a
  larger unverified one.
* **Checkpoint with `.\cp.bat "what you just did"`**, constantly.
* **One release at a time**: delete the previous release *and its tag* before
  publishing, tag from `master`, bump `pubspec.yaml` **and**
  `AboutScreen.appVersion` together, and sign with
  `scripts/sign_release.py` — which must print `OK: rotated` (trap #41).
* **Do not write a next-session prompt** unless he says «جهّز الدنيا» (§7).
