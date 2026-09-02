"""Uploads the 5 P2‑7 adhan background clips (Pixabay Content License — free
commercial use, no attribution) to `tito423/rafeeq-api` under
`adhan/video/<name>.mp4`, downloaded on demand by the app (not bundled).

Reads the files from scripts/adhan_video_build/.  Same `gh api --input`
mechanism as scripts/upload_book_text.py (base64 too big for argv).

    python scripts/upload_adhan_videos.py
"""
import base64
import json
import os
import subprocess
import sys
import tempfile

BUILD_DIR = os.path.join(os.path.dirname(__file__), "adhan_video_build")
REPO = "tito423/rafeeq-api"
BRANCH = "master"


def existing_sha(repo_path):
    r = subprocess.run(
        ["gh", "api", f"/repos/{REPO}/contents/{repo_path}?ref={BRANCH}",
         "--jq", ".sha"],
        capture_output=True, text=True,
    )
    return r.stdout.strip() if r.returncode == 0 and r.stdout.strip() else None


def upload(local_path, repo_path, message):
    with open(local_path, "rb") as f:
        content_b64 = base64.b64encode(f.read()).decode("ascii")
    body = {"message": message, "branch": BRANCH, "content": content_b64}
    sha = existing_sha(repo_path)
    if sha:
        body["sha"] = sha
    with tempfile.NamedTemporaryFile(
        "w", suffix=".json", delete=False, encoding="utf-8"
    ) as tf:
        json.dump(body, tf)
        body_path = tf.name
    try:
        r = subprocess.run(
            ["gh", "api", "--method", "PUT",
             f"/repos/{REPO}/contents/{repo_path}", "--input", body_path],
            capture_output=True, text=True,
        )
    finally:
        os.unlink(body_path)
    if r.returncode != 0:
        raise RuntimeError(f"upload failed for {repo_path}: {r.stderr}")
    commit = json.loads(r.stdout).get("commit", {}).get("sha", "?")[:9]
    print(f"  {'updated' if sha else 'created'} {repo_path}  "
          f"({os.path.getsize(local_path)/1024/1024:.1f} MB)  commit {commit}")


def main():
    want = sys.argv[1:]
    files = sorted(
        f for f in os.listdir(BUILD_DIR)
        if f.endswith(".mp4") and (not want or f[:-4] in want)
    )
    for f in files:
        print(f"=== {f} ===")
        upload(
            os.path.join(BUILD_DIR, f),
            f"adhan/video/{f}",
            f"content(adhan): background clip {f} (Pixabay Content License)",
        )


if __name__ == "__main__":
    main()
