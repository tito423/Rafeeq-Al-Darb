"""Local packaging regressions derived from the actual signed split APK.

Run after building splits: py -3 -m unittest discover -s scripts -p test_check_apk_native.py
RAFEEQ_NATIVE_TEST_APK can select another actual signed x86_64 split.
"""
import contextlib
import io
import os
from pathlib import Path
import tempfile
import unittest
import zipfile

import check_apk_native as native


class NativeApkChecks(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        source = Path(os.environ.get("RAFEEQ_NATIVE_TEST_APK", Path(native.ROOT) / ".local-audit/phase2/A48-split-x86_64.apk"))
        with zipfile.ZipFile(source) as apk:
            cls.libraries = {f"lib/x86_64/{name}": apk.read(f"lib/x86_64/{name}") for name in native.REQUIRED}

    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix="rafeeq-native-apk-test-")
        self.addCleanup(self.directory.cleanup)
        self.apk = Path(self.directory.name) / "derived.apk"

    def write(self, libraries=None):
        with zipfile.ZipFile(self.apk, "w") as apk:
            for name, data in (self.libraries if libraries is None else libraries).items():
                apk.writestr(name, data)

    def test_actual_split_passes(self):
        self.write()
        self.assertEqual(len(native.check_apk(self.apk, ["x86_64"])), 1)

    def test_partial_universal_is_rejected(self):
        self.write()
        with self.assertRaisesRegex(ValueError, "ABI mismatch"):
            native.check_apk(self.apk, native.ABIS)

    def test_additional_plugin_abi_is_rejected(self):
        libraries = dict(self.libraries)
        libraries["lib/arm64-v8a/libonnxruntime.so"] = libraries["lib/x86_64/libonnxruntime.so"]
        self.write(libraries)
        with self.assertRaisesRegex(ValueError, "ABI mismatch"):
            native.check_apk(self.apk, ["x86_64"])

    def test_each_required_library_is_mandatory(self):
        for name in native.REQUIRED:
            with self.subTest(name=name):
                libraries = dict(self.libraries)
                del libraries[f"lib/x86_64/{name}"]
                self.write(libraries)
                with self.assertRaisesRegex(ValueError, "Missing"):
                    native.check_apk(self.apk, ["x86_64"])

    def test_old_runtime_is_rejected(self):
        libraries = dict(self.libraries)
        name = "lib/x86_64/libonnxruntime.so"
        original = libraries[name]
        libraries[name] = original.replace(b"\x001.28.2\x00", b"\x001.15.1\x00")
        self.assertNotEqual(original, libraries[name])
        self.write(libraries)
        with self.assertRaisesRegex(ValueError, "WRONG ORT"):
            native.check_apk(self.apk, ["x86_64"])

    def test_wrong_machine_is_rejected(self):
        libraries = dict(self.libraries)
        name = "lib/x86_64/libapp.so"
        altered = bytearray(libraries[name])
        altered[18:20] = (183).to_bytes(2, "little")
        libraries[name] = altered
        self.write(libraries)
        with self.assertRaisesRegex(ValueError, "Wrong ELF machine"):
            native.check_apk(self.apk, ["x86_64"])

    def test_duplicate_native_entries_are_rejected(self):
        self.write()
        import warnings
        with warnings.catch_warnings():
            warnings.simplefilter("ignore", UserWarning)
            with zipfile.ZipFile(self.apk, "a") as apk:
                name = "lib/x86_64/libflutter.so"
                apk.writestr(name, self.libraries[name])
        with self.assertRaisesRegex(ValueError, "Duplicate"):
            native.check_apk(self.apk, ["x86_64"])

    def test_cli_returns_failure_for_partial_universal(self):
        self.write()
        with contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(native.main(["--apk", str(self.apk)]), 1)

    def test_cli_accepts_an_explicit_split(self):
        self.write()
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(native.main(["--apk", str(self.apk), "--abi", "x86_64"]), 0)


if __name__ == "__main__":
    unittest.main()
