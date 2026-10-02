#!/bin/bash
# R4 (2026-10-02): voice the four remaining stories + re-voice isa 15, dhulqarnayn 8, salih 3-4.
cd /e/DevEnv/kids_voice
run() { # dir out model ids...
  local d=$1 o=$2 m=$3; shift 3
  [ -s "$d/$o" ] && { echo "skip $d/$o"; return; }
  for t in 1 2 3; do (cd $d && timeout 250 py -3 ../gen_multi.py --model $m $o "$@") && return; echo "retry $d $o"; sleep 20; done
}
F=gemini-3.8-flash-tts
for s in jannatayn dawud dhabih khidr; do
  ids=($(cut -f1 $s/lines.tsv)); n=1
  for ((i=0;i<${#ids[@]};i+=4)); do run $s b$n.wav $F ${ids[@]:i:4}; n=$((n+1)); done
done
run isa bfix.wav $F 15
run dhulqarnayn bfix.wav $F 8
run salih bfix.wav gemini-3.8-flash-lite-tts 3 4
echo ALLDONE
