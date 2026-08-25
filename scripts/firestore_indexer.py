import os
import json
import firebase_admin
from firebase_admin import credentials
from firebase_admin import firestore

# Initialize Firebase Admin with service account
SERVICE_ACCOUNT_PATH = os.environ.get("FIREBASE_SERVICE_ACCOUNT", "serviceAccountKey.json")

from google.oauth2 import service_account
from google.cloud import firestore as google_firestore

def init_firestore():
    if not os.path.exists(SERVICE_ACCOUNT_PATH):
        print(f"ERROR: Service account key not found at {SERVICE_ACCOUNT_PATH}")
        print("Please download it from Firebase Console -> Project Settings -> Service Accounts")
        return None
        
    cred = service_account.Credentials.from_service_account_file(SERVICE_ACCOUNT_PATH)
    # The default database is typically "(default)". If it fails, we can try "-default-"
    try:
        return google_firestore.Client(project='rafeeq-aldarb', credentials=cred, database="(default)")
    except Exception as e:
        print(f"Failed with (default), trying -default-: {e}")
        return google_firestore.Client(project='rafeeq-aldarb', credentials=cred, database="-default-")

def index_hadith(db):
    if not os.path.exists("editions.json"):
        print("editions.json not found, skipping hadith metadata.")
        return
        
    print("Indexing Hadith Books to Firestore...")
    with open("editions.json", "r", encoding="utf-16") as f:
        editions = json.load(f)
        
    batch = db.batch()
    for book_id, book_data in editions.items():
        doc_ref = db.collection("hadith_books").document(book_id)
        # Avoid storing the massive collection array in the document if it exists, just metadata
        metadata = {
            "id": book_id,
            "name": book_data.get("name", book_id)
        }
        batch.set(doc_ref, metadata)
    
    batch.commit()
    print(f"Indexed {len(editions)} hadith books.")

def index_library(db):
    if not os.path.exists("rafeeq_config.json"):
        return
        
    print("Indexing Library Books to Firestore...")
    with open("rafeeq_config.json", "r", encoding="utf-8", errors="ignore") as f:
        config = json.load(f)
        
    books = config.get("library", {}).get("books", [])
    batch = db.batch()
    for book in books:
        doc_ref = db.collection("books").document(book["id"])
        batch.set(doc_ref, book)
        
    batch.commit()
    print(f"Indexed {len(books)} library books.")

if __name__ == "__main__":
    db = init_firestore()
    if db:
        index_hadith(db)
        index_library(db)
        print("Firestore indexing complete.")
