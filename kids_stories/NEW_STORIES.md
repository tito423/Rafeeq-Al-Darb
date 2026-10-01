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
| shuayb | 12 | yes - a balance that leans then levels; honest coins that glow (lawful profit is better) beside a fading heap; the punishment = an empty market |
| kaaba | 19 | yes - Hajar a small light (tent, between Safa and Marwa x7); Zamzam bursts in light, no angel; the House as plain stone courses rising, no covering or writing; the Prophet ﷺ in 2:129 only as a far star; tawaf by featureless figures in white |
| musa_baby | 13 | yes - baby Musa a small light in a reed basket; mother = light at the home, sister = footprints on the bank, Pharaoh's wife = a lit palace window; servants and wet-nurses featureless |
| fil | 7 | yes - army and elephant drawn, soldiers featureless; birds and small stones in the sky, nobody shown hit; an empty field of blowing dry leaves; the House far off and whole |
| isa | 17 | yes - Isa a light in a cradle then a light; Maryam a soft pale light; Jibril only light coming down onto the screen; dates fall, a stream appears; the clay bird whitens and flies; healing = light and opening flowers, no sick or dead drawn |
| dhulqarnayn | 14 | yes - Dhul-Qarnayn a travelling light; sunset over a dark spring as seen by the eye; Yajuj and Majuj never drawn (dust and shadow beyond the pass); iron rising, glowing, copper poured |
| jannatayn | 14 | yes - two featureless men (plain robe / rich robe); vines, palms, crops and the river; the ruin = fallen trellises and bare ground, no storm |
| hudhud | 15 | yes - the hoopoe drawn (crest, barred wings, long beak) and carries the story; Sulayman a light; the queen = her empty throne, then a soft light; the throne arrives in a flash, nobody drawn bringing it; people of Saba' stand facing the sun (no prostration drawn) |
| adam | 16 | yes - Adam a light, Hawwa a soft pale light; angels a ring of small white lights that dips (the prostration); Iblis NOT drawn at all (voice only), the whisper a cold wind that dims the garden; the names = six simple icons lighting in turn; an ordinary tree, no named fruit |
| dawud | 14 | yes - Dawud and their prophet lights, Talut a steady white light (caution); Jalut a large dark featureless shape far off; NO fighting drawn (dust settles, a banner rises); mountains and birds glorify = echo rings and a flock; iron rings of armour forming |
| dhabih | 14 | yes - two lights (father, son); scene 13 (added: the udhiyya, al-Sa'di/al-Qurtubi) = Eid morning, people in white, sheep standing; NO knife and no slaughter: the submission = two still lights on a rock under light from the sky; the ram drawn standing and alive; Ishaq a third small light |
| ihya | 11 | yes - the man of 2:259 and Ibrahim are lights; the hundred years = days and nights over the ruin while palms grow and the light dims and returns; the donkey rises whole out of a gathering shadow; the birds = feathers on four peaks gathering into whole birds - no bones, nothing cut |
| ilyas | 10 | yes - Ilyas a light; the idol a plain stepped stone with no face; the few sincere stay by the light |
| dayf | 12 | yes - Ibrahim a light; the angels three white lights at the tent, never figures or «guests»; Sara a soft light behind a moving screen; the calf a covered dish |
| sabt | 11 | yes - featureless people; fish crowd the surface on the Sabbath (a 7-dot calendar marks it) and vanish after; the pits; the warners in white walk away in light; the transformation NOT drawn - empty shore and pits |
| khidr | 17 | yes - Musa and al-Khidr lights (al-Khidr a cooler white-green light), Yusha' a smaller light; the fish leaps from the basket and leaves a trail in the sea; the ship and its hole; the second incident NOT drawn (scene 11: empty shore, the lights stop then walk on); the wall redrawn darker after the first pass read faint; two orphans small and featureless |

**2026-10-01, later**: the narration docs were re-quoted from the app's own
`quran_sciences.db` / `hadith.db` (GitHub content-mirror) and four narrator
lines lost words that are not in the app's al-Muyassar (kahf 10, shuayb 6 and
lesson, ilyas 2/4, sabt 2; fil 1/5/6). The scene comments were updated to
match; the pictures did not need to change. All timing.json files were
re-estimated from the corrected text.
