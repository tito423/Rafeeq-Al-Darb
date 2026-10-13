"""Fail the release build when the APK carries the wrong ONNX Runtime.

Two plugins ship lib/<abi>/libonnxruntime.so: `onnxruntime` (ORT 1.15.1, the
book reader's voice) and `sherpa_onnx` («رفيق»'s recogniser, ORT 1.28.2, C API
28). Only sherpa's serves both; the first 3.69.0 build packaged the old one for
ARM and «رفيق» would have died on every phone. Called by
build_github_release.bat; compares each ABI's packaged ORT version with
sherpa's (the packaged copy is symbol-stripped, so its bytes differ).
"""
import argparse
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
MACHINES = {"armeabi-v7a": 40, "arm64-v8a": 183, "x86_64": 62}
REQUIRED = ("libflutter.so", "libapp.so", "libonnxruntime.so")


def _version(b):
    m = VERSION.search(b)
    return m.group(1).decode() if m else None


def check_apk(apk, expected_abis, hosted=HOSTED):
    """Reject partial engines, additional ABIs and incompatible native libraries."""
    expected = set(expected_abis)
    if not expected or not expected.issubset(ABIS):
        raise ValueError("Expected ABIs must be a nonempty supported set")
    results = []
    with zipfile.ZipFile(apk) as z:
        native = [n for n in z.namelist() if n.startswith("lib/") and n.endswith(".so")]
        if len(native) != len(set(native)):
            raise ValueError("Duplicate native library entries")
        actual = {n.split("/")[1] for n in native}
        if actual != expected:
            raise ValueError(f"ABI mismatch: expected {sorted(expected)}, found {sorted(actual)}")
        for abi in sorted(expected):
            for name in REQUIRED:
                if f"lib/{abi}/{name}" not in native:
                    raise ValueError(f"Missing {abi}/{name}")
            for name in (n for n in native if n.split("/")[1] == abi):
                header = z.read(name)[:20]
                if len(header) < 20 or header[:4] != b"\x7fELF" or header[5] not in (1, 2):
                    raise ValueError(f"Invalid ELF header: {name}")
                machine = int.from_bytes(header[18:20], "little" if header[5] == 1 else "big")
                if machine != MACHINES[abi]:
                    raise ValueError(f"Wrong ELF machine {machine}: {name}")
            plugin = ABIS[abi]
            dirs = sorted(d for d in os.listdir(hosted) if d.startswith(plugin + "-"))
            if not dirs:
                raise ValueError(f"Sherpa reference unavailable: {plugin}")
            want = os.path.join(hosted, dirs[-1], "android", "src", "main", "jniLibs", abi, "libonnxruntime.so")
            got = z.read(f"lib/{abi}/libonnxruntime.so")
            with open(want, "rb") as reference:
                ver = _version(reference.read())
            if ver != "1.28.2" or _version(got) != ver:
                raise ValueError(f"WRONG ORT {abi}: packaged {_version(got)}, reference {ver}, required 1.28.2")
            results.append(f"{abi}: engine + app + sherpa ORT {ver} ({len(got):,} B)")
    return results


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apk", default=APK, help="APK to verify; defaults to the universal release")
    parser.add_argument("--abi", action="append", choices=tuple(ABIS), help="Expected ABI; repeat for multiple ABIs, defaults to all three")
    args = parser.parse_args(argv)
    try:
        for result in check_apk(args.apk, args.abi or ABIS):
            print(result)
    except (ValueError, OSError, zipfile.BadZipFile) as failure:
        print(f"Native APK check failed: {failure}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
