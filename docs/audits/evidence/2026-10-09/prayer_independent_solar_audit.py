import sys,os,json,math
from pathlib import Path
sys.path.insert(0,str(Path(os.environ['TEMP'])/'rafeeq_audit_ephem_20261010'))
import ephem
rows=[]
for d in ['2026/10/10','2026/10/25']:
 obs=ephem.Observer();obs.lat='51.5074';obs.lon='-0.1278';obs.elevation=0;obs.pressure=0;obs.date=d+' 00:00:00';sun=ephem.Sun()
 noon=obs.next_transit(sun);obs.date=noon;sun.compute(obs);noon_alt=float(sun.alt);noon_shadow=1/math.tan(noon_alt)
 for factor in [1,2]:
  target=math.atan(1/(factor+noon_shadow));lo=float(noon);hi=lo+.3
  for _ in range(60):
   mid=(lo+hi)/2;obs.date=mid;sun.compute(obs)
   if float(sun.alt)>target:lo=mid
   else:hi=mid
  when=ephem.Date((lo+hi)/2)
  rows.append(dict(date=d,shadow_factor=factor,geometric_transit_utc=str(noon),noon_alt_deg=math.degrees(noon_alt),noon_shadow=noon_shadow,target_alt_deg=math.degrees(target),asr_geometric_utc=str(when)))
r=dict(engine='PyEphem '+ephem.__version__,pressure=0,elevation=0,scope='Independent geometric solar-shadow crossing using actual computed Sun altitude; not a religious verdict or proposed adjustment. Compare app and API outputs separately.',sources=['https://rhodesmill.org/pyephem/quick.html','https://github.com/batoulapps/adhan-js/blob/develop/src/SolarTime.ts'],results=rows)
Path('docs/audits/evidence/2026-10-09/prayer-independent-solar.json').write_text(json.dumps(r,indent=2),encoding='utf-8')
for row in rows:print(row)
