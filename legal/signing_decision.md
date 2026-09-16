# Signing: what to do if the app goes to Google Play

**Asked for:** «قرر انت الصح في موضوع التوقيع وراجع نفسك كويس جدا قبل ما تاخد قرار».
This is the decision, the reasoning, and — explicitly — the parts I could not
verify from here.

## The recommendation, in one line

**Go to Play with your own key: choose "use an existing app signing key" when
you create the app in Play Console and upload the key from `../Rafeeq-Keys/`.
Keep publishing the same APK on GitHub, signed the same way.** Then a phone
does not care which of the two it installed from — except on Android 7–8, and
that exception is spelled out below.

## Why this is the question at all

An Android update is only allowed when the new package is signed by the same
certificate as the installed one. If Play signs your app with a key Google
generated, a phone that installed the GitHub APK cannot take a Play update, and
a phone that installed from Play cannot take a GitHub one. The refusal looks
like «التطبيق غير متوافق» and the only way through it is uninstall — which for
this app destroys the hundreds of megabytes the reader has downloaded.

Play App Signing is **not optional** for a new app. But it does not force a new
key: when the app is created you may upload the key you already have, and
Google then signs releases with **that** key. That is the whole trick.

## The complication that is specific to this app

`scripts/sign_release.py` does not sign with one key. It signs with a
**SigningCertificateLineage** (APK Signature Scheme v3, trap #41):

| Android | Certificate the device sees |
|---|---|
| 9 and up (API 28+) | `CN=Rafeeq Al-Darb, OU=Personal, O=tito423, L=Cairo, C=EG` |
| 7–8 (API 24–27) | `C=US, O=Android, CN=Android Debug` |

That is deliberate and it is what lets today's builds install over the old
debug-signed ones without an uninstall. It also means **"the app's key" is two
keys**, and which one a device considers authoritative depends on its Android
version.

So, uploading the release key to Play:

* **Android 9 and up — clean.** The installed GitHub build presents the release
  certificate through v3, a Play build signed with the same key presents the
  same certificate, and the update is allowed in both directions.
* **Android 7–8 — not clean.** Those devices never read v3. They see the
  *debug* certificate on the GitHub build. A Play build signed with the release
  key alone would not match, and the update would be refused on exactly the
  oldest phones this app went out of its way to support.

## What follows

1. **Upload the release key to Play** (Play Console → your app → Test and
   release → App integrity → App signing key → "Use an existing app signing
   key"). Google keeps a copy; if that is unacceptable to you, the only other
   honest option is to stay on GitHub, because a Google-generated key splits
   the two channels permanently.
2. **Treat Play as the channel for new installs**, and keep the GitHub release
   going for the people already on it. They are not stranded: on Android 9+
   they can move to Play whenever they like and the install carries over.
3. **Android 7–8 users who installed from GitHub will need one uninstall** to
   move to Play. Tell them rather than let them meet it as an error — and note
   that their downloaded content goes with it. If you would rather nobody ever
   hit that, keep Android 7–8 on the GitHub channel.
4. **Do not stop rotating on the GitHub channel.** The lineage is what keeps
   the update path open for everyone already installed. Nothing about Play
   changes that.
5. **If Play ever generates a key for you by mistake**, stop before the first
   release. After a release, changing the app signing key is a request to
   Google (key upgrade), it takes effect only for API 28+, and it leaves the
   same Android 7–8 split you were trying to avoid.

## What I could not check from here, and you should

* The exact wording and placement of the "use an existing app signing key"
  option changes with Play Console's UI. I am describing the mechanism, not a
  screenshot I took today.
* **Whether Play will accept a key that carries a lineage.** Google's tooling
  wants a single signing key (a PEPK export or a `.pem` produced by their
  encryption tool). My expectation is that you upload the *release* key and the
  lineage simply stops applying to Play-signed builds — which is precisely why
  Android 7–8 is the affected group above — but confirm it in the console
  before you commit, because everything downstream depends on it.
* Play's current download-size ceiling. It has moved (100 → 150 → 200 MB for
  the download generated from a bundle) and it is checked against the
  **per-device** download, not the universal APK.

## The size question, measured today

The universal release APK is **205.4 MB** after `hadith.db` came out of the
bundle. That is not the number Play would see, because an App Bundle ships one
ABI per device. Read from the APK itself:

| Inside the APK | Compressed |
|---|---|
| `assets/` (Flutter) | 95.4 MB |
| native libs, all three ABIs | 68.0 MB — of which **~25 MB reaches any one phone** |
| adhan audio under `res/` | 34.9 MB |

* An App Bundle therefore drops roughly **43 MB** on its own.
* **The adhan audio is in the APK twice.** All 12 files are byte-identical
  between `res/*.mp3` (the native alarm's copy) and
  `assets/flutter_assets/assets/audio/adhan/*` (Flutter's), verified by CRC —
  **34.9 MB duplicated in every install**. Removing one copy is a real piece of
  work (the native alarm plays from `res/raw`, Flutter from its own assets)
  but it is the single biggest saving left.
* `assets/data/quran_sciences.db` is another **32.6 MB**, and it is a
  candidate for the same treatment `hadith.db` just had.

Together those three get a per-device download close to **95 MB**, which is
comfortably inside any of Play's ceilings.
