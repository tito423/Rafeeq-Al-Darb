"""Preview night / warm paper on real scanned mushaf pages, off the device.

Downloads page 050 of each raster printing from R2 (see the curl loop in the
commit that added this), then applies the SAME colour matrices the app uses
(lib/features/quran/data/mushaf_paper_provider.dart) and tiles normal | warm |
night per printing into sheet.png. madinah_night is a dark page and is left
untouched, as in the app. Run from a folder holding <edition>.jpg files.
"""
import numpy as np
from PIL import Image
inv=np.array([[-1,0,0,0,255],[0,-1,0,0,255],[0,0,-1,0,255],[0,0,0,1,0]],float)
hue=np.array([[-0.574,1.430,0.144,0,0],[0.426,0.430,0.144,0,0],[0.426,1.430,-0.856,0,0],[0,0,0,1,0]],float)
grd=np.array([[0.9,0,0,0,15],[0,0.9,0,0,23],[0,0,0.9,0,34],[0,0,0,1,0]],float)
warm=np.array([[244/255,0,0,0,0],[0,232/255,0,0,0],[0,0,207/255,0,0],[0,0,0,1,0]],float)
def comp(a,b):
    A=np.vstack([a,[0,0,0,0,1]]);B=np.vstack([b,[0,0,0,0,1]]);return (A@B)[:4]
night=comp(grd,comp(hue,inv))
def apply(img,m):
    x=np.asarray(img.convert('RGBA'),float); h,w,_=x.shape
    v=np.concatenate([x.reshape(-1,4),np.ones((h*w,1))],1)
    y=np.clip(v@m.T,0,255).reshape(h,w,4).astype(np.uint8); return Image.fromarray(y,'RGBA').convert('RGB')
eds=['tajweed','madinah_gold','qatar','kuwait','madinah_night']
W=300; rows=[]
for e in eds:
    im=Image.open(f'{e}.jpg').convert('RGB'); im=im.resize((W,int(im.height*W/im.width)))
    dark = e=='madinah_night'
    cells=[im, im if dark else apply(im,warm), im if dark else apply(im,night)]
    rows.append(cells)
H=max(c.height for r in rows for c in r)
sheet=Image.new('RGB',(W*3+20,(H+10)*len(rows)),'grey')
for i,r in enumerate(rows):
    for j,c in enumerate(r): sheet.paste(c,(j*(W+10),i*(H+10)))
sheet.save('sheet.png'); print(sheet.size)
