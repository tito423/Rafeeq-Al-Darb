import os
import json
import firebase_admin
from firebase_admin import credentials
from firebase_admin import firestore

# Initialize Firebase Admin with service account
# The user needs to download their service account JSON from Firebase Console
SERVICE_ACCOUNT_PATH = os.environ.get("FIREBASE_SERVICE_ACCOUNT", "../android/app/firebase-adminsdk.json")

def init_firestore():
    if not os.path.exists(SERVICE_ACCOUNT_PATH):
        print(f"ERROR: Service account key not found at {SERVICE_ACCOUNT_PATH}")
        print("Please download it from Firebase Console -> Project Settings -> Service Accounts")
        return None
        
    cred = credentials.Certificate(SERVICE_ACCOUNT_PATH)
    firebase_admin.initialize_app(cred)
    return firestore.client()

def index_mushafs(db):
    if not os.path.exists("../editions.json"):
        print("editions.json not found, skipping mushafs.")
        return
        
    print("Indexing Mushafs to Firestore...")
    with open("../editions.json", "r", encoding="utf-8") as f:
        editions = json.load(f)
        
    batch = db.batch()
    for edition in editions:
        doc_ref = db.collection("mushafs").document(edition["id"])
        batch.set(doc_ref, edition)
    
    batch.commit()
    print(f"Indexed {len(editions)} mushafs.")

def index_library(db):
    if not os.path.exists("../rafeeq_config.json"):
        return
        
    print("Indexing Library Books to Firestore...")
    with open("../rafeeq_config.json", "r", encoding="utf-8") as f:
        config = json.load(f)
        
    books = config.get("library", {}).get("books", [])
    batch = db.batch()
    for book in books:
        doc_ref = db.collection("books").document(book["id"])
        batch.set(doc_ref, book)
        
    batch.commit()
    print(f"Indexed {len(books)} books.")

if __name__ == "__main__":
    db = init_firestore()
    if db:
        index_mushafs(db)
        index_library(db)
        print("Firestore indexing complete.")
