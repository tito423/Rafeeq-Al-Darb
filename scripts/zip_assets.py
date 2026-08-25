import os
import zipfile

def zip_folder(folder_path, output_path):
    if not os.path.exists(folder_path):
        print(f"Folder {folder_path} does not exist.")
        return
        
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    print(f"Zipping {folder_path} to {output_path}...")
    with zipfile.ZipFile(output_path, 'w', zipfile.ZIP_DEFLATED) as zipf:
        for root, _, files in os.walk(folder_path):
            for file in files:
                file_path = os.path.join(root, file)
                arcname = os.path.relpath(file_path, folder_path)
                zipf.write(file_path, arcname)
    print(f"Created {output_path}")

def main():
    base_dir = r"E:\My Projects\Rafiq-Al-Darb\rafeeq_app"
    
    quran_images_dir = os.path.join(base_dir, "temp_downloads", "mushaf", "madani_1024")
    quran_images_zip = os.path.join(base_dir, "assets", "quran", "quran_images.zip")
    
    quran_tafsir_dir = os.path.join(base_dir, "temp_downloads", "tafsir_api")
    quran_tafsir_zip = os.path.join(base_dir, "assets", "quran", "quran_tafsir.zip")
    
    zip_folder(quran_images_dir, quran_images_zip)
    zip_folder(quran_tafsir_dir, quran_tafsir_zip)

if __name__ == '__main__':
    main()
