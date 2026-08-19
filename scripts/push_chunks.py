import subprocess
import os
import sys

sys.stdout.reconfigure(encoding='utf-8')

repo_dir = r'e:\My Projects\Rafiq-Al-Darb\rafeeq-api'

def run_git(args):
    print(f">> git {' '.join(args)}")
    res = subprocess.run(['git'] + args, cwd=repo_dir, capture_output=True, text=True, encoding='utf-8', errors='ignore')
    if res.stdout:
        print(res.stdout.strip())
    if res.stderr:
        print(res.stderr.strip())
    return res.returncode

if __name__ == '__main__':
    # 1. Push thumbnails and catalog first
    run_git(['add', 'mushaf/thumbs', 'mushafs_catalog.json'])
    run_git(['commit', '-m', 'Add all 17 3D mushaf cover thumbnails and catalog'])
    run_git(['push', 'origin', 'master'])
    
    # 2. Push each mushaf directory
    mushaf_dir = os.path.join(repo_dir, 'mushaf')
    folders = [f for f in os.listdir(mushaf_dir) if os.path.isdir(os.path.join(mushaf_dir, f)) and f not in ['hafs', 'tajweed', 'shamarly', 'warsh', 'thumbs']]
    
    for f in folders:
        target_path = f'mushaf/{f}'
        print(f"\n--- Staging and pushing {target_path} ---")
        run_git(['add', target_path])
        run_git(['commit', '-m', f'Add {f} high resolution Quranflash edition'])
        ret = run_git(['push', 'origin', 'master'])
        if ret != 0:
            print(f"[WARN] Push for {f} failed, will retry...")
            run_git(['push', 'origin', 'master'])
    
    print("\n=== ALL MUSHAFS PUSHED TO GITHUB SUCCESSFULLY ===")
