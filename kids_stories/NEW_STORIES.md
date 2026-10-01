# Visuals for the new stories (written in a cloud session, 2026-10-01)

These files belong to the renderer on branch `kids-stories-pipeline`
(`kids_stories/engine`, `render.mjs`). They were written on `master-353kkv`
only because that is the branch the cloud session may push to. To render:
copy `kids_stories/<id>/` and `estimate_timing.py` into the pipeline worktree.

- `<id>/scenes.js` - the scenes, one per row of
  `docs/kids_stories/<id>_narration.md`, same rules as the other stories
  (prophets, angels and the caution list in each doc's notes: light only).
- `<id>/timing.json` - **ESTIMATED** (every entry has `"estimated": true`),
  from `estimate_timing.py`. Overwrite it with the real timing.json and
  words.json once the narration is voiced, then render. Until words.json
  exists, each `K.beat` falls back to a fraction of its scene.
- Every story's stills were rendered here (headless Chromium, `--stills`) and
  looked at before the commit.

| Story | Scenes | Stills checked |
|---|---|---|
| ayyub | 12 | yes |
| zakariya | 15 | yes - Yahya's mother not drawn (lit home instead), the Torah a blank scroll |
| yusuf | 24 | yes - brothers as eleven small stars/caravan/sacks, never people; no wolf, plain shirt; the greeting = stars, sun and moon over the palace |
| kahf | 17 | yes - youths featureless, never countable (in shade, lying); the dog calm at the entrance; the mountain redrawn rugged after the first pass looked like a pyramid |
| luqman | 12 | yes - Luqman and his son as lights; each counsel pictured (seed in a rock, cradle in a lit home, prayer rug); no donkey |
| shuayb | 12 | yes - a balance that leans then levels; glowing honest coins beside a fading heap; the punishment = an empty market |
| kaaba | 19 | yes - Hajar a small light (tent, between Safa and Marwa x7); Zamzam bursts in light, no angel; the House as plain stone courses rising, no covering or writing; the Prophet ﷺ in 2:129 only as a far star; tawaf by featureless figures in white |
| musa_baby | 13 | yes - baby Musa a small light in a reed basket; mother = light at the home, sister = footprints on the bank, Pharaoh's wife = a lit palace window; servants and wet-nurses featureless |
| fil | 7 | yes - army and elephant drawn, soldiers featureless; birds and small stones in the sky, nobody shown hit; an empty field of blowing dry leaves; the House far off and whole |
