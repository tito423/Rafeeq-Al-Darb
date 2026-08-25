import os
import json
import re
from pathlib import Path

PROJECT_ROOT = Path(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DATA_DIR = PROJECT_ROOT / "assets" / "data"

def clean_text(text):
    if not isinstance(text, str):
        return text
    
    # 1. Strip extraneous nested brackets (( ))
    text = re.sub(r'\(\(|\)\)', '', text)
    
    # 2. Strip raw quote artifacts '," and orphaned comma lines ','
    # This targets literal occurrences of `,'"` or `','` or orphaned commas/quotes that shouldn't be there
    text = text.replace('\'"', '"').replace(',"', '"').replace("','", "")
    
    # Remove orphaned commas at start or end of strings, or standalone commas
    text = re.sub(r'^[\s,]+|[\s,]+$', '', text)
    
    # Normalize spaces
    text = re.sub(r'\s+', ' ', text).strip()
    
    return text

def sanitize_json_object(obj):
    if isinstance(obj, dict):
        return {k: sanitize_json_object(v) for k, v in obj.items()}
    elif isinstance(obj, list):
        return [sanitize_json_object(item) for item in obj]
    elif isinstance(obj, str):
        return clean_text(obj)
    else:
        return obj

def process_file(file_path):
    print(f"[*] Processing: {file_path.name}")
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
        
        cleaned_data = sanitize_json_object(data)
        
        with open(file_path, 'w', encoding='utf-8') as f:
            json.dump(cleaned_data, f, ensure_ascii=False, indent=2)
            
        print(f"[+] Cleaned successfully: {file_path.name}")
    except Exception as e:
        print(f"[-] Failed to process {file_path.name}: {e}")

def main():
    dirs_to_process = [DATA_DIR / "tafsir", DATA_DIR / "books"]
    
    for directory in dirs_to_process:
        if directory.exists():
            for root, _, files in os.walk(directory):
                for file in files:
                    if file.endswith('.json'):
                        file_path = Path(root) / file
                        process_file(file_path)

if __name__ == "__main__":
    main()
