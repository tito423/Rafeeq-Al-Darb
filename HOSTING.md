# HOSTING.md — Rafiq Al-Darb content & data hosting plan

**Written 2026-09-03, P2‑9.** This is the plan the owner acts on — an agent
session cannot log into Cloudflare, Firebase, or GitHub console UIs to
provision anything. What this document *does* cover: exactly what exists
today, exactly what to provision, and confirmation that the client is
already wired to plug into it without code changes once it exists.

**Direct answer to the owner's question (2026‑09‑03):** yes — Cloudflare
for static content, Firebase Firestore (free Spark plan, never Blaze) for
any real dynamic/shared data — is the right split, and it's exactly what
this file below formalizes. Nothing about that needs correcting.

---

## 1. Two different jobs, two different services — don't blur them

| | **Static content** (a file every user downloads as-is) | **Dynamic/shared data** (state that changes, is written by users, or must sync across devices) |
|---|---|---|
| Examples in this app | mushaf page SVGs, `hadith.zip`, book PDFs/text JSONs, adhan video clips, translations (bundled in `quran_sciences.db`) | *(none yet)* — the only realistic near-term case is a future **group khatma** (P2‑8 #12, research done, not built — needs the owner's own go-ahead on accounts first) |
| Right service | **Cloudflare R2** (object storage) — free egress, the entire reason to use R2 over S3-alikes for a content-heavy app | **Firebase Firestore**, Spark (**free**) plan only |
| Why not the other way round | Firestore document reads/writes are billed per-operation past the free daily quota — wrong shape for "everyone downloads the same 20 MB file"; R2 has no query/realtime-sync model — wrong shape for "many small documents that change" | |

Today, **100% of what Rafiq hosts is static content.** There is no dynamic
data yet, and none should be added speculatively — Firestore stays
unprovisioned/unused until a real feature (like group khatma, if the owner
approves it) actually needs it. This is the same "don't build ahead of
need" rule as everywhere else in this project, just applied to
infrastructure instead of features.

---

## 2. What exists right now, and where

| Content | Size | Currently hosted at | Status |
|---|---|---|---|
| Mushaf page SVGs (5 editions: Hafs/Shubah/Warsh/Qalun/Duri) | ~24 MB total (brotli), pinned commit `b91d39e1…` | `raw.githubusercontent.com/quranpedia/quran-svg` (upstream repo, not ours) | Fine as-is — it's someone else's CC0 repo, pinned so it can never drift; **not** something to mirror unless upstream disappears |
| `hadith.zip` (9 books, ~41k hadiths) | ~17 MB | **Cloudflare R2, `rafeeq-content` bucket** (`hadith/hadith.zip`) | ✅ **migrated 2026‑09‑03** |
| Book text editions (5 books, Shamela-sourced JSON) | ~5.6 MB total | **R2** `rafeeq-content/books/text/*.json` | ✅ **migrated 2026‑09‑03** |
| Adhan video clips (5 Pixabay clips) | ~15.5 MB total | **R2** `rafeeq-content/adhan/video/*.mp4` | ✅ **migrated 2026‑09‑03** |
| Book image PDFs (5 books) | ~3–20 MB each | `archive.org` (their own hosting, external) | Fine as-is — not ours to move |
| Quran translations (en/fr/ur/es/ru/pt), tafsir, i'rab, word meanings | inside `quran_sciences.db`, 26.1 MB | **bundled in the APK**, not downloaded | Not a hosting concern — ships with the app itself |
| Mushaf audio (per-ayah recitation) | streamed per-ayah, cached on device | `cdn.islamic.network` / `everyayah.com` (external CDNs) | Fine as-is — not ours to host |

**The R2 migration (2026‑09‑03):** owner provisioned a Cloudflare account
and handed over an R2 API token (S3-compatible access key/secret + a
Cloudflare API token) directly in chat. Stored immediately in
`scripts/.env` (gitignored, never committed, never echoed back) — see §7 for
the full record of this and why it should still be rotated.

- Created a fresh bucket, **`rafeeq-content`** (the old `rafeeq-aldarb-data`
  bucket already existed from before this session but turned out to be
  contaminated — see §7, do not reuse it).
- Enabled the bucket's public **r2.dev** managed domain via the Cloudflare
  API (`PUT /accounts/{id}/r2/buckets/{bucket}/domains/managed`,
  `{"enabled": true}`): `https://pub-39dbef68a1a845d5ba669b43a59516b9.r2.dev`.
- Migrated the exact 11 files the app actually reads (same relative paths:
  `hadith/hadith.zip`, `books/text/*.json` ×5, `adhan/video/*.mp4` ×5) from
  `tito423/rafeeq-api` GitHub raw into the bucket — each verified byte-size
  match via S3 `head_object` **and** a live `curl -I` against the public
  r2.dev URL (200, correct `Content-Length`/`Content-Type`).
- `AppConfig.contentBaseUrl`'s default now points at the R2 public URL
  (previously GitHub raw); the `RAFEEQ_CONTENT_BASE` `--dart-define` override
  seam is unchanged, so nothing else in the client needed to change.
  `flutter analyze` clean after the edit.
- **Deliberately not migrated:** the rest of `tito423/rafeeq-api`
  (raw per-book hadith JSON — pipeline source files, not what the app
  downloads; `downloads/adhans/*.mp3` — superseded, the 10 real adhans now
  ship as bundled assets; `mushaf/*.png`, 1.57 GB, 11,760 files — the
  abandoned PNG mushaf design already flagged as dead in §6 below). None of
  it is referenced by `AppConfig`. It costs nothing sitting in a GitHub repo
  (unlike R2, GitHub doesn't bill by storage/egress for a normal repo this
  size), so it was left alone rather than acted on unilaterally — flagged
  for the owner as a repo-cleanup candidate, not urgent.

**GitHub raw is no longer the production content host** — the point of this
migration is exactly the risk §5.5 already named (no CDN, no bandwidth SLA).

---

## 3. What to provision (owner-only — console access)

1. **Create a Cloudflare R2 bucket** (e.g. `rafeeq-content`). Free tier: 10 GB
   storage, 10 M Class-A + 1 M Class-B operations/month, **zero egress
   fees** — the entire ~38 MB this project hosts today fits with enormous
   headroom, and stays free even at real scale because there's no
   per-download bandwidth charge (that's the whole point of R2 over S3).
2. **Copy `tito423/rafeeq-api`'s current contents into that bucket**, same
   folder layout (`hadith/hadith.zip`, `books/text/*.json`,
   `adhan/video/*.mp4`) — a same-shape move, not a redesign.
3. **Issue a new R2 API token, scoped to that one bucket, read-only if
   possible.** ⚠️ **Rotate the old one first** — a prior R2 Secret Access
   Key was pasted into a chat transcript and must be treated as
   compromised (HANDOVER §9, still open). Cloudflare dashboard → R2 →
   Manage R2 API Tokens → delete the old `rafeeq-aldarb-data` token →
   create a new one. The new token's secret **never goes in the client** —
   R2 buckets can be made public-read for exactly this kind of content, so
   the app only ever needs a plain public URL, never a credential.
4. **Ship a build with the new base URL:**
   ```
   flutter build apk --release --dart-define=RAFEEQ_CONTENT_BASE=https://<bucket-public-url>
   ```
   No code change needed for this step — `AppConfig.contentBaseUrl` already
   reads this exact `--dart-define` (confirmed in the source, §4 below).
5. **Leave Firebase exactly as it is** (see §4) — nothing to provision there
   until a real feature needs it.

---

## 4. Client wiring — already done, verified by reading the actual code

`lib/core/config/app_config.dart` already has both override seams the P2‑9
acceptance criteria asked for:

```dart
static const String mushafBase = String.fromEnvironment(
  'RAFEEQ_MUSHAF_BASE',
  defaultValue: 'https://raw.githubusercontent.com/quranpedia/quran-svg/…',
);
static const String contentBaseUrl = String.fromEnvironment(
  'RAFEEQ_CONTENT_BASE',
  defaultValue: 'https://raw.githubusercontent.com/tito423/rafeeq-api/master',
);
```

Both are secret-free (`AppConfig`'s own doc comment: "No credentials live
in the client — the old build embedded Cloudflare R2 keys — removed for
good"), and both already default to today's working GitHub-raw URLs, so a
build with **no** `--dart-define` still works exactly as it does now — the
R2 migration is additive, never a breaking change. **No client code needs
to change for §3's migration** — only the build command gains one
`--dart-define` flag once the bucket exists.

### The Firebase project — exists, unused, correctly free-tier-safe

- **`rafeeq-aldarb`** (project number `201578300543`) already exists,
  already linked to the owner's Google account, already has
  `google-services.json` wired to package `com.tito.rafeeq_aldarb` — set up
  during STAGE 7 in anticipation of Google Sign-In, which was never built.
- **Confirmed by grep, 2026‑09‑03: zero Firebase packages in `pubspec.yaml`**
  (`firebase_core`, `cloud_firestore`, etc. — none present). The project
  exists at the console level; nothing in the app talks to it yet.
- `google-services.json` is real (contains a live API key + a default
  Storage bucket address) but is correctly **gitignored**, confirmed not
  tracked in git history from this point forward (`.gitignore` line 59).
- **This is the correct state to be in.** Adding `firebase_core` +
  `cloud_firestore` now, with no feature using them, would violate "keep
  the install light" (HANDOVER §3/P2‑5) for zero benefit — Flutter/Firebase
  SDKs are not free weight. **Wire it up when a real feature needs it**
  (the clearest candidate: group khatma, P2‑8 #12 — researched, not
  approved to build yet). When that day comes: reuse this same project (no
  new Firebase project needed), enable Firestore in **Spark (free) mode**,
  and design the data model to stay inside 1 GiB storage / 50k reads /
  20k writes-or-deletes per day — comfortably enough for small,
  infrequently-updated documents (a khatma group's member list and
  progress, not a chat log or anything write-heavy). **Never enable the
  Blaze plan** — Blaze itself is usage-based billing tied to a card; Spark
  has no path to an unexpected charge because operations simply stop
  succeeding past the free quota instead of billing further, which is the
  behaviour this project wants.

---

## 5. Answering the scale question directly

> "عايز دايمًا البيانات تبقى متاحة لاحتمال إن التطبيق يكبر بعدد المستخدمين"
> — I always want the data to stay available in case the app grows in users.

Both halves of this plan scale the *right* way for that, for different
reasons:

- **R2's free egress** means serving the mushaf/hadith/book/adhan content to
  10 people or 10 million costs the same **$0** for bandwidth — the only
  thing that could ever cost money is *storage* past 10 GB, and this
  project's entire current footprint is ~38 MB, roughly 0.4% of that free
  ceiling. There's no scenario in this app's current shape where content
  hosting becomes a paid line item.
- **Firestore Spark's free quota resets daily** and simply serves nothing
  further once exhausted rather than silently billing the owner — safe by
  construction. If a genuinely popular shared-data feature someday
  outgrows 50k reads/day, that's a real, deliberate decision to make then
  (upgrade to Blaze with a budget cap, or re-architect), not something that
  can happen by accident on the free plan.

**Bottom line: nothing in this plan can cost money without the owner
explicitly opting into Blaze later** — which is exactly the guardrail
PHASE2.md's original P2‑9 spec asked for.

---

## 7. The R2 credential handoff, and a contaminated old bucket found along the way (2026‑09‑03)

**How the credentials arrived.** The owner pasted a Cloudflare R2 API token
(Cloudflare API token + S3-compatible access key/secret pair) directly into
the chat with the agent, in response to being asked to provision R2 access
per §3. This is the **second time** this exact thing has happened on this
project — §3 already carries a scar from the first one ("a prior R2 Secret
Access Key was pasted into a chat transcript and must be treated as
compromised"). What was done with it this time: written straight to
`scripts/.env` (already `.gitignore`d via the `.env`/`.env.*` rule, confirmed
with `git check-ignore` before any other action), never echoed back in any
message or committed anywhere. **Recommendation, unresolved:** rotate this
token too once the owner is done with any further R2 admin work this
session — pasting a live secret into any chat transcript should be treated
as exposure regardless of how carefully the receiving side handles it
afterward, the same standard §3 already states.

**The old bucket, `rafeeq-aldarb-data`, is contaminated — do not reuse it.**
Listing it (before creating `rafeeq-content`) turned up, among other things:
`mushaf_medina1.zip`, `mushaf_medina2.zip`, `mushaf_shamarly.zip`,
`mushaf_tahajod.zip`, `mushaf_naskh_taleek.zip`, `mushaf_urdu12/13/15.zip` —
**these are the exact QuranFlash internal edition names §5.1 (this
project's own hard rule 2) already identified and purged from the codebase
once.** Their presence in this bucket means they were re-introduced at some
point by a session this HANDOVER's history doesn't otherwise document, sitting
unused in cloud storage rather than in the app — still a rule‑2 violation to
leave in place. Alongside them: a 2.6 GB `tafsir.zip`, a 2.9 GB `audio.zip`, ~20 more
multi-hundred-MB `mushaf_*.zip` files (the same abandoned PNG-mushaf design
flagged in §2's own table), and — the actual bulk of the object count — a
3.8 GB `tafsir/` prefix that is almost certainly an **entire git
repository's `.git/objects` tree uploaded object-by-object** (hundreds of
thousands of small loose-object blobs, not real content files). **Full
inventory, paginated to completion:**

```
TOTAL_COUNT: 254,971 objects
TOTAL_SIZE:  11,442,728,193 bytes  =  10.66 GB
```

**This is already past the R2 free tier's 10 GB storage ceiling** — this
bucket, alone, may already be an active line item on the Cloudflare account,
or will become one the moment a payment method is attached for any reason.
Nothing in `AppConfig` or any script in this repo references
`rafeeq-aldarb-data` — it is not serving the app anything today, just
sitting there accruing storage.

**Not deleted without asking.** Deleting real cloud storage is exactly the
kind of hard-to-reverse action this project's own working style (checkpoint,
verify, don't act past what's confirmed) says to surface rather than assume.
Left the bucket as-is; the owner should decide directly — deleting the whole
bucket is the straightforward recommendation, since nothing in it is used —
and can do it from the Cloudflare dashboard or ask the agent to do it via the
same R2 API once confirmed. **Check the Cloudflare billing/usage page now,
independent of the cleanup decision** — 10.66 GB stored is a real number
worth confirming isn't already generating a charge.

## 8. Acceptance checklist

- [x] `HOSTING.md` exists (this file).
- [x] `AppConfig` re-confirmed secret-free (read directly, §4).
- [x] Both override seams (`RAFEEQ_MUSHAF_BASE`, `RAFEEQ_CONTENT_BASE`)
      already present — no client code change needed for the R2 migration.
- [x] Firebase project state confirmed by direct inspection: real project,
      correctly unused, correctly gitignored, correctly zero-SDK-weight
      until a feature needs it.
- [x] **R2 bucket created (`rafeeq-content`), the app's real ~38 MB migrated,
      public r2.dev domain enabled, `AppConfig.contentBaseUrl` repointed at
      it.** (2026‑09‑03 — §2, §7.) **Still open:** rotate the token that was
      pasted into chat to provision this (§7); decide the old contaminated
      `rafeeq-aldarb-data` bucket's fate (§7).
- [ ] **Owner:** decide whether/when to approve a Firestore-backed feature
      (e.g. group khatma) — a design/scope decision, not a hosting one.
