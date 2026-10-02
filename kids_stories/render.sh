#!/usr/bin/env bash
# Render one kids story to <story>/preview.mp4 using <story>/timing.json.
#   kids_stories/render.sh noah
# Needs Node 22+ (built-in WebSocket), Chrome/Edge/Chromium and ffmpeg with
# libx264. Override discovery with CHROME=... and FFMPEG=...
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
if [ $# -lt 1 ]; then echo "usage: $0 <story> [--stills] [--out file.mp4]" >&2; exit 2; fi
exec node "$here/render.mjs" "$@"
