import os
import urllib.request
import ssl
import time

ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

BOOKS = [
    {
        "id": "riyad_salihin",
        "title": "رياض الصالحين",
        "pdf_url": "https://archive.org/download/Riyad-Us-Saliheen_201705/Riyad%20Us%20Saliheen.pdf"
    },
    {
        "id": "la_tahzan",
        "title": "لا تحزن",
        "pdf_url": "https://archive.org/download/la-tahzan_202011/la-tahzan.pdf"
    },
    {
        "id": "zad_maad",
        "title": "زاد المعاد",
        "pdf_url": "https://archive.org/download/Zad-Al-Maad/Zad-Al-Maad.pdf"
    },
    {
        "id": "tafsir_sadi",
        "title": "تفسير السعدي",
        "pdf_url": "https://archive.org/download/TafsirAlSaadi/TafsirAlSaadi.pdf"
    },
    {
        "id": "fiqh_sunnah",
        "title": "فقه السنة",
        "pdf_url": "https://archive.org/download/FiqhUsSunnah_201812/Fiqh%20Us%20Sunnah.pdf"
    },
    {
        "id": "aqidah_wasitiyyah",
        "title": "العقيدة الواسطية",
        "pdf_url": "https://archive.org/download/AlAqeedahAlWasitiyyah/AlAqeedahAlWasitiyyah.pdf"
    },
    {
        "id": "bidayat_mujtahid",
        "title": "بداية المجتهد",
        "pdf_url": "https://archive.org/download/BidayatulMujtahid/BidayatulMujtahid.pdf"
    },
    {
        "id": "usul_thalatha",
        "title": "الأصول الثلاثة",
        "pdf_url": "https://archive.org/download/AlUsoolAthThalatha/AlUsoolAthThalatha.pdf"
    },
    {
        "id": "sifat_salat",
        "title": "صفة صلاة النبي",
        "pdf_url": "https://archive.org/download/SifatSalatAlNabi/SifatSalatAlNabi.pdf"
    }
]

def main():
    dest_dir = "temp_downloads/books"
    os.makedirs(dest_dir, exist_ok=True)
    
    total_size = 0
    
    for book in BOOKS:
        file_path = os.path.join(dest_dir, f"{book['id']}.pdf")
        if os.path.exists(file_path):
            size = os.path.getsize(file_path)
            total_size += size
            print(f"Already downloaded: {book['title']} ({size / 1024 / 1024:.2f} MB)")
            continue
            
        print(f"Downloading {book['title']}...")
        try:
            req = urllib.request.Request(book['pdf_url'], headers={'User-Agent': 'Mozilla/5.0'})
            with urllib.request.urlopen(req, context=ctx, timeout=60) as response, open(file_path, 'wb') as out_file:
                # Read in chunks to avoid memory issues and see progress
                downloaded = 0
                while True:
                    chunk = response.read(1024 * 1024) # 1MB chunks
                    if not chunk:
                        break
                    out_file.write(chunk)
                    downloaded += len(chunk)
                size = downloaded
                total_size += size
                print(f"Successfully downloaded {book['title']} ({size / 1024 / 1024:.2f} MB)")
        except Exception as e:
            print(f"Error downloading {book['title']}: {e}")
            
    print(f"\nAll books downloaded!")
    print(f"Total Size: {total_size / 1024 / 1024:.2f} MB")

if __name__ == "__main__":
    main()
