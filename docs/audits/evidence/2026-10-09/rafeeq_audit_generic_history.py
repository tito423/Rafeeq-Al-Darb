from pathlib import Path
import subprocess,json,re
root=Path('E:/My Projects/Rafiq-Al-Darb');out=root/'docs/audits/evidence/2026-10-09';values={}
for line in (root/'scripts/.env').read_text(encoding='utf-8-sig').splitlines():
 if '=' not in line or line.lstrip().startswith('#'):continue
 key,value=line.split('=',1);value=value.strip().strip(chr(34)).strip(chr(39))
 if any(x in key.upper() for x in ['KEY','TOKEN','SECRET']) and len(value)>=16:values[key.strip()]=value.encode()
patterns={'private-key':re.compile(rb'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----'),'github-token':re.compile(rb'gh[pousr]_[A-Za-z0-9]{30,}'),'github-fine-grained':re.compile(rb'github_pat_[A-Za-z0-9_]{50,}'),'aws-access-id':re.compile(rb'AKIA[0-9A-Z]{16}')}
ext={'.dart','.py','.ps1','.bat','.sh','.ts','.js','.cjs','.json','.yaml','.yml','.toml','.md','.txt','.env','.properties','.sql','.xml','.kts','.kt','.pem','.key','.gradle'};targets={}
for row in subprocess.check_output(['git','rev-list','--objects','--all'],cwd=root,text=True).splitlines():
 parts=row.split(' ',1)
 if len(parts)==2 and (Path(parts[1]).suffix.lower() in ext or '.env' in Path(parts[1]).name):targets[parts[0]]=parts[1]
p=subprocess.Popen(['git','cat-file','--batch'],cwd=root,stdin=subprocess.PIPE,stdout=subprocess.PIPE);matches=[];count=total=0
for oid,name in targets.items():
 p.stdin.write((oid+'\n').encode());p.stdin.flush();head=p.stdout.readline().decode().split()
 if len(head)!=3:continue
 size=int(head[2]);b=p.stdout.read(size);p.stdout.read(1)
 if head[1]!='blob':continue
 count+=1;total+=size
 hits=[('current-value:'+k,v) for k,v in values.items() if v in b]+[(kind,pat) for kind,pat in patterns.items() if pat.search(b)]
 for kind,needle in hits:
  for n,line in enumerate(b.splitlines(),1):
   if (needle in line if isinstance(needle,bytes) else needle.search(line)):matches.append({'blob':oid,'path':name,'line':n,'kind':kind})
 if count%3000==0:print('Scanned',count,flush=True)
p.stdin.close();p.wait();d={'scope':'Every reachable text-source/config/document blob with listed extensions; current local key/token/secret values plus explicit private-key/GitHub/AWS patterns. Values are never emitted; binary and unknown-format secrets are outside this bounded scan.','extensions':sorted(ext),'current_local_credential_names_checked':list(values),'blobs_scanned':count,'bytes_scanned':total,'matches':matches};(out/'generic-history-secrets.json').write_text(json.dumps(d,indent=2));print(json.dumps({'blobs':count,'bytes':total,'match_locations':len(matches),'kinds':sorted(set(x['kind'] for x in matches))}))
