# Procedural ambience (no downloaded audio): filtered noise per scene, cross-faded.
import numpy as np, json, wave
from scipy.signal import butter, sosfilt
SR=24000; rng=np.random.default_rng(3)
T=json.load(open('timing2.json')); dur=[t['seconds'] for t in T]; total=sum(dur)
N=int(total*SR)+SR; t=np.arange(N)/SR
def filt(x, kind, f): return sosfilt(butter(2, f, kind, fs=SR, output='sos'), x)
def brown(n):
    w=rng.standard_normal(n); b=np.cumsum(w); b-=filt(b,'high',8)*0+np.convolve(b,np.ones(2400)/2400,'same'); return b/np.max(np.abs(b))
white=rng.standard_normal(N)
wind=filt(white,'low',280)*(0.55+0.45*np.sin(2*np.pi*t/7.3)**2)
rain=filt(filt(white,'high',700),'low',3000)
swell=(np.sin(2*np.pi*t/6.5)*0.5+0.5)**2
waves=filt(white,'low',450)*(0.25+0.75*swell)
bubble=filt(white,'low',200)*(0.5+0.5*np.sin(2*np.pi*t*7)**8)
def norm(x): return x/np.sqrt(np.mean(x**2))
wind,rain,waves,bubble=map(norm,(wind,rain,waves,bubble))
# per-scene gains (linear RMS relative): wind, rain, waves, bubble
G={1:(1,0,0,0),2:(1,0,0,0),3:(.8,0,0,0),4:(1,0,0,0),5:(1,0,0,0),6:(.6,0,0,1),
   7:(.8,.35,0,.4),8:(.3,1,.6,0),9:(.2,.8,1,0),10:(.1,.6,1,0),11:(.4,.1,.6,0),12:(.7,0,.15,0)}
env=np.zeros((4,N)); start=0.0
for i,d in enumerate(dur,1):
    a=int(start*SR); b=int((start+d)*SR); env[:,a:b]=np.array(G[i])[:,None]; start+=d
env[:,int(start*SR):]=np.array(G[12])[:,None]
k=int(1.2*SR)
def smooth(e):
    c=np.cumsum(np.concatenate([np.zeros(1),e])); m=(c[k:]-c[:-k])/k
    return np.concatenate([np.full(k//2,m[0]),m,np.full(len(e)-len(m)-k//2,m[-1])])
env=np.array([smooth(e) for e in env])   # 1.2 s cross-fades (running mean via cumsum)
amb=(env[0]*wind+env[1]*rain+env[2]*waves+env[3]*bubble)
amb*=10**(-44/20)   # about -44 dBFS RMS: a bed, never over the voice
fade=int(2*SR); amb[:fade]*=np.linspace(0,1,fade)
# end: the bed fades out WITH the last word (voice ends 1.5 s before the track), never swells after it
vend=int((total-1.5)*SR); f0=vend-int(1.2*SR); f1=vend+int(0.4*SR)
amb[f0:f1]*=np.linspace(1,0,f1-f0); amb[f1:]=0
w=wave.open('amb2.wav','wb'); w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
w.writeframes((np.clip(amb,-1,1)*32767).astype(np.int16).tobytes()); w.close(); print('ok', round(N/SR,1))
