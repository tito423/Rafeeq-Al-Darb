"""Select actual app locale chips, capture screenshots, preserve original Urdu.

Home header button positions are taken from the inspected1080x2400 screenshots.
Picker choices are located in a fresh accessibility XML, never a stale dump.
"""
from pathlib import Path
import json, subprocess, time, xml.etree.ElementTree as ET, re

out = Path('E:/My Projects/Rafiq-Al-Darb/docs/audits/evidence/2026-10-09')
names = {'ar':'العربية','en':'English','fr':'Français','es':'Español','pt':'Português','ru':'Русский','ur':'اردو'}
def adb(*args):
    process = subprocess.run(['adb','-s','emulator-5554',*args],capture_output=True)
    if process.returncode:
        raise RuntimeError(process.stderr.decode(errors='replace'))
    return process.stdout

current = 'en'
result = []
for lang in ['ar','en','fr','es','pt','ru','ur']:
    adb('shell','input','tap','209' if current in ['ar','ur'] else '869','350')
    time.sleep(.7)
    adb('shell','rm','-f','/sdcard/audit_home_locale.xml')
    output = adb('shell','uiautomator','dump','/sdcard/audit_home_locale.xml').decode(errors='replace')
    if 'dumped' not in output:
        raise RuntimeError('fresh picker dump failed: '+output)
    document = adb('shell','cat','/sdcard/audit_home_locale.xml')
    tree = ET.fromstring(document)
    nodes = [node for node in tree.iter('node')
             if node.get('text') == names[lang] or node.get('content-desc') == names[lang]]
    if len(nodes) != 1:
        raise RuntimeError(f'Expected one current picker chip for {lang}, found{len(nodes)}')
    x1,y1,x2,y2 = map(int,re.findall(r'\d+',nodes[0].get('bounds','')))
    adb('shell','input','tap',str((x1+x2)//2),str((y1+y2)//2))
    time.sleep(.8)
    shot = out/f'device-home-{lang}.png'
    shot.write_bytes(adb('exec-out','screencap','-p'))
    result.append(dict(lang=lang,screenshot=shot.name,device_date=adb('shell','date').decode().strip(),
                       selection_label=names[lang],selection_bounds=[x1,y1,x2,y2],
                       scope='Actual signed baseline emulator screenshot; requires visual inspection, not all-screen certification.'))
    current = lang
    (out/'device-home-locale-walk.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
    print('Captured actual home',lang,flush=True)
