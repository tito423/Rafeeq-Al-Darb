import wave, numpy as np, json, subprocess
SR=24000
def load(f):
    w=wave.open(f); x=np.frombuffer(w.readframes(w.getnframes()),dtype=np.int16).astype(np.float32)/32768
    assert w.getframerate()==SR; return x
def tighten(x, gap=0.13, edge=0.04):
    hop=int(SR*0.01); n=len(x)//hop
    db=np.array([20*np.log10(np.sqrt(np.mean(x[j*hop:(j+1)*hop]**2))+1e-9) for j in range(n)])
    v=db>-40; idx=np.where(v)[0]
    a=max(0,idx[0]*hop-int(edge*SR)); b=min(len(x),(idx[-1]+1)*hop+int(edge*SR))
    out=[]; j=idx[0]; start=a
    # shorten silent runs longer than gap
    k=idx[0]
    while k<=idx[-1]:
        if not v[k]:
            r=k
            while r<=idx[-1] and not v[r]: r+=1
            if (r-k)*0.01>gap:
                cut_a=k*hop+int(gap/2*SR); cut_b=r*hop-int(gap/2*SR)
                out.append(x[start:cut_a]); start=cut_b
            k=r
        else: k+=1
    out.append(x[start:b])
    # join the kept pieces with a 20 ms equal-power cross-fade: a butt splice
    # inside a pause was heard as a click at every shortened comma (owner, v5)
    xf=int(0.02*SR); fi=np.sin(np.linspace(0,np.pi/2,xf))**2; fo=1-fi
    y=out[0]
    for p in out[1:]:
        if len(y)<xf or len(p)<xf: y=np.concatenate([y,p]); continue
        y=np.concatenate([y[:-xf], y[-xf:]*fo + p[:xf]*fi, p[xf:]])
    f=int(0.01*SR); y[:f]*=np.linspace(0,1,f); y[-f:]*=np.linspace(1,0,f)
    return y
sil=lambda s: np.zeros(int(s*SR),np.float32)
scenes=[]; timing=[]
for i in range(1,13):
    parts=[sil(0.25)]
    if i==11: parts+= [load('r11044.wav'), sil(0.5)]
    parts+=[tighten(load(f'n{i:02d}.wav')), sil(0.3 if i<12 else 1.5)]
    seg=np.concatenate(parts); scenes.append(seg); timing.append({'scene':i,'seconds':round(len(seg)/SR,3)})
voice=np.concatenate(scenes)
wave_out=wave.open('voice2.wav','wb'); wave_out.setnchannels(1); wave_out.setsampwidth(2); wave_out.setframerate(SR)
wave_out.writeframes((np.clip(voice,-1,1)*32767).astype(np.int16).tobytes()); wave_out.close()
json.dump(timing,open('timing2.json','w'),indent=1)
print('total', round(len(voice)/SR,2)); print([t['seconds'] for t in timing])
