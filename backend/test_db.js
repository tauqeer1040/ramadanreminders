require('dotenv').config();
const admin = require('firebase-admin');

// Initialize Firebase Admin
admin.initializeApp({
  credential: admin.credential.cert({
    projectId: process.env.FIREBASE_PROJECT_ID,
    clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
    privateKey: process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n'),
  }),
});

const db = admin.firestore();

async function testConnection() {
  console.log("Adding dummy user document to Firestore...");
  
  try {
    await db.collection('users').doc('TEST_UID_123').set({
      welcome_message: "Hello! The Node.js terminal successfully wrote this natively!",
      timestamp: admin.firestore.FieldValue.serverTimestamp()
    });
    
    console.log("✅ SUCCESS: Data written to Firestore!");
    console.log("👉 Go check your Firebase Firestore console right now!");
  } catch (err) {
    console.error("❌ ERROR writing to Firestore:", err);
  }
  
  process.exit(0);
}

testConnection();
