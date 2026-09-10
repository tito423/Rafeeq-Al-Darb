# -*- coding: utf-8 -*-
"""Sign the release APK with the real key, carrying the debug key's lineage.

Why this exists rather than a plain `signingConfig` in Gradle:

The app shipped for its whole life signed with the **Android debug key** — a
key that is on every machine with the SDK, whose password is the word
"android". Anyone can build an APK that Android will accept as an update to
this one. Moving to a private key normally means the owner has to uninstall
first, because Android refuses an update signed by a different key, and
uninstalling loses every downloaded mushaf page and every setting.

APK Signature Scheme v3 has a way out: a **SigningCertificateLineage**, a
signed statement that the new key is the rightful successor of the old one.
An APK carrying it updates the installed app in place. Gradle's DSL has no
field for a lineage, so the APK is signed here instead, after the build.

    py -3 scripts/sign_release.py

Reads the keystore and its password from the key folder, which lives OUTSIDE
this repository and is never committed. Refuses to do anything if the
resulting APK does not actually carry the new certificate — the whole point
is to not have to take that on trust.
"""

import io
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
APK = os.path.join(ROOT, "rafeeq_app", "build", "app", "outputs",
                   "flutter-apk", "app-release.apk")

# Outside the repo on purpose. Overridable so the folder can be moved.
KEYS = os.environ.get("RAFEEQ_KEYS",
                      os.path.join(os.path.dirname(ROOT), "Rafeeq-Keys"))
KEYSTORE = os.path.join(KEYS, "rafeeq-release.jks")
PASSWORD_FILE = os.path.join(KEYS, "KEYSTORE-PASSWORD.txt")
LINEAGE = os.path.join(KEYS, "lineage.bin")
ALIAS = "rafeeq"

DEBUG_KS = os.path.join(os.path.expanduser("~"), ".android", "debug.keystore")
DEBUG_ALIAS = "androiddebugkey"
DEBUG_PW = "android"  # not a secret: this is the SDK's published default

EXPECT_DN = "CN=Rafeeq Al-Darb"
DEBUG_DN = "CN=Android Debug"


def build_tool(name):
    """Newest build-tools copy of `name`."""
    sdk = os.environ.get("ANDROID_SDK_ROOT") or os.environ.get(
        "ANDROID_HOME") or os.path.join(
            os.environ.get("LOCALAPPDATA", ""), "Android", "Sdk")
    base = os.path.join(sdk, "build-tools")
    versions = sorted(os.listdir(base),
                      key=lambda v: [int(x) for x in re.findall(r"\d+", v)])
    return os.path.join(base, versions[-1], name)


def password():
    text = io.open(PASSWORD_FILE, encoding="utf-8").read()
    m = re.search(r"^Password:\s*(\S+)", text, re.M)
    if not m:
        sys.exit("no Password: line in %s" % PASSWORD_FILE)
    return m.group(1)


def dn(verify_output):
    m = re.search(r"^Signer #1 certificate DN: (.+)$", verify_output, re.M)
    return m.group(1).strip() if m else "?"


def run(args, label):
    p = subprocess.run(args, capture_output=True, text=True)
    if p.returncode != 0:
        # Never echo the arguments: they carry the keystore password.
        sys.stderr.write((p.stderr or p.stdout or "")[-2000:] + "\n")
        sys.exit("%s failed (exit %d)" % (label, p.returncode))
    return p.stdout


def main():
    for path in (APK, KEYSTORE, PASSWORD_FILE):
        if not os.path.exists(path):
            sys.exit("missing: %s" % path)
    apksigner = build_tool("apksigner.bat" if os.name == "nt" else "apksigner")
    pw = password()

    if not os.path.exists(LINEAGE):
        if not os.path.exists(DEBUG_KS):
            sys.exit(
                "The debug keystore is gone: %s\n"
                "Without it the lineage cannot be created, and moving to the\n"
                "real key would need an uninstall." % DEBUG_KS)
        run([apksigner, "rotate", "--out", LINEAGE,
             "--old-signer", "--ks", DEBUG_KS, "--ks-pass", "pass:" + DEBUG_PW,
             "--ks-key-alias", DEBUG_ALIAS, "--key-pass", "pass:" + DEBUG_PW,
             "--new-signer", "--ks", KEYSTORE, "--ks-pass", "pass:" + pw,
             "--ks-key-alias", ALIAS, "--key-pass", "pass:" + pw],
            "apksigner rotate")
        print("lineage created: %s" % LINEAGE)

    # Both signers, oldest first. apksigner refuses a lineage otherwise: the
    # v2 block has to stay signed by the ORIGINAL key so a device too old to
    # read v3 (below Android 9) still accepts the update, while v3 carries the
    # new key plus the lineage proving it inherited from the old one. On
    # Android 9 and up — which is every phone this app will meet — the app's
    # identity becomes the new key.
    run([apksigner, "sign",
         "--ks", DEBUG_KS, "--ks-pass", "pass:" + DEBUG_PW,
         "--ks-key-alias", DEBUG_ALIAS, "--key-pass", "pass:" + DEBUG_PW,
         "--next-signer",
         "--ks", KEYSTORE, "--ks-pass", "pass:" + pw,
         "--ks-key-alias", ALIAS, "--key-pass", "pass:" + pw,
         "--lineage", LINEAGE,
         # Without this apksigner defaults to 33, which would leave
         # Android 9-12 still running on the debug key. Rotation has
         # been honoured since 28; measured on the signed APK, this
         # moves the new key's range from "33+" to "28+".
         "--rotation-min-sdk-version", "28",
         # v1 (JAR signing) is off, exactly as the shipped APK already
         # had it: minSdk is 24 and v2 covers everything from 24 up.
         # Enabling it alongside a lineage would also require signing
         # the v1 block with the OLD (debug) key, which is the thing
         # being moved away from.
         "--v1-signing-enabled", "false",
         "--v2-signing-enabled", "true",
         "--v3-signing-enabled", "true",
         APK], "apksigner sign")

    # Two verifications, because the answer differs by Android version and a
    # single one hides half of it. On 28+ the app must present the new key; on
    # 24-27, where v3 cannot be read, it must still present the OLD one, or
    # those devices would see a signature mismatch and refuse the update.
    modern = run([apksigner, "verify", "--print-certs",
                  "--min-sdk-version", "28", APK], "apksigner verify (28+)")
    legacy = run([apksigner, "verify", "--print-certs",
                  "--min-sdk-version", "24", "--max-sdk-version", "27", APK],
                 "apksigner verify (24-27)")
    print("Android 9 and up : %s" % dn(modern))
    print("Android 7 to 8   : %s" % dn(legacy))

    # The check this script exists for. A signature that verifies is not the
    # same as a signature by the right key.
    if EXPECT_DN not in modern:
        sys.exit("REFUSED: on Android 9+ this APK is not signed by %s"
                 % EXPECT_DN)
    if DEBUG_DN not in legacy:
        sys.exit("REFUSED: the old key is gone from the 24-27 range, so a "
                 "phone below Android 9 would reject this as a signature "
                 "mismatch instead of updating")
    print("\nOK: rotated. New key from Android 9 up, old key kept below it "
          "so every install path is still an update, not a reinstall.")


if __name__ == "__main__":
    main()
