import { applicationDefault, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { FieldValue, getFirestore } from 'firebase-admin/firestore';

import { validateFounderTarget } from '../lib/domain.mjs';

const email = process.env.FOUNDER_EMAIL;
const projectId = process.env.GCLOUD_PROJECT || process.env.GOOGLE_CLOUD_PROJECT;
const apply = process.argv.includes('--apply');
const production = process.argv.includes('--production');

if (!email || !projectId) {
  throw new Error('Set FOUNDER_EMAIL and GCLOUD_PROJECT; no address is stored in source.');
}
if (apply && !projectId.startsWith('demo-') && !production) {
  throw new Error('Live grant requires an explicit --production flag.');
}
if (projectId.startsWith('demo-') && !process.env.FIREBASE_AUTH_EMULATOR_HOST) {
  throw new Error('A demo project grant must use the Auth emulator.');
}

const local = Boolean(process.env.FIREBASE_AUTH_EMULATOR_HOST && process.env.FIRESTORE_EMULATOR_HOST);
if (projectId.startsWith('demo-') && !local) {
  throw new Error('A demo grant requires both Auth and Firestore emulators.');
}
const app = initializeApp(local
  ? { projectId }
  : { credential: applicationDefault(), projectId });
const account = await getAuth(app).getUserByEmail(email);
const uid = validateFounderTarget(account, email);
if (!apply) {
  console.log(`Dry run: verified account UID ${uid} in ${projectId} is eligible for founder Plus.`);
  process.exit(0);
}

const db = getFirestore(app);
await db.runTransaction(async (tx) => {
  const markerRef = db.doc('config/founderPlusGrant');
  const accountRef = db.doc(`accounts/${uid}`);
  const marker = await tx.get(markerRef);
  const current = await tx.get(accountRef);
  if (marker.exists && marker.get('uid') !== uid) {
    throw new Error('Founder Plus is already assigned to a different account UID.');
  }
  if (current.exists && current.get('tier') === 'plus' && current.get('entitlementSource') !== 'founder') {
    throw new Error('This account has a different Plus entitlement; do not overwrite it.');
  }
  tx.set(markerRef, { uid, grantedAt: FieldValue.serverTimestamp() }, { merge: true });
  tx.set(accountRef, {
    tier: 'plus', entitlementSource: 'founder',
    entitlementUpdatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });
});
console.log(`Founder Plus granted to verified account UID ${uid} in ${projectId}.`);
