"""Upload legal/privacy.html to the bucket the app links to.

    py -3 scripts/r2_upload_privacy.py

`AppConfig.privacyPolicyUrl` is `<contentBaseUrl>/legal/privacy.html`, so
the page the app and Play show is this object. Plain HTML, no
Content-Encoding (trap #6's rule applies to anything the app fetches).
"""
import os

from r2_common import r2_client, BUCKET

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

if __name__ == '__main__':
    with open(os.path.join(ROOT, 'legal', 'privacy.html'), 'rb') as f:
        body = f.read()
    r2_client().put_object(Bucket=BUCKET, Key='legal/privacy.html', Body=body,
                           ContentType='text/html; charset=utf-8')
    print('uploaded', len(body))
