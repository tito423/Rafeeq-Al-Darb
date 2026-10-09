import importlib.util,json,re,subprocess,concurrent.futures
from pathlib import Path
spec=importlib.util.spec_from_file_location('endpoints',Path(__file__).with_name('rafeeq_audit_endpoints.py'))
ep=importlib.util.module_from_spec(spec);spec.loader.exec_module(ep)
text=ep.read('rafeeq_app/lib/core/config/content_mirrors.dart')
mapping={}
for tag,body in re.findall(r"'(content-[^']+)':\s*\[([^]]+)\]",text):
    mapping[tag]=re.findall(r"'([^']+/)'",body)
items=[]
for item in ep.unique.values():
    if not item['url'].startswith(ep.base+'/'): continue
    key=item['url'][len(ep.base)+1:]
    tags=[tag for tag,prefixes in mapping.items() if any(key.startswith(p) for p in prefixes)]
    for tag in tags:
        items.append(dict(item,kind='mirror-'+item['kind'],url=f'https://github.com/tito423/Rafeeq-Al-Darb/releases/download/{tag}/'+key.replace('/','__'),original=item['url']))
    if item['kind']=='voice-pack' and not tags:
        items.append(dict(item,kind='unwired-voice-mirror',url='https://github.com/tito423/Rafeeq-Al-Darb/releases/download/content-mirror/'+key.replace('/','__'),original=item['url']))
config=json.loads(subprocess.check_output(['curl.exe','-fsSL','--max-time','30',ep.base+'/config/recitation_mirrors.json'],text=True))
(ep.out/'recitation-mirrors-live.json').write_text(json.dumps(config,indent=2),encoding='utf-8')
for folder in config['ayah']:
    for surah,ayah,part in [(1,1,1),(114,6,7)]:
        items.append(dict(kind='mirror-ayah-reciter',url=f'https://github.com/tito423/rafeeq-recitations/releases/download/ayah-{folder}-p{part}/{surah:03}{ayah:03}.mp3',path='rafeeq_app/lib/core/services/recitation_mirrors.dart',line=60))
reciters=ep.load('rafeeq_app/assets/data/catalogs/reciters_full.json')
moshaf={m['id']:m for r in reciters for m in r['moshaf']}
for mid in config['surah']:
    m=moshaf.get(mid)
    if not m: continue
    surahs=[int(s) for s in m['surah_list'].split(',') if s]
    for surah in sorted(set([min(surahs),max(surahs)])):
        items.append(dict(kind='mirror-surah-reciter',url=f'https://github.com/tito423/rafeeq-recitations/releases/download/surah-{mid}/{surah:03}.mp3',path='rafeeq_app/lib/core/services/recitation_mirrors.dart',line=64))
items=list({x['url']:x for x in items}.values())
(ep.out/'mirror-inventory.json').write_text(json.dumps(items,ensure_ascii=False,indent=2),encoding='utf-8')
out=ep.out/'mirrors.jsonl'
results=[json.loads(s) for s in out.read_text(encoding='utf-8').splitlines()] if out.exists() else []
seen={x['url'] for x in results}
pending=[x for x in items if x['url'] not in seen]
print('Mirror requests remaining',len(pending),'live sets',len(config['ayah']),len(config['surah']),flush=True)
with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:
    for i,result in enumerate(pool.map(ep.probe,pending),1):
        results.append(result)
        with out.open('a',encoding='utf-8') as f:f.write(json.dumps(result,ensure_ascii=False)+'\n')
        if i%100==0:print('Mirrors checked',i,'failed',sum(not r['ok'] for r in results),flush=True)
print(json.dumps(dict(total=len(results),failed=sum(not r['ok'] for r in results),failures=[r for r in results if not r['ok']]),indent=2),flush=True)
