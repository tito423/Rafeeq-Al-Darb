from pathlib import Path
import json,subprocess,concurrent.futures,hashlib,gzip,tempfile,time,collections
root=Path('E:/My Projects/Rafiq-Al-Darb');out=root/'docs/audits/evidence/2026-10-09'
cache=Path(tempfile.gettempdir())/'rafeeq_audit_content_20261009';cache.mkdir(exist_ok=True)
primary={x['url']:x for x in map(json.loads,(out/'endpoints.jsonl').read_text().splitlines())}
mirrors=list(map(json.loads,(out/'mirrors.jsonl').read_text().splitlines()))
selected=[m for m in mirrors if m['kind'] in ['mirror-book','mirror-translation','mirror-hadeethenc','mirror-hadith','mirror-sciences']]
# Half-completed downloads are never accepted on reruns.
def fetch(url):
    token=hashlib.sha256(url.encode()).hexdigest();dest=cache/(token+'.bin')
    if not dest.exists():
        part=cache/(token+'.part')
        r=subprocess.run(['curl.exe','-sS','-L','--fail','--compressed','--max-time','120','--max-filesize','104857600','-o',str(part),'-w','%{http_code}',url],capture_output=True,text=True)
        if r.returncode or r.stdout not in ['200','206']:return {'ok':False,'curl_exit':r.returncode,'http':r.stdout[-3:]}
        part.replace(dest)
    data=dest.read_bytes();wire=len(data)
    if data[:2]==b'\x1f\x8b':data=gzip.decompress(data)
    return {'ok':True,'download_bytes':wire,'decoded_bytes':len(data),'sha256_decoded':hashlib.sha256(data).hexdigest(),'magic':data[:4].hex()},data
counts=[7,286,200,176,120,165,206,75,129,109,123,111,43,52,99,128,111,110,98,135,112,78,118,64,77,227,93,88,69,60,34,30,73,54,45,83,182,88,75,85,54,53,89,59,37,35,38,29,18,45,60,49,62,55,78,96,29,22,24,13,14,11,11,18,12,12,30,52,52,44,28,28,20,56,40,31,50,40,46,42,29,19,36,25,22,17,19,26,30,20,15,21,11,8,8,19,5,8,8,11,11,8,3,9,5,4,7,3,6,3,5,4,5,6]
refs={f'{s}:{a}' for s,n in enumerate(counts,1) for a in range(1,n+1)}
assert len(refs)==6236

def compare(m):
    result={'kind':m['kind'],'original':m['original'],'mirror':m['url'],'path':m['path'],'line':m['line']}
    try:
        p=fetch(m['original']);q=fetch(m['url'])
        if not isinstance(p,tuple) or not isinstance(q,tuple):
            result.update(ok=False,primary=p if not isinstance(p,tuple) else p[0],mirror_result=q if not isinstance(q,tuple) else q[0]);return result
        a,abytes=p;b,bbytes=q;result.update(primary=a,mirror_result=b,identical_decoded=a['sha256_decoded']==b['sha256_decoded'])
        validation={}
        if m['kind']=='mirror-translation':
            doc=json.loads(abytes);verses=doc['verses'];keys=set(verses)
            validation={'verse_count':len(verses),'missing_refs':sorted(refs-keys),'extra_refs':sorted(keys-refs),'empty_or_non_string_refs':[k for k,v in verses.items() if not isinstance(v,str) or not v.strip()],'lang':doc.get('lang'),'edition':doc.get('edition'),'translator':doc.get('translator')}
            validation['ok']=not any(validation[k] for k in ['missing_refs','extra_refs','empty_or_non_string_refs'])
        elif m['kind']=='mirror-book':
            doc=json.loads(abytes);validation={'type':type(doc).__name__,'top_level_keys':list(doc)[:20] if isinstance(doc,dict) else [],'ok':isinstance(doc,(dict,list))}
        else:
            import zipfile,io
            z=zipfile.ZipFile(io.BytesIO(abytes));bad=z.testzip();validation={'entries':z.namelist(),'crc_bad_entry':bad,'ok':bad is None}
        result.update(validation=validation,ok=result['identical_decoded'] and validation['ok'])
    except Exception as e:result.update(ok=False,error_type=type(e).__name__)
    return result
existing=[json.loads(s) for s in (out/'content-full-comparison.jsonl').read_text(encoding='utf-8').splitlines()] if (out/'content-full-comparison.jsonl').exists() else []
finished={x['original'] for x in existing if x['ok']};pending=[m for m in selected if m['original'] not in finished]
print('Full content pairs selected',len(selected),'pending',len(pending),flush=True)
with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:
    for i,r in enumerate(pool.map(compare,pending),1):
        existing.append(r)
        with (out/'content-full-comparison.jsonl').open('a',encoding='utf-8') as f:f.write(json.dumps(r,ensure_ascii=False)+'\n')
        if i%25==0:print('Compared',i,'failures',sum(not x['ok'] for x in existing),flush=True)
latest={x['original']:x for x in existing};summary={'selected':len(selected),'completed':len(latest),'failures':[x for x in latest.values() if not x['ok']],'counts_by_kind':dict(collections.Counter(x['kind'] for x in latest.values())),'scope':'Full decoded SHA256 comparison; JSON structural and translation reference coverage; ZIP CRC only, not semantic religious accuracy.'}
(out/'content-full-comparison-summary.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2),encoding='utf-8');print(json.dumps(summary,ensure_ascii=False),flush=True)
