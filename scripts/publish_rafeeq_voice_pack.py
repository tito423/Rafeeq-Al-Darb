"""Publish «رفيق»'s voice pack - the offline speech recogniser the assistant
downloads once (owner, 2026-09-27: «أفضل نموذج … في التحميلات والإعدادات،
ينزله أول مرة بس، ولو منزلوش الأفضل مايشتغلش»).

    py -3 scripts/publish_rafeeq_voice_pack.py

Chosen by measurement (TASK_FOLLOWUP 2026-09-27 18:50, E:\\DevEnv\\asr):
Meta's omnilingual-asr 300M CTC v2, int8, as converted by sherpa-onnx
(Apache-2.0, 1600+ languages incl. all seven of the app's) - 366 MB, ~0.5 s a
command on the PC, the best Arabic of the four tried - and silero VAD v5
(MIT, 2 MB), which finds where speech starts and ends.

Uploaded to R2 under asr/ and to the content-mirror GitHub release under the
same key with / -> __ (ContentMirrors' fallback name). Prints the sizes and
SHA-256 the app checks after download.
"""
import hashlib
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = r"E:\DevEnv\asr"
OMNI = os.path.join(SRC, "sherpa-onnx-omnilingual-asr-1600-languages-300M-ctc-v2-int8-2026-02-05")
AR = os.path.join(SRC, "fastconformer_ar")
# «دقة أعلى في العربية» (2026-09-30): NVIDIA stt_ar_fastconformer_hybrid_large_pcd
# v1.0 (CC BY 4.0), CTC int8 for sherpa-onnx from huggingface.co/krut42/
# voice-fastconformer-ar-ctc-int8. Replaces the whisper-turbo pack (too slow).
#     py -3 scripts/publish_rafeeq_voice_pack.py ar
AR_FILES = {
    f"asr/rafeeq_ar_v1/{n}": os.path.join(AR, n) for n in ("model.int8.onnx", "tokens.txt")
}
FILES = {
    "asr/rafeeq_v1/model.int8.onnx": os.path.join(OMNI, "model.int8.onnx"),
    "asr/rafeeq_v1/tokens.txt": os.path.join(OMNI, "tokens.txt"),
    "asr/rafeeq_v1/silero_vad.onnx": os.path.join(SRC, "silero_vad_v5.onnx"),
}


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for b in iter(lambda: f.read(1 << 20), b""):
            h.update(b)
    return h.hexdigest()


def main():
    sys.path.insert(0, HERE)
    from r2_common import BUCKET, r2_client

    r2 = r2_client()
    out = os.path.join(HERE, "out", "rafeeq_voice_pack")
    os.makedirs(out, exist_ok=True)
    files = {"ar": AR_FILES}.get(
        (sys.argv[1:] or [""])[0], FILES)
    for key, path in files.items():
        size = os.path.getsize(path)
        print(key, size, sha256(path))
        r2.upload_file(path, BUCKET, key, ExtraArgs={
            "ContentType": "text/plain; charset=utf-8" if key.endswith(".txt")
            else "application/octet-stream",
            "CacheControl": "max-age=31536000",
        })
        mirror = os.path.join(out, key.replace("/", "__"))
        if not os.path.exists(mirror):
            os.link(path, mirror) if os.name != "nt" else __import__("shutil").copyfile(path, mirror)
        subprocess.run(["gh", "release", "upload", "content-mirror", mirror,
                        "--clobber", "-R", "tito423/Rafeeq-Al-Darb"], check=True)
        print("  uploaded: R2 + content-mirror")


if __name__ == "__main__":
    main()
