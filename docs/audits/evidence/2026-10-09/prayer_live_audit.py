from pathlib import Path
import subprocess,json,re,time,concurrent.futures
out=Path('docs/audits/evidence/2026-10-09');base='https://api.aladhan.com/v1'
def get(url):
 for attempt in range(3):
  p=subprocess.run(['curl','-sS','--fail','--max-time','20',url],capture_output=True)
  if p.returncode==0:
   obj=json.loads(p.stdout)
   if obj.get('code')==200:return obj['data']
  if attempt==2:raise RuntimeError(url+' '+p.stderr.decode(errors='replace')[:180])
  time.sleep(.5)
methods=get(base+'/methods');published={str(m['id']):dict(key=k,name=m['name'],params=m.get('params') or {}) for k,m in methods.items() if m.get('id') not in [None,99]}
(out/'prayer-methods-live.json').write_text(json.dumps(published,indent=2),encoding='utf-8')
src=Path('rafeeq_app/lib/core/models/prayer_calculation_methods.dart').read_text(encoding='utf-8');ids=sorted(map(int,re.findall(r'^\s*id:\s*(\d+),',src,re.M)))
cities=[('cairo',30.0444,31.2357),('makkah',21.4225,39.8262),('jakarta',-6.2088,106.8456),('london',51.5074,-.1278),('dubai',25.2048,55.2708)]
work=[(m,c,lat,lon,date,school) for m in ids for c,lat,lon in cities for date in ['10-10-2026','25-10-2026'] for school in [0,1]]
def fetch(w):
 m,c,lat,lon,date,school=w;url=f'{base}/timings/{date}?latitude={lat}&longitude={lon}&method={m}&school={school}&timezonestring=UTC';data=get(url);t=data['timings']
 return dict(method=m,city=c,latitude=lat,longitude=lon,date=date,school=data['meta']['school'],latitudeAdjustmentMethod=data['meta']['latitudeAdjustmentMethod'],url=url,**{k.lower():t[k].split(' ')[0] for k in ['Fajr','Sunrise','Dhuhr','Asr','Maghrib','Isha']})
rows=[];errors=[];start=time.time()
with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:
 for f in concurrent.futures.as_completed([pool.submit(fetch,w) for w in work]):
  try:rows.append(f.result())
  except Exception as e:errors.append(str(e))
  if (len(rows)+len(errors))%40==0:
   print('Fetched',len(rows),'/',len(work),'errors',len(errors),flush=True)
   (out/'prayer-timings-live.json').write_text(json.dumps(rows,indent=2),encoding='utf-8')
(out/'prayer-timings-live.json').write_text(json.dumps(rows,indent=2),encoding='utf-8')
(out/'prayer-live-fetch-summary.json').write_text(json.dumps(dict(planned=len(work),completed=len(rows),errors=errors,elapsed_seconds=round(time.time()-start,2),method_count=len(ids),dates=['10-10-2026','25-10-2026'],scope='Actual AlAdhan primary API requested now; app comparison separate; UTC numeric reference not local-zone/adhan audibility proof'),indent=2),encoding='utf-8')
if errors:raise SystemExit(1)
