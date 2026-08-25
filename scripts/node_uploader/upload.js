const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const fs = require('fs');
const path = require('path');

const serviceAccount = require('../../serviceAccountKey.json');

initializeApp({
  credential: cert(serviceAccount)
});

const db = getFirestore();

async function indexHadith() {
  const editionsPath = path.join(__dirname, '../../editions.json');
  if (!fs.existsSync(editionsPath)) {
    console.log("editions.json not found, skipping.");
    return;
  }
  
  console.log("Indexing Hadith Books...");
  // editions.json is utf-16
  const rawData = fs.readFileSync(editionsPath, 'utf16le').replace(/^\uFEFF/, '');
  const editions = JSON.parse(rawData);
  
  const batch = db.batch();
  let count = 0;
  for (const [bookId, bookData] of Object.entries(editions)) {
    const docRef = db.collection("hadith_books").doc(bookId);
    batch.set(docRef, {
      id: bookId,
      name: bookData.name || bookId
    });
    count++;
  }
  
  await batch.commit();
  console.log(`Indexed ${count} hadith books.`);
}

async function indexLibrary() {
  const configPath = path.join(__dirname, '../../rafeeq_config.json');
  if (!fs.existsSync(configPath)) {
    console.log("rafeeq_config.json not found, skipping.");
    return;
  }
  
  console.log("Indexing Library Books...");
  const rawData = fs.readFileSync(configPath, 'utf8');
  const config = JSON.parse(rawData);
  const books = (config.library && config.library.books) ? config.library.books : [];
  
  const batch = db.batch();
  let count = 0;
  for (const book of books) {
    const docRef = db.collection("books").doc(book.id);
    batch.set(docRef, book);
    count++;
  }
  
  await batch.commit();
  console.log(`Indexed ${count} library books.`);
}

async function run() {
  try {
    await indexHadith();
    await indexLibrary();
    console.log("Firestore indexing complete.");
  } catch (error) {
    console.error("Error during indexing:", error);
  }
}

run();
