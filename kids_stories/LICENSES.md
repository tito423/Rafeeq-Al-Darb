# Kids stories - licences of everything the pipeline uses

Checked live on 2026-09-30 (CLAUDE.md §1.7). Re-check when a tool is upgraded.

## Assets

**None.** Every picture in the video is drawn by code in this folder
(`engine/lib.js`, `<story>/scenes.js`) - written for this project, owned by
the project. No image, font, icon, clip art, sound effect or music is
downloaded or embedded. The preview has **no audio track** (brief rule 2: no
music; natural sound effects only if licensed - none were added).

## Tools (used to render; nothing from them is shipped inside the video)

| Tool | Version used | Licence | Checked at |
|---|---|---|---|
| Node.js | 24.21.0 | MIT ("Permission is hereby granted, free of charge…") | https://raw.githubusercontent.com/nodejs/node/main/LICENSE |
| Google Chrome (headless) | 154.0.8037.58 | Google Terms of Service + Chrome Additional Terms; most source under open-source licences listed at `chrome://credits`. The excerpt read says nothing restricting headless/automated use. Edge or Chromium work too (`CHROME=`). | https://www.google.com/chrome/terms/ |
| FFmpeg | n8.1.1 (BtbN-style static build bundled with ShareX at `C:\Program Files\ShareX\ffmpeg.exe`) | LGPL 2.1+, but this build is `--enable-gpl`, so GPL 2+ applies to the ffmpeg binary. Using the binary as a tool does not put the output video under the GPL. | https://ffmpeg.org/legal.html |
| x264 (inside that ffmpeg) | as built in n8.1.1 | GNU GPL (commercial licence also offered by VideoLAN) | https://www.videolan.org/developers/x264.html |

No npm packages are used: `render.mjs` speaks the Chrome DevTools Protocol
through Node's built-in `WebSocket` and `fetch`, so there is no dependency
tree whose licences would need tracking. (puppeteer-core 25.12.0 and
playwright-core 1.63.0 are both Apache-2.0 per `npm view` on 2026-09-30, if a
later session prefers one.)

## Open question for the owner (not verified, not a lawyer's answer)

H.264 is required by the brief. H.264 is a patented format pooled by Via LA
(formerly MPEG LA). A summary of https://www.via-la.com/licensing-programs/avc-h-264/
fetched on 2026-09-30 said the AVC licence does **not** exempt free
distribution in general; ffmpeg's legal page says private non-commercial use
carries little practical concern. Whether a free, sideloaded, non-commercial
app that bundles or streams these clips owes anything was **not** established
here - that needs the licence text itself read in full, or advice.
