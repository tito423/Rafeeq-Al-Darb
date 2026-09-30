# Kids stories - narration pipeline (Nuh first)

Run from `E:/DevEnv/kids_voice` with the SILMA venv (`E:/DevEnv/silma-venv`,
torch 2.6.0+cu124; SILMA TTS: MIT code, Apache-2.0 weights). The owner's
voice reference (`owner_ref_short_24k.wav`, 6.6 s - SILMA's code caps a
reference at 8.05 s) is NOT in git: the repo is public.

1. `genall.py` - one WAV per line of `lines.txt`. Every line is FULLY
   voweled by hand: SILMA skips its own tashkeel once a text has 3+ marks,
   and half-voweled text was mispronounced (owner, 2026-09-30).
   nfe_step 32, speed 0.85.
2. Check each line by transcribing it (FastConformer, E:/DevEnv/asr) and
   regenerate stutters with another seed (`genfix.py`, `genend.py`); long
   lines are split - SILMA speeds up the short tail chunk of a long line.
3. `mix2.py` - trims edges, shortens pauses inside a line to 0.2 s, 0.35 s
   between lines -> `voice2.wav` + `timing2.json` (scene durations).
4. `amb.py` - procedural ambience (filtered noise: wind, water, rain, waves;
   nothing downloaded, no music) at -44 dBFS, cross-faded per scene, fading
   out with the last word.
5. ffmpeg mix: high-pass, light compression, the bed ducked under the voice
   (sidechaincompress), loudnorm -16 LUFS.
The ayah recitation in scene 11 is in the PREVIEW only (licence NEEDS_REVIEW
in CONTENT-LICENSES.md); the published story streams it from the app.

## Voice v2: Gemini 3.8 Flash TTS (owner's choice, 2026-10-01: «روعة»)
`gemini_tts.py` (key read from `scripts/.env` GEMINI_API_KEY, never printed)
+ `genall_g.py`: prebuilt voice **Sadaltager**, one mood per line on top of a
base direction that asks for a studio-clean recording. Every file then goes
through `afftdn=nr=18:nf=-50:tn=1,highpass=70,lowpass=10500,agate` - the raw
output had a noise floor at -64 dB and 34 % of its energy above 4 kHz (the
owner heard «خرفشة … كأنك في التليفون»); cleaned: -99 dB.
**Free tier = 3 requests/minute and 10 requests/day** (the 429 says so;
RPD resets at midnight Pacific = 11:00 Dubai in October). One story is 12
lines: batch lines, or a paid key (~$0.002 per 10 s of audio, Google's
pricing page 2026-10-01).
