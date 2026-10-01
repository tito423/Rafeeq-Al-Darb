#!/usr/bin/env bash
# stills at 35% and 85% of every scene of a story -> <story>/out/sheetN.png
s=$1
AT=$(py -3 -c "
import json;T=[e['seconds'] for e in json.load(open('$s/timing.json'))]
S=[sum(T[:i]) for i in range(len(T))]
print(','.join(str(round(S[i]+d*f,2)) for i,d in enumerate(T) for f in (0.35,0.85)))")
rm -rf "$s/out/at"; node render.mjs "$s" --at "$AT" | tail -1
py -3 -c "
from PIL import Image, ImageDraw
import glob
fs=sorted(glob.glob('$s/out/at/*.png'))
for k in range(0,len(fs),9):
    sh=Image.new('RGB',(1920,1080))
    for j,f in enumerate(fs[k:k+9]):
        im=Image.open(f).resize((640,360)); ImageDraw.Draw(im).text((8,8),f[-10:-4],fill=(255,255,0)); sh.paste(im,((j%3)*640,(j//3)*360))
    sh.save('$s/out/sheet%d.png'%(k//9))
print(len(fs))"
