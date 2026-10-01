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
