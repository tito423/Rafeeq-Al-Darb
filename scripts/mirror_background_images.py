"""Copy the Unsplash background photos the app shows onto R2, byte for byte.

Audit 2026-09-24, C1: the adhkar and new-Muslim backgrounds had ONE source,
images.unsplash.com. The app now asks R2 first, then the GitHub mirror, then
Unsplash (ContentMirrors.of). This uploads each photo, at the exact URL the
app uses (?w=640&q=70&fit=crop), to `images/backgrounds/<photo-id>.jpg`.
Then run `py -3 scripts/github_content_mirror.py --only content-mirror`.

    py -3 scripts/mirror_background_images.py
"""
import os, re, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
APP = os.path.join(os.path.dirname(HERE), "rafeeq_app", "lib", "features")
SOURCES = [os.path.join(APP, "azkar", "data", "azkar_backgrounds.dart"),
           os.path.join(APP, "new_muslim", "data", "new_muslim_backgrounds.dart")]
PUBLIC = "https://pub-39dbef68a1a845d5ba669b43a59516b9.r2.dev"
UA = "RafeeqAlDarb/3.60 (https://github.com/tito423/Rafeeq-Al-Darb) curl/8"


def main():
    sys.path.insert(0, HERE)
    from r2_common import r2_client, BUCKET
    s3 = r2_client()
    urls = sorted({u for f in SOURCES
                   for u in re.findall(r"https://images\.unsplash\.com/[^'\"]+", open(f, encoding="utf-8").read())})
    print(len(urls), "photos")
    with tempfile.TemporaryDirectory() as tmp:
        for u in urls:
            pid = re.search(r"/(photo-[0-9a-f-]+)", u).group(1)
            key = f"images/backgrounds/{pid}.jpg"
            dest = os.path.join(tmp, pid + ".jpg")
            r = subprocess.run(["curl", "-sL", "-A", UA, "-o", dest, "-w", "%{http_code} %{content_type}", u],
                               capture_output=True, text=True)
            size = os.path.getsize(dest) if os.path.exists(dest) else 0
            if not r.stdout.startswith("200") or "image/" not in r.stdout or size < 10_000:
                print("SKIP", u, r.stdout, size)
                continue
            s3.upload_file(dest, BUCKET, key, ExtraArgs={"ContentType": "image/jpeg"})
            chk = subprocess.run(["curl", "-s", "-A", UA, "-o", os.devnull, "-w", "%{http_code} %{size_download}",
                                  f"{PUBLIC}/{key}"], capture_output=True, text=True).stdout
            print(key, size, "-> R2", chk)


if __name__ == "__main__":
    main()
