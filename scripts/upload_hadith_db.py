"""Uploads scripts/pipeline_zips/hadith.zip to the content repo
`tito423/rafeeq-api` at `hadith/hadith.zip`, via the GitHub Contents API
(`gh api`, already authenticated on this box as `tito423`) — the same
proven pattern as scripts/upload_book_text.py.

Run AFTER scripts/build_hadith_db.py has produced a fresh
scripts/pipeline_zips/hadith.zip (P2‑13: real per-hadith grading added for
Abu Dawud/Tirmidhi/an-Nasa'i/Ibn Majah). Overwrites the file already hosted
there (fetches its blob sha, updates in place) so `AppConfig.hadithDbUrl`
keeps pointing at the same URL — only `AppConfig.hadithDbVersion` changes,
which is what makes already-downloaded devices re-fetch (see
`DbHelper.openDownloaded`'s doc).
"""
import base64
import json
import os
import subprocess
import tempfile

LOCAL = r"e:\My Projects\Rafiq-Al-Darb\scripts\pipeline_zips\hadith.zip"
REPO = "tito423/rafeeq-api"
BRANCH = "master"
REPO_PATH = "hadith/hadith.zip"


def existing_sha():
    res = subprocess.run(
        ["gh", "api", f"/repos/{REPO}/contents/{REPO_PATH}?ref={BRANCH}",
         "--jq", ".sha"],
        capture_output=True, text=True,
    )
    return res.stdout.strip() if res.returncode == 0 and res.stdout.strip() else None


def main():
    size_mb = os.path.getsize(LOCAL) / 1024 / 1024
    print(f"local file: {LOCAL} ({size_mb:.1f} MB)")

    with open(LOCAL, "rb") as f:
        content_b64 = base64.b64encode(f.read()).decode("ascii")

    sha = existing_sha()
    print(f"existing blob sha on {REPO}: {sha or '(none — first upload)'}")

    body = {
        "message": "content(hadith): rebuild with real per-hadith grading "
                    "for Abu Dawud/Tirmidhi/an-Nasa'i/Ibn Majah (P2-13)",
        "branch": BRANCH,
        "content": content_b64,
    }
    if sha:
        body["sha"] = sha

    # base64 of a 16MB file is well past the Windows command-line arg limit —
    # hand gh api the request body via a temp file, not as -f args.
    with tempfile.NamedTemporaryFile(
        "w", suffix=".json", delete=False, encoding="utf-8"
    ) as tf:
        json.dump(body, tf)
        body_path = tf.name
    try:
        res = subprocess.run(
            ["gh", "api", "--method", "PUT",
             f"/repos/{REPO}/contents/{REPO_PATH}", "--input", body_path],
            capture_output=True, text=True,
        )
    finally:
        os.unlink(body_path)

    if res.returncode != 0:
        print("UPLOAD FAILED")
        print("stdout:", res.stdout[:2000])
        print("stderr:", res.stderr[:2000])
        raise SystemExit(1)

    j = json.loads(res.stdout)
    commit = j.get("commit", {}).get("sha", "?")[:9]
    action = "updated" if sha else "created"
    print(f"{action} {REPO_PATH} on {REPO}@{BRANCH}  commit {commit}")


if __name__ == "__main__":
    main()
