import firebase_admin
from firebase_admin import credentials, firestore
import sys

# Usage: python update_firestore_urls.py <R2_BASE_URL>
# Example: python update_firestore_urls.py "https://pub-123456.r2.dev"

if len(sys.argv) < 2:
    print("Usage: python update_firestore_urls.py <R2_BASE_URL>")
    print("Please provide your public R2 dev URL.")
    sys.exit(1)

R2_BASE_URL = sys.argv[1].rstrip('/')

# Define mapping: collection_name -> zip_file_name
MAPPINGS = {
    'books': f"{R2_BASE_URL}/hadith.zip", # In this database, books contains Bukhari & Muslim
    'hadith_books': f"{R2_BASE_URL}/hadith.zip",
    'tafsir': f"{R2_BASE_URL}/tafsir.zip",
    # Add other collections if needed
}

from google.oauth2 import service_account
from google.cloud import firestore as google_firestore

def init_firestore():
    cred = service_account.Credentials.from_service_account_file('../serviceAccountKey.json')
    return google_firestore.Client(project='rafeeq-aldarb', credentials=cred, database="-default-")

def main():
    db = init_firestore()
    
    total_updated = 0

    for collection_name, zip_url in MAPPINGS.items():
        print(f"Updating collection '{collection_name}' with URL: {zip_url} ...")
        collection_ref = db.collection(collection_name)
        docs = collection_ref.stream()
        
        count = 0
        batch = db.batch()
        batch_count = 0
        
        for doc in docs:
            # We update the download_url field for each document
            batch.update(doc.reference, {'download_url': zip_url})
            count += 1
            batch_count += 1
            
            # Commit in batches of 400 (Firestore limit is 500)
            if batch_count >= 400:
                batch.commit()
                batch_count = 0
                print(f"  Committed batch for {collection_name}...")
                
        # Commit remaining
        if batch_count > 0:
            batch.commit()
            
        print(f"Finished updating {count} documents in '{collection_name}'.")
        total_updated += count

    print(f"\nSuccessfully updated {total_updated} total documents in Firestore.")

if __name__ == '__main__':
    main()
