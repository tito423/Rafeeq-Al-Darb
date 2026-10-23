# seerat_ibn_hisham — full text, vowelled

Replaces the old copy (Shamela 7450, Taha Abd al-Ra'uf Sa'd), which held only
the first two of four volumes and was 55% vowelled — below the 80% the book
reader needs before it offers the voice (`book_speaker.dart`).

**Source.** OpenITI `0213IbnHisham.SiraNabawiyya.Shamela0023833-ara1`
(github.com/OpenITI/0225AH, `data/0213IbnHisham/`): Shamela 23833, al-Saqqa /
al-Abyari / al-Shalabi, al-Halabi 2nd ed. 1375/1955, complete in 2 volumes.
OpenITI already removed the editors' introduction, footnotes and indices.
The text there has no vowels at all.

**Vowels.**
1. `diacritize.py` — every word through CATT encoder-decoder
   (github.com/abjadai/catt, release v2 ONNX, `pip download catt-tashkeel`).
   Writes a resumable cache `segment -> vowelled`.
2. `build_book.py` — puts the vowels back on the original text (punctuation
   and page markers untouched), then finds runs of 5+ words that match the
   mushaf (`rafeeq_app/assets/data/quran_local.db`). Those runs become `aya`
   paragraphs, so the voice skips them like every other quoted ayah. They take
   the mushaf's vowels where the book's letters line up with it, and stay bare
   where they do not. The book's letters are never changed.
   Writes the gzipped book JSON (schema 1) and a report.

```
CATT_PKG=<dir with catt_tashkeel> python3 diacritize.py <openiti file> cache.jsonl
python3 build_book.py <openiti file> cache.jsonl quran_local.db seerat_ibn_hisham.json report.json
```

**Known limits.** The vowels are a model's, not an editor's: right on
common words, weaker on rare names and on poetry. Quoted ayahs shorter
than 5 words are not detected, so they get the model's vowels.
