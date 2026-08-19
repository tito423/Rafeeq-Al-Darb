import subprocess
import os
import sys

sys.stdout.reconfigure(encoding='utf-8')

repo_dir = r'e:\My Projects\Rafiq-Al-Darb\rafeeq-api'

def run_git(args):
    print(f">> git {' '.join(args)}")
    res = subprocess.run(['git'] + args, cwd=repo_dir, capture_output=True, text=True, encoding='utf-8', errors='ignore')
    if res.stdout:
        print(res.stdout)
    if res.stderr:
        print(res.stderr)
    return res.returncode

if __name__ == '__main__':
    print("=== COMMITTING AND PUSHING ALL MUSHAFS TO GITHUB ===")
    run_git(['status'])
    run_git(['add', '-A'])
    run_git(['commit', '-m', 'Add all 17 high-res Quranflash Mushaf editions and 3D cover thumbnails'])
    run_git(['push', 'origin', 'master'])
    print("=== PUSH COMPLETE ===")
