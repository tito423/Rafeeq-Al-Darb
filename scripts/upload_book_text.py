"""Uploads the built book text editions to the content repo
`tito423/rafeeq-api` under `books/text/<id>.json`, via the GitHub Contents API
(`gh api`, which is already authenticated on this box as `tito423`).

Run AFTER `scripts/build_book_text.py` has produced the files in
`scripts/book_text_build/`. This is the same "host large content on
rafeeq-api, download on demand" pattern the hadith DB uses
(`AppConfig.hadithDbUrl`) — see HANDOVER.md §6.

    python scripts/upload_book_text.py            # upload all built files
    python scripts/upload_book_text.py al_fawaid  # just one

Each file is committed to the repo's default branch (`master`). If the path
already exists the script fetches its blob sha and updates in place.
"""
import base64
import json
import os
import subprocess
import sys
import tempfile

BUILD_DIR = os.path.join(os.path.dirname(__file__), "book_text_build")
REPO = "tito423/rafeeq-api"
BRANCH = "master"


def existing_sha(repo_path):
    res = subprocess.run(
        ["gh", "api", f"/repos/{REPO}/contents/{repo_path}?ref={BRANCH}",
         "--jq", ".sha"],
        capture_output=True, text=True,
    )
    return res.stdout.strip() if res.returncode == 0 and res.stdout.strip() else None


def upload(local_path, repo_path, message):
    with open(local_path, "rb") as f:
        content_b64 = base64.b64encode(f.read()).decode("ascii")
    sha = existing_sha(repo_path)
    body = {"message": message, "branch": BRANCH, "content": content_b64}
    if sha:
        body["sha"] = sha

    # The base64 blob is ~MB — far past the Windows command-line limit — so
    # hand `gh api` the request body on stdin via a temp file, not as -f args.
    with tempfile.NamedTemporaryFile(
        "w", suffix=".json", delete=False, encoding="utf-8"
    ) as tf:
        json.dump(body, tf)
        body_path = tf.name
    try:
        res = subprocess.run(
            ["gh", "api", "--method", "PUT",
             f"/repos/{REPO}/contents/{repo_path}", "--input", body_path],
            capture_output=True, text=True,
        )
    finally:
        os.unlink(body_path)
    if res.returncode != 0:
        raise RuntimeError(f"upload failed for {repo_path}: {res.stderr}")
    j = json.loads(res.stdout)
    commit = j.get("commit", {}).get("sha", "?")[:9]
    action = "updated" if sha else "created"
    print(f"  {action} books/text/{os.path.basename(repo_path)}  "
          f"({os.path.getsize(local_path)/1024:.0f} KB)  commit {commit}")


def main():
    want = sys.argv[1:]
    files = sorted(
        f for f in os.listdir(BUILD_DIR)
        if f.endswith(".json") and (not want or f[:-5] in want)
    )
    if not files:
        print("no built files in", BUILD_DIR)
        return
    for f in files:
        book_id = f[:-5]
        print(f"=== {book_id} ===")
        upload(
            os.path.join(BUILD_DIR, f),
            f"books/text/{book_id}.json",
            f"content(books): text edition for {book_id} (al-Maktaba al-Shamela)",
        )


if __name__ == "__main__":
    main()
