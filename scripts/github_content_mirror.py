"""Mirror the app's R2 content onto GitHub Releases of the app's own repo.

The owner, 2026-09-24: «حط خمس حلول احتياطية لكل حاجة بتستغل في التطبيق»,
and GitHub Releases approved as a second host. The app then tries R2 first and
the release asset second (AppConfig.mirrorsFor).

    py -3 scripts/github_content_mirror.py            # upload what is missing
    py -3 scripts/github_content_mirror.py --verify   # sizes + a range request
    py -3 scripts/github_content_mirror.py --only content-mirror   # one release

Bytes are copied VERBATIM from the public R2 endpoint — the books stay gzip
with no Content-Encoding (CLAUDE.md trap #6), and the app sniffs them the same
way whichever host answered. An asset is named after its R2 key with '/'
turned into '__' (GitHub allows no '/' in asset names); AppConfig.mirrorsFor
builds the same name. Resumable: an asset already on the release with the
same byte count is skipped.

Which prefixes go to which release is RELEASES below. The per-ayah recitation
folders are not mirrored here: 18,708 files is far past a release's 1,000-asset
limit, and those verses already have three hosts beyond R2 (everyayah and two
islamic.network bitrates).
"""
import json, os, subprocess, sys, tempfile, urllib.request

REPO = "tito423/Rafeeq-Al-Darb"
PUBLIC = "https://pub-39dbef68a1a845d5ba669b43a59516b9.r2.dev"
UA = "RafeeqAlDarb-mirror/1.0 (https://github.com/tito423/Rafeeq-Al-Darb)"
HERE = os.path.dirname(os.path.abspath(__file__))

RELEASES = {
    "content-mirror": ["books/text/", "hadeethenc/", "hadith/", "sciences/",
                       "quran/translations/", "channels/", "legal/",
                       "asr/whisper-tiny-ar-quran/", "tts/open_ar_v1/", "ruqyah/",
                       "images/backgrounds/", "geo/"],
    "content-mushaf": ["mushaf/madinah_qc/"],
    "content-surah": ["recitations/surah/basit_murattal/",
                      "recitations/surah/maher_murattal/"],
}


def asset_name(key: str) -> str:
    return key.replace("/", "__")


def r2_objects():
    sys.path.insert(0, HERE)
    from r2_common import r2_client, BUCKET
    s3 = r2_client()
    out, tok = [], None
    while True:
        kw = dict(Bucket=BUCKET, MaxKeys=1000)
        if tok:
            kw["ContinuationToken"] = tok
        r = s3.list_objects_v2(**kw)
        out += [(o["Key"], o["Size"]) for o in r.get("Contents", [])]
        if not r.get("IsTruncated"):
            return out
        tok = r["NextContinuationToken"]


def gh(*args, check=True):
    return subprocess.run(["gh", *args], capture_output=True, text=True,
                          encoding="utf-8", check=check)


def ensure_release(tag):
    if gh("release", "view", tag, "--repo", REPO, check=False).returncode == 0:
        return
    gh("release", "create", tag, "--repo", REPO, "--prerelease",
       "--title", f"Content mirror ({tag})",
       "--notes", "نسخة احتياطية من محتوى التطبيق المستضاف على R2، بنفس البايتات. "
                  "يستخدمها التطبيق تلقائيًا إذا تعذّر الوصول إلى الخادم الأساسي. "
                  "ليست إصدارًا من التطبيق.")


def existing_assets(tag):
    r = gh("api", "--paginate", f"repos/{REPO}/releases/tags/{tag}", "--jq",
           "[.assets[] | {name, size}]")
    names = {}
    for chunk in r.stdout.strip().splitlines():
        for a in json.loads(chunk):
            names[a["name"]] = a["size"]
    return names


def fetch(key, dest):
    # Accept-Encoding: gzip, so an object STORED with Content-Encoding: gzip
    # (the 45 translations) comes back as its stored bytes. Without it
    # Cloudflare inflates it on the way out, the byte count no longer equals
    # the object's, and the size check below refused all 45 on the first run.
    # urllib never inflates, so what is written is exactly what R2 holds.
    req = urllib.request.Request(f"{PUBLIC}/{key}", headers={
        "User-Agent": UA, "Accept-Encoding": "gzip"})
    with urllib.request.urlopen(req, timeout=120) as res, open(dest, "wb") as f:
        while True:
            b = res.read(1 << 20)
            if not b:
                break
            f.write(b)


def main():
    verify = "--verify" in sys.argv
    objs = r2_objects()
    report = []
    only = sys.argv[sys.argv.index("--only") + 1] if "--only" in sys.argv else None
    for tag, prefixes in RELEASES.items():
        if only and tag != only:
            continue
        want = [(k, s) for k, s in objs if any(k.startswith(p) for p in prefixes)]
        if not verify:
            ensure_release(tag)
        have = existing_assets(tag)
        missing = [(k, s) for k, s in want if have.get(asset_name(k)) != s]
        report.append(f"{tag}: want {len(want)}, have-matching {len(want) - len(missing)}, missing {len(missing)}")
        if verify:
            continue
        with tempfile.TemporaryDirectory() as tmp:
            for n, (k, s) in enumerate(missing, 1):
                dest = os.path.join(tmp, asset_name(k))
                fetch(k, dest)
                if os.path.getsize(dest) != s:
                    msg = f"  SIZE MISMATCH from R2: {k} ({os.path.getsize(dest)} != {s})"
                    report.append(msg)
                    print(msg, flush=True)  # at once: a silent skip hid 45 of them
                    continue
                gh("release", "upload", tag, dest, "--repo", REPO, "--clobber")
                os.remove(dest)
                print(f"{tag} {n}/{len(missing)} {k}", flush=True)
    if verify:
        # One range request per release, on the smallest asset, through the
        # same redirect the app follows.
        for tag, prefixes in RELEASES.items():
            want = sorted((s, k) for k, s in objs if any(k.startswith(p) for p in prefixes))
            if not want:
                continue
            k = want[0][1]
            url = f"https://github.com/{REPO}/releases/download/{tag}/{asset_name(k)}"
            p = subprocess.run(["curl", "-sL", "-r", "0-1023", "-o", os.devnull, "-A", UA,
                                "-w", "%{http_code} %{size_download}", url],
                               capture_output=True, text=True)
            report.append(f"  range {tag}/{asset_name(k)} -> {p.stdout}")
    text = "\n".join(report)
    open(os.path.join(HERE, "github_content_mirror_report.txt"), "w", encoding="utf-8").write(text)
    print(text)


if __name__ == "__main__":
    main()
