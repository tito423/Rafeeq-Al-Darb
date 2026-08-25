import os
import subprocess
import glob

def download_adhan():
    audio_dir = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
    os.makedirs(audio_dir, exist_ok=True)
    
    # Use ytsearch1: to grab the first search result for these terms
    muezzins = {
        "makkah": "ytsearch1:Adhan Makkah short beautiful",
        "abdulbasit": "ytsearch1:Adhan Abdul Basit Abdus Samad short",
        "minshawi": "ytsearch1:Adhan Muhammad Siddiq Minshawi",
        "mishary": "ytsearch1:Adhan Mishary Rashid Alafasy",
        "mustafa_ismail": "ytsearch1:Adhan Mustafa Ismail"
    }

    # Clean up old webm or broken mp3 files
    for old_file in glob.glob(os.path.join(audio_dir, "*.webm")):
        try: os.remove(old_file)
        except: pass

    for name, query in muezzins.items():
        output_template = os.path.join(audio_dir, f"{name}.%(ext)s")
        m4a_file = os.path.join(audio_dir, f"{name}.m4a")
        
        if os.path.exists(m4a_file):
            print(f"Skipping {name}, already downloaded.")
            continue
            
        print(f"Downloading Adhan for {name}...")
        
        # Using yt-dlp to extract best audio specifically in m4a so we don't need ffmpeg
        command = [
            "yt-dlp",
            "-f", "bestaudio[ext=m4a]/bestaudio",
            "--match-filter", "duration < 360",
            "-o", output_template,
            query
        ]
        
        try:
            subprocess.run(command, check=True)
            print(f"Successfully downloaded {name}.m4a")
        except subprocess.CalledProcessError as e:
            print(f"Failed to download {name}: {e}")

if __name__ == "__main__":
    download_adhan()
