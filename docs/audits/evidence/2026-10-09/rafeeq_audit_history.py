from pathlib import Path
import subprocess,json,re
root=Path('E:/My Projects/Rafiq-Al-Darb');out=root/'docs/audits/evidence/2026-10-09'
values={}
for line in (root/'scripts/.env').read_text(encoding='utf-8-sig').splitlines():
    if '=' not in line or line.lstrip().startswith('#'):continue
    key,value=line.split('=',1);value=value.strip().strip(chr(34)).strip(chr(39))
    if ('R2' in key.upper() and ('KEY' in key.upper() or 'SECRET' in key.upper())) and len(value)>=16:values[key.strip()]=value.encode()
objects=subprocess.check_output(['git','rev-list','--objects','--all'],cwd=root,text=True).splitlines()
extensions={'.dart','.py','.ps1','.bat','.sh','.ts','.js','.cjs','.json','.yaml','.yml','.toml','.md','.txt','.env','.properties','.sql','.xml','.kts'}
targets={}
for line in objects:
    parts=line.split(' ',1)
    if len(parts)==2 and (Path(parts[1]).suffix.lower() in extensions or '.env' in Path(parts[1]).name):targets[parts[0]]=parts[1]
p=subprocess.Popen(['git','cat-file','--batch'],cwd=root,stdin=subprocess.PIPE,stdout=subprocess.PIPE)
matches=[];scanned=0;bytes_scanned=0
for oid,name in targets.items():
    p.stdin.write((oid+'\n').encode());p.stdin.flush()
    head=p.stdout.readline().decode().split()
    if len(head)!=3:continue
    size=int(head[2]);data=p.stdout.read(size);p.stdout.read(1)
    if head[1]!='blob':continue
    scanned+=1;bytes_scanned+=size
    for key,value in values.items():
        if value in data:
            for n,line in enumerate(data.splitlines(),1):
                if value in line:matches.append({'blob':oid,'path':name,'line':n,'credential_name':key})
    if scanned%2000==0:print('Historical text blobs scanned',scanned,flush=True)
p.stdin.close();p.wait()
doc={'scope':'Every text-source/config/document blob with supported extension reachable from local Git refs (--all), compared to current R2 credential values. No secret values emitted; other unrelated keys are not covered by value matching.','blobs_scanned':scanned,'bytes_scanned':bytes_scanned,'matches':matches}
for commit in ['3747f715','ecbb820d','eae5036d']:
    entries=subprocess.check_output(['git','ls-tree','-r',commit],cwd=root,text=True).splitlines()
    lines=[]
    for entry in entries:
        meta,name=entry.split('\t',1);oid=meta.split()[2]
        for match in matches:
            if match['blob']==oid:lines.append(dict(match,path=name))
    doc.setdefault('known_commit_locations',[]).append({'commit':commit,'matches':lines})
(out/'credential-history.json').write_text(json.dumps(doc,indent=2),encoding='utf-8')
print(json.dumps({'blobs_scanned':scanned,'bytes_scanned':bytes_scanned,'matching_locations':len(matches),'known_commits':doc['known_commit_locations']},indent=2))
