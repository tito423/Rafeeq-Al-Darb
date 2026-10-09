from pathlib import Path
import subprocess,json,re
root=Path('E:/My Projects/Rafiq-Al-Darb')
values={}
for line in (root/'scripts/.env').read_text(encoding='utf-8-sig').splitlines():
    if '=' not in line or line.lstrip().startswith('#'): continue
    key,value=line.split('=',1)
    if 'R2' in key.upper() and ('KEY' in key.upper() or 'SECRET' in key.upper()):
        value=value.strip().strip(chr(34)).strip(chr(39))
        if len(value)>=16: values[key.strip()]=value.encode()
result=[]
for commit in ['3747f715','ecbb820d','eae5036d']:
    patch=subprocess.run(['git','show','--format=','--no-ext-diff',commit],cwd=root,capture_output=True).stdout
    matches=[key for key,val in values.items() if val in patch]
    result.append({'commit':commit,'current_R2_credential_names_matched':matches,'count':len(matches)})
tracked=subprocess.check_output(['git','ls-files'],cwd=root,text=True).splitlines()
current=[]
for name in tracked:
    try: data=(root/name).read_bytes()
    except OSError: continue
    for key,value in values.items():
        if value in data: current.append({'file':name,'credential_name':key})
doc={'scope':'Compare current R2 credential values to the three previously reported public commits and the complete tracked working tree; credential values are never emitted. This is not a complete scan of all historical Git objects.','current_credential_count':len(values),'historical_matches':result,'tracked_matches':current}
(root/'docs/audits/evidence/2026-10-09/credential-check.json').write_text(json.dumps(doc,indent=2),encoding='utf-8')
print(json.dumps(doc,indent=2))
