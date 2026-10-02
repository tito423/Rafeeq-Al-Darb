# Nuh — visuals v2: from "acceptable" to professional

Read `CLAUDE.md` and `docs/kids_stories_brief.md` (rule 1 as updated on
master: ordinary people allowed with simplified faces - no eyes or mouth;
a prophet or companion NEVER drawn, only a soft warm glow; angels never).
No music, no drawn Qur'an text, nothing beyond the verses of each scene.

## What the owner said about v1 (2026-09-30)
«باين خالص انه تصميم آلي … المشهد بيطول ساكن مفيش أي حركات … عايزه
أكثر احترافية من كده بكتير». The reference he measures against is
@Codezilla's Claude-made motion-graphics explainer: constant, smooth,
purposeful motion, synced to the voice.

## Inputs (already in `kids_stories/noah/`)
- `timing.json` — the REAL scene durations of the finished narration
  (130.9 s). Scene 11 is 38 s: a recitation of Hud 11:44 then narration.
- `words.json` — the start time of every spoken word, per scene, in seconds
  from the scene's start (recogniser spelling). **Key events to words.**

## Requirements
1. **Nothing is ever still.** The camera always moves (slow push-in, pan,
   gentle parallax drift); 3–5 depth layers per scene at different speeds;
   ambient life every moment: drifting clouds, birds far off, dust, swaying
   palms and grass, shimmering water, rain particles, splashes, light rays.
2. **Word-synced beats** (from `words.json`), e.g.:
   - 1 «تماثيل» → the idols slide into focus; «يعبدونها» → the camera settles on them.
   - 2 «نوحًا» → a warm glow appears at the town's edge; «الليل» / «النهار» → sky turns.
   - 4 «ألواح» → planks fly in and stack; «مسامير» → pegs tap in with small sparks of dust.
   - 5 «سخروا» → a few simple faceless townspeople pass by pointing (body language only).
   - 7 «زوجين اثنين» → a pair enters exactly on the words; more pairs keep walking.
   - 8 «أبواب السماء» → the clouds split with light; «عيونًا» → springs burst up.
   - 10 the ark on huge waves; far off, one lone peak; the great wave rises
     between them on «الموج» and covers the peak (no person drawn); then calm.
   - 11 during the recitation: rain thins, clouds part, rays of light, water
     sinks, land appears; the ark settles on al-Judi on «الجودي».
   - 12 sunrise, birds, green shoots growing; the glow beside the ark.
3. **Transitions** ≤ 0.6 s (match cuts, camera moves, quick dissolves). No
   long ghosting of two scenes over each other (v1's biggest flaw).
4. **Remove from v1:** the broken planks in scene 5 (not in the verse).
5. **Look:** richer lighting (soft gradients, glow, god rays, soft shadows),
   atmospheric perspective (far layers hazier), smooth easing everywhere, a
   consistent warm palette. 1280x720, 30 fps, H.264 as before.
6. Keep one-command rendering (`render.sh noah`), keep `LICENSES.md` true,
   and **look at extracted frames and short clips of your own render**
   before calling it done (CLAUDE.md §1.3).

## Deliverable
Commit on `kids-stories-pipeline`, push, report the SHA, render time, and
what you could not verify. `noah/preview.mp4` is silent - the owner's voice
is not in the repo; the local session muxes it.
