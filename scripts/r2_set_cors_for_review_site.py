"""Let the content-review site read the library books straight from R2.

The review site is served from https://tito423.github.io, the books from the
bucket's public r2.dev endpoint. A browser will not read one origin from the
other without the bucket saying so, and the bucket had NO CORS rule at all -
checked before this was written, not assumed.

Only GET and HEAD, only from the review site's own origin and localhost (the
local server the site is checked on before publishing), and only the two
prefixes the site actually reads. The app itself is unaffected: a native HTTP
client does not consult CORS.

Usage:  py -3 scripts/r2_set_cors_for_review_site.py [--show]
"""
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from r2_common import BUCKET, r2_client  # noqa: E402

RULES = [
    {
        'AllowedOrigins': [
            'https://tito423.github.io',
            'http://localhost:8765',
            'http://127.0.0.1:8765',
        ],
        'AllowedMethods': ['GET', 'HEAD'],
        'AllowedHeaders': ['range', 'content-type'],
        'ExposeHeaders': ['content-length', 'content-type'],
        'MaxAgeSeconds': 3600,
    }
]


def main():
    s3 = r2_client()
    if '--show' not in sys.argv:
        s3.put_bucket_cors(Bucket=BUCKET,
                           CORSConfiguration={'CORSRules': RULES})
        print('CORS set on', BUCKET)
    got = s3.get_bucket_cors(Bucket=BUCKET)['CORSRules']
    for r in got:
        print('  origins :', r.get('AllowedOrigins'))
        print('  methods :', r.get('AllowedMethods'))
        print('  maxage  :', r.get('MaxAgeSeconds'))


main()
