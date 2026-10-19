"""Upload the book reader's Arabic voice to R2 as a download pack.

Supertone's Supertonic-3 in the int8 form sherpa-onnx publishes
(github.com/k2-fsa/sherpa-onnx releases, tag tts-models,
sherpa-onnx-supertonic-3-tts-int8-2026-05-11.tar.bz2). Code MIT; weights
BigScience OpenRAIL-M, whose text travels with the pack as LICENSE.txt
(fetched from huggingface.co/Supertone/supertonic-3). Chosen 2026-10-20 by
measurement - see the class comment of OpenVoice (open_voice.dart).

It replaced the FastPitch+Vocos voice (nipponjo/tts_arabic) that lived under
tts/open_ar_v1/; that folder is left on the bucket for installed copies of
older builds.

    py -3 scripts/r2_upload_tts_voice.py <unpacked sherpa-onnx folder> <LICENSE.txt>

Verifies each object afterwards with a ranged GET on the public endpoint and
refuses to finish unless every size matches.
"""
import os
import sys
import urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from r2_common import BUCKET, r2_client  # noqa: E402

PREFIX = "tts/supertonic3_ar_v1/"
FILES = ["duration_predictor.int8.onnx", "text_encoder.int8.onnx",
         "vector_estimator.int8.onnx", "vocoder.int8.onnx", "tts.json",
         "unicode_indexer.bin", "voice.bin"]
PUBLIC = "https://pub-39dbef68a1a845d5ba669b43a59516b9.r2.dev"


def main():
    src, licence = sys.argv[1], sys.argv[2]
    s3 = r2_client()
    items = [(os.path.join(src, f), f) for f in FILES] + [(licence, "LICENSE.txt")]
    bad = 0
    for path, name in items:
        key = PREFIX + name
        size = os.path.getsize(path)
        s3.upload_file(path, BUCKET, key, ExtraArgs={
            "ContentType": "text/plain; charset=utf-8" if name.endswith(".txt")
            else "application/octet-stream"})
        req = urllib.request.Request(PUBLIC + "/" + key, headers={
            "Range": "bytes=0-1023", "User-Agent": "RafeeqAlDarb/3.90 upload-check"})
        with urllib.request.urlopen(req) as r:
            got = len(r.read())
            total = r.headers.get("Content-Range", "")
            status = r.status
        ok = status == 206 and total.endswith("/" + str(size))
        bad += not ok
        print(f"{'OK ' if ok else 'BAD'} {key}: local {size} B; public {status} "
              f"{got} B, {total}")
    if bad:
        sys.exit(f"{bad} object(s) did not verify")


if __name__ == "__main__":
    main()
