import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test, { after, before, beforeEach } from 'node:test';
import { fileURLToPath } from 'node:url';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';

const rules = readFileSync(
  fileURLToPath(new URL('../../firestore.rules', import.meta.url)),
  'utf8',
);
let environment;

before(async () => {
  environment = await initializeTestEnvironment({
    projectId: 'demo-stewardie-rules',
    firestore: { rules, host: '127.0.0.1', port: 8080 },
  });
});
after(async () => environment?.cleanup());
beforeEach(async () => {
  await environment.clearFirestore();
  await environment.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await db.doc('accounts/alice').set({ tier: 'basic' });
    await db.doc('accounts/bob').set({ tier: 'plus' });
    await db.doc('spaces/space12345').set({ name: 'Home' });
    await db.doc('spaces/space12345/members/alice').set({ status: 'active' });
    await db.doc('spaces/space12345/members/bob').set({ status: 'removed' });
    await db.doc('spaces/space12345/tasks/task12345').set({
      title: 'Dishes', status: 'unclaimed',
    });
    await db.doc('spaces/space12345/tasks/done12345').set({
      title: 'Old dishes', status: 'completed',
    });
    await db.doc('spaces/space12345/checkIns/alice').set({ mood: 'calm' });
    await db.doc('spaces/space12345/plans/plan12345').set({ title: 'A walk' });
  });
});

function db(uid, verified = true) {
  return environment.authenticatedContext(uid, {
    email_verified: verified,
  }).firestore();
}

test('a verified member can read only their own account and active space', async () => {
  await assertSucceeds(db('alice').doc('accounts/alice').get());
  await assertFails(db('alice').doc('accounts/bob').get());
  await assertSucceeds(db('alice').doc('spaces/space12345').get());
  await assertSucceeds(db('alice').doc('spaces/space12345/tasks/task12345').get());
  await assertSucceeds(db('alice').collection('spaces/space12345/tasks')
    .where('status', '!=', 'completed').get());
  await assertFails(db('alice').doc('spaces/space12345/tasks/done12345').get());
  await assertFails(db('bob').doc('spaces/space12345/tasks/task12345').get());
  await assertFails(db('outsider').doc('spaces/space12345').get());
});

test('unverified users cannot read even their own account', async () => {
  await assertFails(db('alice', false).doc('accounts/alice').get());
  await assertFails(db('alice', false).doc('spaces/space12345').get());
});

test('clients cannot forge Plus, membership or task completion', async () => {
  await assertFails(db('alice').doc('accounts/alice').update({ tier: 'plus' }));
  await assertFails(db('alice').doc('spaces/space12345/members/bob').update({ status: 'active' }));
  await assertFails(db('alice').doc('spaces/space12345/tasks/task12345').update({ status: 'completed' }));
  const snapshot = await db('alice').doc('accounts/alice').get();
  assert.equal(snapshot.get('tier'), 'basic');
});

test('moods and plans are member-readable but server-written', async () => {
  await assertSucceeds(db('alice').doc('spaces/space12345/checkIns/alice').get());
  await assertSucceeds(db('alice').collection('spaces/space12345/plans').get());
  await assertFails(db('bob').doc('spaces/space12345/checkIns/alice').get());
  await assertFails(db('outsider').doc('spaces/space12345/plans/plan12345').get());
  await assertFails(db('alice').doc('spaces/space12345/checkIns/alice').set({ mood: 'happy' }));
  await assertFails(db('alice').doc('spaces/space12345/plans/plan12345').delete());
});
