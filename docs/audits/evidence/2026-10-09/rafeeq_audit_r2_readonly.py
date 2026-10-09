import sys,json
from pathlib import Path
sys.path.insert(0,'E:/My Projects/Rafiq-Al-Darb/scripts')
from r2_common import r2_client,BUCKET
doc={'operation':'ListObjectsV2 MaxKeys=1 on configured bucket; read only; no object names or credentials recorded','authenticated_list_success':False}
try:
    result=r2_client().list_objects_v2(Bucket=BUCKET,MaxKeys=1)
    doc['http_status']=result['ResponseMetadata']['HTTPStatusCode']
    doc['authenticated_list_success']=doc['http_status']==200
except Exception as e:
    doc['error_class']=type(e).__name__
    if hasattr(e,'response'):doc['error_code']=e.response.get('Error',{}).get('Code')
Path('E:/My Projects/Rafiq-Al-Darb/docs/audits/evidence/2026-10-09/credential-live-readonly.json').write_text(json.dumps(doc,indent=2),encoding='utf-8')
print(json.dumps(doc))
