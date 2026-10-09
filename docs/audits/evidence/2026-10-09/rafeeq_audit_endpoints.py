from pathlib import Path
import json, re, subprocess, concurrent.futures, time
root=Path('E:/My Projects/Rafiq-Al-Darb')
out=root/'docs/audits/evidence/2026-10-09'
base='https://pub-39dbef68a1a845d5ba669b43a59516b9.r2.dev'
items=[]
def add(kind,url,path,line=1,expected=None):
    items.append(dict(kind=kind,url=url,path=path,line=line,expected_bytes=expected))
def read(name): return (root/name).read_text(encoding='utf-8')
def load(name): return json.loads(read(name))
cat='rafeeq_app/lib/features/library/data/book_catalog.dart'
for m in re.finditer(r"(?:url|downloadUrl):\s*'([^']+)'",read(cat)):
    n=read(cat)[:m.start()].count('\n')+1
    if m and (m[1].startswith('http') or '${AppConfig.contentBaseUrl}' in m[1]):
        add('book',m[1].replace('${AppConfig.contentBaseUrl}',base),cat,n)
cat='rafeeq_app/assets/data/mushaf/editions.json'
for e in load(cat)['editions']:
    for page in [1,e['pages']]: add('mushaf',f"{base}/mushaf/{e['image_path']}/{page:03}.{e.get('image_ext','jpg')}",cat)
cat='rafeeq_app/assets/data/catalogs/reciters_full.json'
for r in load(cat):
    for m in r['moshaf']:
        surahs=[int(s) for s in m['surah_list'].split(',') if s]
        for surah in sorted(set([min(surahs),max(surahs)])):
            add('surah-reciter',f"{m['server']}{surah:03}.mp3",cat)
cat='rafeeq_app/lib/core/services/recitation_source.dart'
for n,line in enumerate(read(cat).splitlines(),1):
    m=re.search(r"^\s*'ar\.[^']+': '([^']+)'",line)
    if m:
        for ayah in ['001001','114006']: add('ayah-reciter',f'https://everyayah.com/data/{m[1]}/{ayah}.mp3',cat,n)
cat='rafeeq_app/lib/features/kids/data/kids_stories_data.dart'
for n,line in enumerate(read(cat).splitlines(),1):
    m=re.search(r"id:\s*'([^']+)'",line)
    if m:
        for ext in ['mp4','jpg']: add('kids-story',f'{base}/kids/stories/{m[1]}.{ext}',cat,n)
cat='rafeeq_app/lib/features/azkar/data/adhkar_recitations.dart'
for id in ['fares_abbad','samir_albashiri','rami_muhammad','abdulaziz_bin_ibrahim','faisal_labban']:
    for t in ['morning','evening']: add('adhkar',f'{base}/azkar/recitations/{id}_{t}.mp3',cat)
for t in ['morning','evening']: add('adhkar',f'{base}/azkar/rafeeq_voice/{t}_v1.mp3',cat)
ih='https://d1.islamhouse.com/data/ar/ih_sounds/chain_01/Mishari_Raashid/Azkar_AlSba7_w_AlMsa/'
for f in ['ar_1434_Azkar_AlSba7.mp3','ar_1434_Azkar_AlMsa.mp3']: add('adhkar',ih+f,cat)
cat='rafeeq_app/assets/data/catalogs/quran_translations.json'
for tr in load(cat)['translations']: add('translation',f"{base}/quran/translations/{tr['lang']}.json.gz",cat,expected=tr['gz_bytes'])
cat='rafeeq_app/lib/features/assistant/data/rafeeq_voice_pack.dart'
for folder,names in [('rafeeq_v1',['model.int8.onnx','tokens.txt','silero_vad.onnx']),('rafeeq_ar_v1',['model.int8.onnx','tokens.txt'])]:
    for name in names: add('voice-pack',f'{base}/asr/{folder}/{name}',cat)
for lang in ['ar','en','fr','es','pt','ru','ur']: add('hadeethenc',f'{base}/hadeethenc/{lang}.zip','rafeeq_app/lib/core/config/app_config.dart')
add('hadith',base+'/hadith/hadith.zip','rafeeq_app/lib/core/config/app_config.dart')
add('sciences',base+'/sciences/v2/quran_sciences.zip','rafeeq_app/lib/core/config/app_config.dart')
cat='rafeeq_app/assets/data/azkar_audio.json'
for url in load(cat)['audio'].values(): add('individual-dhikr',url,cat)
for name in ['fp_ms.onnx','vocos44.onnx']:
    add('book-voice',f'{base}/tts/open_ar_v1/{name}','rafeeq_app/lib/features/library/data/tts/open_voice.dart')
for id in ['afasy','ajami','abkar','muaiqly','sudais']:
    add('ruqyah',f'{base}/ruqyah/{id}.mp3','rafeeq_app/lib/features/ruqyah/data/ruqyah_catalog.dart')
add('ruqyah',f'{base}/ruqyah/tarteel_hadi.m4a','rafeeq_app/lib/features/ruqyah/data/ruqyah_catalog.dart')
unique={x['url']:x for x in items}
(out/'endpoint-inventory.json').write_text(json.dumps(list(unique.values()),ensure_ascii=False,indent=2),encoding='utf-8')
def probe(item):
    start=time.monotonic()
    result=subprocess.run(['curl.exe','-sS','-I','-L','--max-time','25','-A','RafeeqAudit/2026-10-09 (https://github.com/tito423/Rafeeq-Al-Darb)',item['url']],capture_output=True,text=True)
    headers=result.stdout
    codes=re.findall(r'^HTTP/\S+ (\d+)',headers,re.M)
    types=re.findall(r'^content-type:\s*(.+)',headers,re.M|re.I)
    sizes=re.findall(r'^content-length:\s*(\d+)',headers,re.M|re.I)
    code=int(codes[-1]) if codes else 0
    mime=types[-1].strip() if types else ''
    return dict(item,http=code,mime=mime,content_length=int(sizes[-1]) if sizes else None,curl_exit=result.returncode,error=result.stderr.strip(),seconds=round(time.monotonic()-start,3),ok=result.returncode==0 and code in [200,206] and 'text/html' not in mime)
results=[json.loads(s) for s in (out/'endpoints.jsonl').read_text(encoding='utf-8').splitlines()] if (out/'endpoints.jsonl').exists() else []
checked={x['url'] for x in results}
pending=[x for x in unique.values() if x['url'] not in checked]
print('Requests remaining:',len(pending),'already checked:',len(checked),flush=True)
with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
    for i,res in enumerate(pool.map(probe,pending),1):
        results.append(res)
        with (out/'endpoints.jsonl').open('a',encoding='utf-8') as f: f.write(json.dumps(res,ensure_ascii=False)+'\n')
        if i%100==0: print('Checked:',i,'failures:',sum(not r['ok'] for r in results),flush=True)
print(json.dumps(dict(total=len(results),failures=sum(not r['ok'] for r in results),by_kind={k:sum(r['kind']==k for r in results) for k in sorted(set(r['kind'] for r in results))}),indent=2),flush=True)
