# Bundled databases

Two of the databases this app bundles are **not carried in git**. They are
build artifacts, not sources, and one of them made the repository
unpushable: GitHub hard-rejects any single file over 100 MB, and
`quran_sciences.db` is ~132 MB — every `git push` was refused by the server,
which is why 175 commits sat unpushed on `master` while the GitHub releases
carried only APKs. Both files were removed from the whole history and are
now gitignored, the same rule this repo already applies to
`scripts/book_text_build/` and the other regenerable pipeline output.

They are still bundled into the APK — see `pubspec.yaml`'s `assets:` list.
They just have to exist on the machine that builds it.

| File | Size | How to get it |
| --- | --- | --- |
| `quran_local.db` | 5.6 MB | **Committed** — small enough to live in git. Nothing to do. |
| `quran_sciences.db` | ~132 MB | `python scripts/build_sciences_db.py` — writes straight into this directory. Needs `scripts/temp_phase1/` (the raw pipeline input) present. |
| `hadith.db` | ~75 MB | `python scripts/build_hadith_db.py` — writes to `scripts/pipeline_zips/hadith.db`; copy it here. Or download the hosted copy: `https://pub-39dbef68a1a845d5ba669b43a59516b9.r2.dev/hadith/hadith.zip` (`AppConfig.hadithDbUrl`) and unzip `hadith.db` into this directory. |

A build with either file missing fails at asset resolution, loudly — it does
not silently ship an app with no hadith or no tafsir.
