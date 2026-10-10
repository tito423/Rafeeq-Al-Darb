"""Read current channel metadata from the channel page itself, not a snippet."""
from pathlib import Path
import concurrent.futures, importlib.util, json, re, subprocess, tempfile

root = Path('E:/My Projects/Rafiq-Al-Darb')
out = root / 'docs/audits/evidence/2026-10-09'
spec = importlib.util.spec_from_file_location('channel_metadata', root/'scripts/verify_youtube_channels.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
code = (root/'rafeeq_app/lib/features/channels/data/islamic_channels.dart').read_text(encoding='utf-8')
items = [dict(id=m[1], channel_id=re.search(r"channelId:\s*'([^']+)'",m[2])[1])
         for m in re.finditer(r"IslamicChannel\(\s*id:\s*'([^']+)',(.*?)\n  \)",code,re.S)]

def check(item):
    url = 'https://www.youtube.com/channel/'+item['channel_id']
    with tempfile.TemporaryDirectory(prefix='rafeeq_channel_') as directory:
        dest = Path(directory)/'page.html'
        process = subprocess.run(['curl.exe','-sS','-L','--max-time','45','--max-filesize','8388608',
            '-A',module.UA['User-Agent'],'-H','Accept-Language: ar,en;q=0.8','-o',str(dest),'-w','%{http_code}',url],
            capture_output=True,text=True)
        data = dest.read_text(encoding='utf-8',errors='replace') if dest.exists() else ''
        metadata = module.extract(data)
        return dict(item,url=url,http=process.stdout[-3:],curl_exit=process.returncode,
                    metadata=metadata,ok=process.returncode==0 and process.stdout[-3:]=='200'
                    and metadata['channel_id']==item['channel_id'] and bool(metadata['title']),
                    scope='Channel ID/title from current primary page; no independent assertion about official ownership.')

with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
    result = list(pool.map(check,items))
(out/'channel-identities.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
print('Channel identities',len(result),'verified',sum(x['ok'] for x in result),flush=True)
for item in result:
    print(item['id'],item['http'],item['metadata']['channel_id'],item['ok'],flush=True)
