from pathlib import Path
import zipfile,json,collections,re,subprocess,hashlib,datetime
r=Path('.').resolve();o=r/'docs/audits/evidence/2026-10-09';p=r/'rafeeq_app/build/app/outputs/flutter-apk/app-release.apk';vals={}
for line in (r/'scripts/.env').read_text(encoding='utf-8-sig').splitlines():
 if '=' not in line or line.lstrip().startswith('#'):continue
 k,v=line.split('=',1);v=v.strip().strip(chr(34)).strip(chr(39))
 if any(x in k.upper() for x in ['SECRET','TOKEN','KEY']) and len(v)>=16:vals[k.strip()]=v.encode()
groups=collections.defaultdict(lambda:{'compressed_bytes':0,'uncompressed_bytes':0,'entries':0});hits=[]
patterns={'private-key':rb'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----','github-token':rb'gh[pousr]_[A-Za-z0-9]{30,}','github-fine-grained':rb'github_pat_[A-Za-z0-9_]{50,}','aws-access-id':rb'AKIA[0-9A-Z]{16}'};generic=[]
with zipfile.ZipFile(p) as z:
 for i in z.infolist():
  group='/'.join(i.filename.split('/')[:2]) if i.filename.startswith('lib/') else ('flutter-assets' if i.filename.startswith('assets/flutter_assets/') else i.filename.split('/')[0]);g=groups[group];g['compressed_bytes']+=i.compress_size;g['uncompressed_bytes']+=i.file_size;g['entries']+=1
  b=z.read(i)
  for k,v in vals.items():
   if v in b:hits.append({'entry':i.filename,'credential_name':k})
  for kind,pat in patterns.items():
   if re.search(pat,b):generic.append({'entry':i.filename,'kind':kind})
 largest=sorted(z.infolist(),key=lambda i:i.compress_size,reverse=True)[:35]
 d={'apk_bytes':p.stat().st_size,'sha256':hashlib.file_digest(p.open('rb'),'sha256').hexdigest(),'groups':dict(groups),'largest_entries':[{'path':i.filename,'compressed_bytes':i.compress_size,'bytes':i.file_size} for i in largest],'current_local_credential_names_checked':list(vals),'current_credential_hits':hits,'generic_pattern_hits':generic,'limitations':'Known current local keys/tokens plus explicit private-key/GitHub/AWS patterns only; absence is not a proof that all possible secrets are absent. Audit APK is debug signed and not published.'}
(o/'apk-census-and-secrets.json').write_text(json.dumps(d,indent=2));print('APK bytes',d['apk_bytes'],'known credential hits',len(hits),'generic pattern hits',len(generic))
failed=[json.loads(s) for s in (o/'mirrors.jsonl').read_text(encoding='utf-8').splitlines() if not json.loads(s)['ok']];retry=[]
for i in failed:
 a=subprocess.run(['curl.exe','-sS','-I','-L','--max-time','30',i['url']],capture_output=True,text=True);codes=re.findall(r'^HTTP/\S+ (\d+)',a.stdout,re.M);sizes=re.findall(r'^content-length:\s*(\d+)',a.stdout,re.M|re.I);retry.append({'url':i['url'],'previous_http':i['http'],'http':int(codes[-1]) if codes else 0,'bytes':int(sizes[-1]) if sizes else None,'curl_exit':a.returncode})
(o/'mirror-retries.json').write_text(json.dumps(retry,indent=2));print('Sanitized retries',retry)
