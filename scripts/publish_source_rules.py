"""Publish config/source_rules.json - how the app reads dorar.net and
shamela.ws (lib/core/services/source_rules.dart).

    py -3 scripts/publish_source_rules.py            # write + upload
    py -3 scripts/publish_source_rules.py --dry-run  # write only

The file is built from the Dart defaults, with scripts/source_rules_overrides.json
on top (only the rules a site change forced). Bump "version" there for every
change the app must take: the app applies a file only when its version is
newer than the one it has. Then run scripts/check_sources.py.

Uploaded to R2 (config/source_rules.json) and to the content-mirror GitHub
release as config__source_rules.json (ContentMirrors' fallback name).
"""
import json
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
DART = os.path.join(ROOT, "rafeeq_app", "lib", "core", "services", "source_rules.dart")
OVERRIDES = os.path.join(HERE, "source_rules_overrides.json")
OUT = os.path.join(HERE, "out", "source_rules.json")
KEY = "config/source_rules.json"


def dart_defaults():
    src = open(DART, encoding="utf-8").read()
    body = src[src.index("static const Map<String, String> defaults = {"):]
    body = body[: body.index("};")]
    rules = {}
    # 'key': 'value' or 'key':\n r'value'
    for m in re.finditer(r"'([a-z_.]+)':\s*(r?)'((?:[^'\\]|\\.)*)'", body):
        key, raw, val = m.group(1), m.group(2), m.group(3)
        if not raw:
            val = val.encode().decode("unicode_escape").encode("latin-1").decode("utf-8")
        rules[key] = val
    built = int(re.search(r"builtInVersion = (\d+);", src).group(1))
    return built, rules


def main():
    built, rules = dart_defaults()
    version = built
    if os.path.exists(OVERRIDES):
        o = json.load(open(OVERRIDES, encoding="utf-8"))
        version = max(version, int(o.get("version", built)))
        for k, v in o.get("rules", {}).items():
            if k not in rules:
                sys.exit(f"unknown rule {k}")
            rules[k] = v
    doc = {"version": version, "rules": rules}
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(doc, f, ensure_ascii=False, indent=1)
    print(f"version {version}, {len(rules)} rules -> {OUT}")
    if "--dry-run" in sys.argv:
        return
    sys.path.insert(0, HERE)
    from r2_common import BUCKET, r2_client

    r2_client().upload_file(OUT, BUCKET, KEY, ExtraArgs={
        "ContentType": "application/json; charset=utf-8",
        "CacheControl": "max-age=3600",
    })
    print("uploaded to R2:", KEY)
    mirror = os.path.join(HERE, "out", KEY.replace("/", "__"))
    with open(mirror, "w", encoding="utf-8") as f:
        json.dump(doc, f, ensure_ascii=False, indent=1)
    subprocess.run(["gh", "release", "upload", "content-mirror", mirror,
                    "--clobber", "-R", "tito423/Rafeeq-Al-Darb"], check=True)
    print("uploaded to GitHub content-mirror:", os.path.basename(mirror))


if __name__ == "__main__":
    main()
