"""Upload the open Arabic voice (sample B) to R2 as a download pack.

The owner chose it for its tafkhim of the divine name. Three ONNX files from
nipponjo/tts_arabic (Hugging Face nipponjo/tts-arabic-onnx), trained on the
Arabic Speech Corpus (CC BY 4.0); the weights state no licence, and the
owner's decision on that is recorded in CONTENT-LICENSES.md.

    py -3 scripts/r2_upload_tts_voice.py

Verifies each object afterwards with a ranged GET on the public endpoint.
"""
import os
import sys
import urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from r2_common import BUCKET, r2_client  # noqa: E402

SRC = os.path.join(os.path.dirname(sys.executable), "Lib", "site-packages",
                   "tts_arabic", "data")
import sys as _sys
FILES = _sys.argv[1:] or ["fp_ms.onnx", "vocos44.onnx"]
PUBLIC = "https://pub-39dbef68a1a845d5ba669b43a59516b9.r2.dev"


def main():
    s3 = r2_client()
    for name in FILES:
        path = os.path.join(SRC, name)
        key = "tts/open_ar_v1/" + name
        size = os.path.getsize(path)
        s3.upload_file(path, BUCKET, key,
                       ExtraArgs={"ContentType": "application/octet-stream"})
        req = urllib.request.Request(PUBLIC + "/" + key, headers={
            "Range": "bytes=0-1023", "User-Agent": "RafeeqAlDarb/3.36 upload-check"})
        with urllib.request.urlopen(req) as r:
            got = len(r.read())
            total = r.headers.get("Content-Range", "")
        print(f"{key}: local {size} bytes; public ranged GET {r.status} "
              f"{got} bytes, {total}")


if __name__ == "__main__":
    main()
