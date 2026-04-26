require('dotenv').config();
const admin = require('firebase-admin');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert({
      projectId: process.env.FIREBASE_PROJECT_ID,
      clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
      privateKey: process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n'),
    }),
  });
}
const db = admin.firestore();

async function readLastInsight() {
  try {
    const snap = await db.collection('users').doc('TEST_UID_123').collection('insights').doc('2026-03-24').get();
    if (snap.exists) {
        console.log("Insight for 2026-03-24:");
        console.log(JSON.stringify(snap.data(), null, 2));
    } else {
        console.log("Insight not found!");
    }

    const userSnap = await db.collection('users').doc('TEST_UID_123').get();
    if (userSnap.exists) {
        console.log("\nUser Tags:");
        console.log(JSON.stringify(userSnap.data().relevantTaskTags, null, 2));
    }
  } catch (e) {
    console.error(e);
  }
  process.exit(0);
}

readLastInsight();
