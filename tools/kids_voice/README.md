# kids_voice — how the kids-corner stories are voiced

A copy of the working folder `E:/DevEnv/kids_voice` (the scripts and each
story's `lines.tsv` + `moods.json`), kept here so the pipeline can be read
and rerun from GitHub. The audio itself (3.7 GB of WAV takes) stays on the
PC; the finished videos are on R2 and the content-mirror release.

Order for one story (run inside `E:/DevEnv/kids_voice/<id>/`; the scripts use
the absolute paths of that machine):
1. `py -3 ../gen_multi.py b1.wav 1 2 3 4` - Gemini TTS, up to 4 lines a request
   (`gemini_tts.py` reads `GEMINI_API_KEY` from the gitignored `scripts/.env`).
2. `py -3 ../split_batches.py b1=1,2,3,4 ...` (or `split_ui.py`, tolerant of
   glued words) - one clean `nNN.wav` per line.
3. `py -3 ../new/word_audit.py <id>` - a word missing in BOTH FastConformer and
   Whisper is flagged.
4. `py -3 ../mk_rec.py <id>=S:A` - the Minshawi ayah, ASR-checked.
5. `py -3 ../mix_story.py <scenes> <rec scene> rec.wav <id> <ambience per scene>`,
   then `py -3 ../words_json.py`.
6. Copy `timing2.json` / `words.json` into the `kids-stories-pipeline` branch's
   `kids_stories/<id>/` and `node render.mjs <id> --audio ... --out <id>/out/<id>_v1.mp4`.
7. `py -3 scripts/build_kids_stories.py --upload`, then
   `py -3 scripts/github_content_mirror.py --only content-mirror`.
