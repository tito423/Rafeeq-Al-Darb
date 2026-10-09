import subprocess,time,json,re
from pathlib import Path
root=Path('E:/My Projects/Rafiq-Al-Darb');out=root/'docs/audits/evidence/2026-10-09'
pkg='com.tito.rafeeq_aldarb'
def adb(*args):return subprocess.run(['adb','-s','emulator-5554',*args],capture_output=True,text=True).stdout
results=[]
for n in range(1,4):
    adb('shell','am','force-stop',pkg)
    time.sleep(1)
    adb('logcat','-c')
    start=adb('shell','am','start','-W','-n',pkg+'/.MainActivity')
    time.sleep(8)
    mem=adb('shell','dumpsys','meminfo',pkg)
    log=adb('logcat','-d','-s','flutter:E','AndroidRuntime:E')
    result={'run':n,'start_output':start,'meminfo':mem,'errors':log,'scenario':'Process cold start via force-stop; emulator API36.1; signed baseline 3.87.0+102; Urdu/light; not a physical phone or profile build.'}
    results.append(result)
    print('Run',n,re.findall(r'(LaunchState|TotalTime|WaitTime):\s*(\S+)',start),flush=True)
(out/'device-cold-starts.json').write_text(json.dumps(results,indent=2),encoding='utf-8')
shot=subprocess.check_output(['adb','-s','emulator-5554','exec-out','screencap','-p'])
(out/'home-cold.png').write_bytes(shot)
