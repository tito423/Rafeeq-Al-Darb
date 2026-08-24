import os
import shutil
import subprocess
from pathlib import Path

PROJECT_ROOT = Path(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DATA_DIR = PROJECT_ROOT / "assets" / "data"
TAFSIR_DIR = DATA_DIR / "tafsir"
BOOKS_DIR = DATA_DIR / "books"
TEMP_DIR = PROJECT_ROOT / "temp_downloads"

def run_cmd(cmd):
    print(f"[*] Running: {cmd}")
    subprocess.run(cmd, shell=True, check=True)

def clone_and_extract():
    TAFSIR_DIR.mkdir(parents=True, exist_ok=True)
    BOOKS_DIR.mkdir(parents=True, exist_ok=True)
    TEMP_DIR.mkdir(parents=True, exist_ok=True)
    
    try:
        # 1. Fetch Tafsirs (spa5k/tafsir_api)
        tafsir_repo_dir = TEMP_DIR / "tafsir_api"
        if not tafsir_repo_dir.exists():
            run_cmd(f'git clone --depth 1 https://github.com/spa5k/tafsir_api.git "{tafsir_repo_dir}"')
        
        # Copy the massive JSON files we want
        # In spa5k/tafsir_api, the JSONs might be in tafsir/ directory or editions.
        print("[+] Processing Tafsir datasets...")
        # Since we don't know the exact internal structure of the repo, let's just copy the whole tafsir folder if it exists.
        if (tafsir_repo_dir / "tafsir").exists():
            for item in (tafsir_repo_dir / "tafsir").iterdir():
                if item.is_dir() or item.suffix == '.json':
                    dest = TAFSIR_DIR / item.name
                    if item.is_dir():
                        shutil.copytree(item, dest, dirs_exist_ok=True)
                    else:
                        shutil.copy2(item, dest)
        
        # 2. Fetch Hadith/Books (AhmedBaset/hadith-json)
        hadith_repo_dir = TEMP_DIR / "hadith_json"
        if not hadith_repo_dir.exists():
            run_cmd(f'git clone --depth 1 https://github.com/AhmedBaset/hadith-json.git "{hadith_repo_dir}"')
        
        print("[+] Processing Books datasets (Riyad as-Salihin)...")
        riyad_path = hadith_repo_dir / "db" / "riyadussaliheen"
        if not riyad_path.exists():
             riyad_path = hadith_repo_dir / "db" / "riyad_as_salihin"
             
        if riyad_path.exists():
            shutil.copytree(riyad_path, BOOKS_DIR / "riyadussaliheen", dirs_exist_ok=True)
        else:
            # Let's just copy all db folders as books
            if (hadith_repo_dir / "db").exists():
                 for item in (hadith_repo_dir / "db").iterdir():
                     if item.is_dir():
                          shutil.copytree(item, BOOKS_DIR / item.name, dirs_exist_ok=True)

        print("[+] Massive datasets fetched and extracted successfully!")
    except Exception as e:
        print(f"[-] Error: {e}")
    finally:
        # Cleanup
        if TEMP_DIR.exists():
            # Windows might have read-only files in .git, so standard shutil.rmtree might fail. 
            # We'll leave it or use a forced removal.
            try:
                run_cmd(f'rmdir /S /Q "{TEMP_DIR}"')
            except Exception:
                pass

if __name__ == "__main__":
    clone_and_extract()
