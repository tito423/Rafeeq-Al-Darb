import os
from google.oauth2 import service_account
from google.cloud import firestore

cred = service_account.Credentials.from_service_account_file('serviceAccountKey.json')

for db_id in ['(default)', '-default-', 'rafeeq-aldarb']:
    print(f"Trying database_id: {db_id}")
    try:
        db = firestore.Client(project='rafeeq-aldarb', credentials=cred, database=db_id)
        db.collection("test").document("test").set({"hello": "world"})
        print(f"SUCCESS with {db_id}")
        break
    except Exception as e:
        print(f"Failed with {db_id}: {e}")
