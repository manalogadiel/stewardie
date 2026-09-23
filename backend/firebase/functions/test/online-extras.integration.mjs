import assert from 'node:assert/strict';
import test from 'node:test';
import { initializeApp as initializeAdminApp } from 'firebase-admin/app';
import { getAuth as getAdminAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';
import { initializeApp as initializeClientApp, deleteApp } from 'firebase/app';
import { connectAuthEmulator, getAuth, signInWithEmailAndPassword } from 'firebase/auth';
import { connectFunctionsEmulator, getFunctions, httpsCallable } from 'firebase/functions';

assert.ok(process.env.FIREBASE_AUTH_EMULATOR_HOST);
assert.ok(process.env.FIRESTORE_EMULATOR_HOST);
const projectId = 'demo-stewardie';
const admin = initializeAdminApp({ projectId }, `extras-${Date.now()}`);
const authAdmin = getAdminAuth(admin);
const db = getFirestore(admin);

test('online mood and calendar remain member-scoped and author-controlled', async () => {
  const suffix = Date.now().toString(36);
  const uid = `mood-owner-${suffix}`;
  const outsiderUid = `mood-outsider-${suffix}`;
  const password = 'LocalOnly!123456';
  const clients = [];
  let spaceId;
  async function client(id) {
    const email = `${id}@example.test`;
    await authAdmin.createUser({ uid: id, email, password, emailVerified: true });
    const app = initializeClientApp({ apiKey: 'local-demo-key', projectId, appId: id }, id);
    clients.push(app);
    const auth = getAuth(app);
    connectAuthEmulator(auth, 'http://127.0.0.1:9099', { disableWarnings: true });
    await signInWithEmailAndPassword(auth, email, password);
    const functions = getFunctions(app, 'us-central1');
    connectFunctionsEmulator(functions, '127.0.0.1', 5001);
    return (name, data) => httpsCallable(functions, name)(data);
  }
  try {
    const owner = await client(uid);
    const outsider = await client(outsiderUid);
    spaceId = (await owner('createSpace', {
      name: 'Test mood space', kind: 'friends', timeZone: 'Asia/Manila',
    })).data.spaceId;
    await assert.rejects(
      outsider('setCheckIn', { spaceId, mood: 'happy', color: 'rose' }),
      (error) => error.code === 'functions/permission-denied',
    );
    await owner('setCheckIn', { spaceId, mood: 'calm', color: 'sky', note: 'Fine today' });
    const checkIn = await db.doc(`spaces/${spaceId}/checkIns/${uid}`).get();
    assert.equal(checkIn.get('mood'), 'calm');
    assert.equal(checkIn.get('color'), 'sky');
    assert.equal(checkIn.get('note'), 'Fine today');
    assert.ok(checkIn.get('expiresAt').toMillis() > Date.now());
    await owner('removeCheckIn', { spaceId });
    assert.equal((await db.doc(`spaces/${spaceId}/checkIns/${uid}`).get()).exists, false);

    const planId = `plan-${suffix}`;
    const day = Date.UTC(2026, 8, 23);
    const plan = { spaceId, planId, title: 'Shared walk', note: '', allDay: true,
      startMillis: day, endMillis: day + 86400000, participants: [] };
    await owner('savePlan', plan);
    assert.equal((await db.doc(`spaces/${spaceId}/plans/${planId}`).get()).get('ownerUid'), uid);
    await assert.rejects(
      outsider('savePlan', { ...plan, title: 'Forged edit' }),
      (error) => error.code === 'functions/permission-denied',
    );
    await assert.rejects(
      owner('savePlan', { ...plan, participants: [outsiderUid] }),
      (error) => error.code === 'functions/permission-denied',
    );
    await owner('savePlan', { ...plan, title: 'A longer walk' });
    assert.equal((await db.doc(`spaces/${spaceId}/plans/${planId}`).get()).get('title'), 'A longer walk');
    await owner('removePlan', { spaceId, planId });
    assert.equal((await db.doc(`spaces/${spaceId}/plans/${planId}`).get()).exists, false);
  } finally {
    await Promise.all(clients.map(deleteApp));
    if (spaceId) await db.recursiveDelete(db.doc(`spaces/${spaceId}`));
    await Promise.all([uid, outsiderUid].map(async (id) => {
      await db.recursiveDelete(db.doc(`accounts/${id}`));
      await authAdmin.deleteUser(id).catch(() => {});
    }));
  }
});
