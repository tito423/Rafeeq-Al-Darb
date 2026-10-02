#!/usr/bin/env bash
# wait for running renders, then render the given stories one after another
while pgrep -f "render.mjs (musa|sulayman)" >/dev/null 2>&1 || tasklist 2>/dev/null | grep -q "node.exe.*" && ps -W 2>/dev/null | grep -q "render.mjs"; do sleep 20; done
for s in "$@"; do node render.mjs $s --audio E:/DevEnv/kids_voice/$s/${s}_audio.mp3 --out $s/out/${s}_v1.mp4 > $s/out/render.log 2>&1; done
