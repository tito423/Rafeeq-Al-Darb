# Kids stories — visual pipeline brief (cloud session)

Read `CLAUDE.md` first; it binds you. You are building the VISUALS ONLY for
the kids-corner prophet stories. The narration text is written and sourced
by the local session and is not yours to write or change.

## Hard rules (owner + Islamic content standard)
1. **Who may be drawn** (owner's decision in chat, 2026-09-30, after being
   shown the Dar al-Ifta / Majma' al-Buhuth rulings: «انت رايك صح»):
   - ordinary people MAY appear, flat kids style, faces NOT fully featured
     (no detailed eyes or mouth);
   - a **prophet or companion is NEVER drawn** - no body, silhouette, shadow
     or hands; his presence is only a soft warm glow in the scene;
   - angels are never drawn.
2. **No music.** Natural sound effects only, and only if they come from a
   source whose licence you record (CC0 preferred). None is fine.
3. **No Qur'an text drawn in the video.** On-screen text is added later by
   the local session from the app's own mushaf text.
4. Nothing invented beyond the scene list below (no rainbow, no dove, no
   extra events). If a scene seems to need something not listed, leave it
   out and note it.
5. Check every library licence live (§1.7) and write it in
   `kids_stories/LICENSES.md`.

## What to build
- `kids_stories/` — a deterministic renderer: scenes as code
  (SVG/Canvas/HTML, or Remotion if its licence fits an individual's
  non-commercial app — check it live), rendered frame by frame with a
  headless browser and encoded with ffmpeg.
- Output: 1280x720, 30 fps, H.264 MP4, calm child-friendly flat style,
  warm palette, smooth easing, gentle camera moves. Quality bar: a
  professional kids' explainer.
- Each scene's duration comes from `kids_stories/noah/timing.json`
  (`[{ "scene": 1, "seconds": 8.0 }, ...]`); create it with placeholder
  durations of 8 s each. The local session will replace it with the
  narration's measured durations and re-render, so the render must read it.
- One command renders the whole story: `kids_stories/render.sh noah`.

## Story 1 — Nuh (Noah), peace be upon him: scenes
Each scene cites the verse it rests on; draw only what the verse states.
1. Stone idols standing in an old valley town at dusk (Nuh 71:23 names
   the idols; draw plain unnamed stone shapes, no labels).
2. Day and night passing over the town again and again — the call made
   by night and by day (Nuh 71:5).
3. Sun and moon racing across the sky, a sense of very many years
   (al-Ankabut 29:14 — 950 years; no number on screen).
4. An ark taking shape from planks and pegs, plank by plank, in open land
   (Hud 11:37, al-Qamar 54:13 «ذات ألواح ودسر»).
5. The town beside the growing ark, quiet — mocking is told by the
   narrator only (Hud 11:38).
6. Water welling up out of the ground (Hud 11:40 «وفار التنور»; the
   exegetes differ on what al-tannur is, so draw no oven - only water rising
   from the earth).
7. Animals in pairs walking up into the ark (Hud 11:40).
8. The sky's gates pouring water, springs bursting from the earth, waters
   meeting (al-Qamar 54:11-12).
9. The ark sailing on waves like mountains (Hud 11:42).
10. A great wave rising and filling the view, then calm (Hud 11:43 — told
    by the narrator; draw only the wave).
11. The rain stops, the water sinks into the earth, the ark comes to rest
    on a mountain (Hud 11:44, al-Judi).
12. Closing: calm landscape at sunrise, room for a lesson line added later.

## Deliverable
Branch `kids-stories-pipeline`, pushed. `kids_stories/noah/preview.mp4`
(placeholder timings), `LICENSES.md`, and a short `kids_stories/README.md`
on how to re-render with new timings. Commit messages per CLAUDE.md §2.4.
Do NOT touch `rafeeq_app/`.
