import urllib.request
import json
import ssl

def fetch_repo_tree(repo):
    url = f"https://api.github.com/repos/{repo}/git/trees/main?recursive=1"
    ctx = ssl._create_unverified_context()
    try:
        req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
        with urllib.request.urlopen(req, context=ctx) as response:
            data = json.loads(response.read().decode())
            for item in data.get('tree', []):
                if item['path'].endswith('.png') and 'page' in item['path'].lower():
                    print(f"{repo}: {item['path']}")
                    return
    except Exception as e:
        print(f"Error fetching {repo} main: {e}")
        
    url = f"https://api.github.com/repos/{repo}/git/trees/master?recursive=1"
    try:
        req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
        with urllib.request.urlopen(req, context=ctx) as response:
            data = json.loads(response.read().decode())
            for item in data.get('tree', []):
                if item['path'].endswith('.png') and 'page' in item['path'].lower():
                    print(f"{repo}: {item['path']}")
                    return
    except Exception as e:
        print(f"Error fetching {repo} master: {e}")

fetch_repo_tree('quran/quran.com-images')
fetch_repo_tree('QuranHub/quran-pages-images')
