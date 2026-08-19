import os
import requests
import base64
import json
import time

# --- Configuration ---
# Your GitHub PAT (Personal Access Token) with 'repo' scope.
GITHUB_TOKEN = os.environ.get("GITHUB_PAT")
GITHUB_USER = "tito423"
GITHUB_REPO = "rafeeq-api"
BRANCH = "main"

# The 6 Authentic Hadith Books from fawazahmed0/hadith-api
HADITH_SOURCES = {
    "bukhari": "https://cdn.jsdelivr.net/gh/fawazahmed0/hadith-api@1/editions/ara-bukhari.json",
    "muslim": "https://cdn.jsdelivr.net/gh/fawazahmed0/hadith-api@1/editions/ara-muslim.json",
    "abudawud": "https://cdn.jsdelivr.net/gh/fawazahmed0/hadith-api@1/editions/ara-abudawud.json",
    "ibnmajah": "https://cdn.jsdelivr.net/gh/fawazahmed0/hadith-api@1/editions/ara-ibnmajah.json",
    "tirmidhi": "https://cdn.jsdelivr.net/gh/fawazahmed0/hadith-api@1/editions/ara-tirmidhi.json",
    "nasai": "https://cdn.jsdelivr.net/gh/fawazahmed0/hadith-api@1/editions/ara-nasai.json"
}

def upload_to_github(file_path, content, message):
    if not GITHUB_TOKEN:
        print(f"[!] SKIP: GITHUB_PAT is not set. Saving {file_path} locally instead.")
        os.makedirs(os.path.dirname(file_path), exist_ok=True)
        with open(file_path, "wb") as f:
            f.write(content)
        return
        
    url = f"https://api.github.com/repos/{GITHUB_USER}/{GITHUB_REPO}/contents/{file_path}"
    headers = {
        "Authorization": f"token {GITHUB_TOKEN}",
        "Accept": "application/vnd.github.v3+json"
    }

    # Check if file exists to get its SHA
    response = requests.get(url, headers=headers)
    sha = None
    if response.status_code == 200:
        sha = response.json().get('sha')

    # Convert content to base64 string
    content_b64 = base64.b64encode(content).decode('utf-8')

    data = {
        "message": message,
        "content": content_b64,
        "branch": BRANCH
    }
    if sha:
        data["sha"] = sha

    put_response = requests.put(url, headers=headers, json=data)
    if put_response.status_code in [200, 201]:
        print(f"[+] Successfully pushed {file_path} to GitHub!")
    else:
        print(f"[-] Failed to push {file_path}. Status: {put_response.status_code}")
        print(put_response.text)

def main():
    print("=== Rafeeq Al-Darb Assets Sync ===")
    
    # 1. Download & Upload Hadith Books
    for name, url in HADITH_SOURCES.items():
        print(f"\n[*] Downloading {name}...")
        try:
            resp = requests.get(url)
            resp.raise_for_status()
            
            # Save the JSON directly to the repository
            file_path = f"hadith/{name}.json"
            upload_to_github(file_path, resp.content, f"Update Hadith book: {name}")
            
            # Polite delay to not hammer the CDN or GitHub API
            time.sleep(1)
        except Exception as e:
            print(f"[!] Error processing {name}: {e}")

if __name__ == "__main__":
    main()
