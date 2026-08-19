import os
import urllib.request
import ssl
import sys
import subprocess
from concurrent.futures import ThreadPoolExecutor

sys.stdout.reconfigure(encoding='utf-8')

ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

target_dir = os.path.abspath(os.path.join('..', 'rafeeq-api', 'mushaf', 'shamarly'))
os.makedirs(target_dir, exist_ok=True)

print(f"Target directory: {target_dir}")

def download_page(page_num):
    target_path = os.path.join(target_dir, f"{page_num}.png")
    if os.path.exists(target_path) and os.path.getsize(target_path) > 2000:
        return True, page_num
    
    url = f"https://raw.githubusercontent.com/Mr-DDDAlKilanny/shamraly-images/master/{page_num:03d}.png"
    try:
        req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
        with urllib.request.urlopen(req, context=ctx, timeout=15) as resp:
            data = resp.read()
            if len(data) > 1000:
                with open(target_path, 'wb') as f:
                    f.write(data)
                return True, page_num
    except Exception as e:
        print(f"Error page {page_num}: {e}")
    return False, page_num

print("Downloading Shamarly pages (1-522)...")
with ThreadPoolExecutor(max_workers=16) as pool:
    results = list(pool.map(download_page, range(1, 523)))

success_count = sum(1 for ok, _ in results if ok)
print(f"Shamarly downloaded: {success_count} / 522 pages")

# Git add, commit, push in ../rafeeq-api
api_repo_dir = os.path.abspath(os.path.join('..', 'rafeeq-api'))
print(f"Running git operations in {api_repo_dir}...")
try:
    subprocess.run(['git', 'add', 'mushaf/shamarly'], cwd=api_repo_dir, check=True)
    subprocess.run(['git', 'commit', '-m', 'Add high-res Mushaf Shamarly pages (522 pages)'], cwd=api_repo_dir, check=True)
    subprocess.run(['git', 'push', 'origin', 'master'], cwd=api_repo_dir, check=True)
    print("✓ Successfully pushed Shamarly Mushaf to GitHub!")
except Exception as e:
    print(f"Git operation error: {e}")
