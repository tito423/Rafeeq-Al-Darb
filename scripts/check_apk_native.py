"""Fail the release build when the APK carries the wrong ONNX Runtime.

Two plugins ship lib/<abi>/libonnxruntime.so: `onnxruntime` (ORT 1.15.1, the
book reader's voice) and `sherpa_onnx` («رفيق»'s recogniser, ORT 1.28.2, C API
28). Only sherpa's serves both; the first 3.69.0 build packaged the old one for
ARM and «رفيق» would have died on every phone. Called by
build_github_release.bat; compares each ABI's packaged ORT version with
sherpa's (the packaged copy is symbol-stripped, so its bytes differ).
"""
import os
import re
import sys
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
APK = os.path.join(ROOT, "rafeeq_app", "build", "app", "outputs", "flutter-apk", "app-release.apk")
PUB = os.environ.get("PUB_CACHE") or os.path.join(os.environ["LOCALAPPDATA"], "Pub", "Cache")
HOSTED = os.path.join(PUB, "hosted", "pub.dev")
ABIS = {"arm64-v8a": "sherpa_onnx_android_arm64", "armeabi-v7a": "sherpa_onnx_android_armeabi",
        "x86_64": "sherpa_onnx_android_x86_64"}
NUL = b"\x00"
VERSION = re.compile(NUL + rb"(1\.\d{2}\.\d+)" + NUL)


def _version(b):
    m = VERSION.search(b)
    return m.group(1).decode() if m else None


def main():
    bad = 0
    with zipfile.ZipFile(APK) as z:
        for abi, plugin in ABIS.items():
            dirs = sorted(d for d in os.listdir(HOSTED) if d.startswith(plugin + "-"))
            want = os.path.join(HOSTED, dirs[-1], "android", "src", "main", "jniLibs", abi, "libonnxruntime.so")
            got = z.read(f"lib/{abi}/libonnxruntime.so")
            ver = _version(open(want, "rb").read())
            ok = ver is not None and _version(got) == ver
            print(f"{abi}: {'sherpa ORT' if ok else 'WRONG ORT'} {_version(got)} ({len(got):,} B)")
            bad += not ok
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
