const fs = require('fs');
const path = require('path');
const { S3Client, PutObjectCommand } = require('@aws-sdk/client-s3');

const R2_ACCOUNT_ID = 'e8edfc13bb53ce91a561113de8f080ed';
const R2_ACCESS_KEY_ID = 'c13c77ebfc7750fc3de780b48dbcc00e';
const R2_SECRET_ACCESS_KEY = 'a84aeb272ab31776999a4c52f6f1c4df2e96495d43eec3e4f3c7e75cc8cf1689';
const BUCKET_NAME = 'rafeeq';
const PUBLIC_URL = 'https://pub-b9273af6154c4a618f813447e8a9fc09.r2.dev';

const s3Client = new S3Client({
  region: 'auto',
  endpoint: `https://${R2_ACCOUNT_ID}.r2.cloudflarestorage.com`,
  credentials: {
    accessKeyId: R2_ACCESS_KEY_ID,
    secretAccessKey: R2_SECRET_ACCESS_KEY,
  }
});

async function uploadFolder(folderPath) {
  const files = fs.readdirSync(folderPath);
  
  for (const filename of files) {
    if (filename.endsWith('.json')) {
      const filePath = path.join(folderPath, filename);
      const objectName = `books/texts/${filename}`;
      
      console.log(`Uploading ${filename} to ${objectName}...`);
      
      const fileStream = fs.createReadStream(filePath);
      
      const uploadParams = {
        Bucket: BUCKET_NAME,
        Key: objectName,
        Body: fileStream,
        ContentType: 'application/json; charset=utf-8'
      };
      
      try {
        await s3Client.send(new PutObjectCommand(uploadParams));
        const downloadUrl = `${PUBLIC_URL}/${objectName}`;
        console.log(`File accessible at: ${downloadUrl}`);
      } catch (err) {
        console.error(`Error uploading ${filename}:`, err);
      }
    }
  }
}

const scrapedDir = path.join(__dirname, 'test_upload');
if (fs.existsSync(scrapedDir)) {
  uploadFolder(scrapedDir).then(() => console.log('Done.'));
} else {
  console.log(`Directory ${scrapedDir} not found.`);
}
