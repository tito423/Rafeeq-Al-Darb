const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const serviceAccount = require('../serviceAccountKey.json');

initializeApp({
  credential: cert(serviceAccount)
});

const db = getFirestore();
const R2_BASE_URL = "https://pub-b9273af6154c4a618f813447e8a9fc09.r2.dev";

const MAPPINGS = {
    'books': `${R2_BASE_URL}/hadith.zip`,
    'hadith_books': `${R2_BASE_URL}/hadith.zip`,
    'tafsir': `${R2_BASE_URL}/tafsir.zip`,
};

async function updateCollection(collectionName, zipUrl) {
    const snapshot = await db.collection(collectionName).get();
    let count = 0;
    
    // Firestore batch limit is 500
    let batch = db.batch();
    let batchCount = 0;

    for (const doc of snapshot.docs) {
        batch.update(doc.ref, { download_url: zipUrl });
        count++;
        batchCount++;

        if (batchCount === 400) {
            await batch.commit();
            batch = db.batch();
            batchCount = 0;
        }
    }

    if (batchCount > 0) {
        await batch.commit();
    }
    console.log(`Updated ${count} documents in ${collectionName}`);
    return count;
}

async function main() {
    let total = 0;
    for (const [collection, url] of Object.entries(MAPPINGS)) {
        total += await updateCollection(collection, url);
    }
    console.log(`Successfully updated ${total} documents total.`);
}

main().catch(console.error);
