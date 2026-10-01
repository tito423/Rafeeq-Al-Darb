# Kids stories - visuals renderer

Deterministic, code-drawn scenes (Canvas 2D) rendered frame by frame in
headless Chrome and encoded with ffmpeg to 1280x720, 30 fps, H.264, no audio.
Rules: `docs/kids_stories_brief.md` (no human figure, no music, no Qur'an text
drawn, nothing beyond the scene list).

## Render

```bash
kids_stories/render.sh noah            # -> kids_stories/noah/preview.mp4
kids_stories/render.sh noah --stills   # 3 PNGs per scene in noah/out/stills (seconds, no encode)
kids_stories/render.sh noah --at 3.2,40.5            # stills at these global seconds -> noah/out/at
kids_stories/render.sh noah --audio narration.mp3    # mux the narration (AAC) into the MP4
```

Needs Node 22+ (built-in `WebSocket`), Chrome/Edge/Chromium, and ffmpeg with
libx264. Found automatically on this machine (Chrome in Program Files, ffmpeg
from ShareX); elsewhere set `CHROME=/path` and `FFMPEG=/path`.
Measured 2026-09-30 on the owner's PC: 96 s of video (2,880 frames) in about
280 s; stills in about 6 s.

## New timings from the narration

Edit `kids_stories/<story>/timing.json` - one entry per scene, in order:

```json
[{ "scene": 1, "seconds": 7.35 }, { "scene": 2, "seconds": 9.1 }, ...]
```

then run `render.sh <story>` again. Scene `n` starts exactly at the sum of the
earlier `seconds`, so narration can be laid on those boundaries. Every
animation that belongs to a scene's story beat is scaled to that scene's
length; rain, waves and ripples keep their natural speed. The 0.7 s
cross-fades straddle boundaries (half before, half after) and do not move
them. The render refuses a timing file whose count or scene numbers do not
match the story.

## v2 (2026-10-01): motion and word sync

- `<story>/words.json` (per-scene word start times from the narration's ASR)
  is passed to the page; scenes call `K.beat(scene, 'word', fallbackSeconds)`
  so each event lands on the word that names it (idols on «تماثيل», planks on
  «ألواح», pegs on «ومسامير», the first pair on «زوجين», the wave on «الموج»,
  al-Judi on «الجودي» ...). Re-voicing only needs a new timing.json + words.json.
- Every scene is 4-7 parallax layers (`K.par(c, depth, fn)`) under a camera
  that always moves (scene move + a slow hand-held breath in the engine).
- Ambient life: birds, dust in light, swaying grass, god rays, spray.
- Cuts are 0.5 s with a slight push-in on the incoming shot (v1: 0.7 s ghosting).
- Brief rule 1 as updated 2026-09-30: ordinary people appear only as flat,
  featureless figures (`K.person`, no eyes or mouth - scene 5); Nuh is never
  drawn, his presence is only a warm light (`K.presence`).

## Layout

| | |
|---|---|
| `render.sh`, `render.mjs` | one-command render; CDP client, frame loop, ffmpeg pipe |
| `engine/index.html` | timeline, camera, cross-fades, fade in/out |
| `engine/lib.js` | drawing kit: sky, sun, moon, stars, clouds, land, town, stones, water, rain, the ark (plank by plank with pegs), animals |
| `noah/scenes.js` | the 12 scenes of the story of Nuh, each citing its verse |
| `noah/timing.json` | per-scene seconds, measured from the narration |
| `noah/words.json` | per-word start seconds within each scene |
| `LICENSES.md` | licences of every tool, checked live |

## Decisions to know about (Nuh)

- Only scene 5 has people (faceless passers-by who point and laugh); the ark's planks fly in from the pile by themselves.
- Scene 3: sun and moon speed up to at most 1.2 day-night cycles per second
  and the sky's contrast is softened as they speed up, to stay well under the
  3-flashes-per-second photosensitivity guideline. Full sun/moon arc trails
  were tried first and looked like a rainbow (ruled out by the brief), so
  they became short comet tails.
- Scene 6: no oven (tannur) is drawn - only water welling from the ground.
- Scene 8: "gates of the sky" are drawn as lit breaks in the cloud with
  torrents falling, not as doors or architecture.
- Scene 10: the ark, the far lone peak and the wave that rises between them and covers the peak; no person.
- Scene 12: the lower third is open meadow, kept empty for the lesson line.
- Shapes the brief does not specify and had to be chosen: the ark has a hull,
  a plank cabin with a pitched roof and small vents, a side door and (scene 7
  only) a ramp; the animals are elephants, camels, lions, horses and sheep.
