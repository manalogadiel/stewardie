import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import test from 'node:test';
import { fileURLToPath } from 'node:url';
import { initializeApp as initializeAdminApp } from 'firebase-admin/app';
import { getAuth as getAdminAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';
import { initializeApp as initializeClientApp, deleteApp } from 'firebase/app';
import {
  connectAuthEmulator, getAuth, signInWithEmailAndPassword,
} from 'firebase/auth';
import {
  connectFunctionsEmulator, getFunctions, httpsCallable,
} from 'firebase/functions';

const projectId = 'demo-stewardie';
assert.ok(process.env.FIREBASE_AUTH_EMULATOR_HOST);
assert.ok(process.env.FIRESTORE_EMULATOR_HOST);

const admin = initializeAdminApp({ projectId });
const adminAuth = getAdminAuth(admin);
const db = getFirestore(admin);

async function clientFor(uid, email, verified) {
  const password = 'LocalTrialOnly!12345';
  await adminAuth.createUser({ uid, email, emailVerified: verified, password });
  const app = initializeClientApp({
    apiKey: 'local-demo-key', projectId, appId: `local-${uid}`,
  }, uid);
  const auth = getAuth(app);
  connectAuthEmulator(auth, 'http://127.0.0.1:9099', { disableWarnings: true });
  await signInWithEmailAndPassword(auth, email, password);
  const functions = getFunctions(app, 'us-central1');
  connectFunctionsEmulator(functions, '127.0.0.1', 5001);
  return { app, call: (name, payload) => httpsCallable(functions, name)(payload) };
}

test('local callables enforce membership, task ownership, quotas and founder Plus', async () => {
  const founder = await clientFor('founder123', 'founder@example.test', true);
  const member = await clientFor('member123', 'member@example.test', true);
  const unverified = await clientFor('unverified123', 'unverified@example.test', false);
  try {
    await assert.rejects(
      unverified.call('createSpace', { name: 'Unverified', kind: 'family', timeZone: 'Asia/Manila' }),
      (error) => error.code === 'functions/unauthenticated',
    );
    const makeSpace = (name) => founder.call('createSpace', {
      name, kind: 'family', timeZone: 'Asia/Manila',
    });
    const first = (await makeSpace('Home')).data.spaceId;
    await makeSpace('Second');
    await makeSpace('Third');
    await assert.rejects(makeSpace('Fourth'), (error) => error.code === 'functions/resource-exhausted');
    await assert.rejects(
      member.call('createTask', { spaceId: first, title: 'Cannot add' }),
      (error) => error.code === 'functions/permission-denied',
    );

    const taskId = (await founder.call('createTask', {
      spaceId: first, title: 'Wash dishes',
    })).data.taskId;
    await assert.rejects(
      member.call('actOnTask', { spaceId: first, taskId, operationId: 'operation1', action: 'accept' }),
      (error) => error.code === 'functions/permission-denied',
    );
    const accepted = (await founder.call('actOnTask', {
      spaceId: first, taskId, operationId: 'operation2', action: 'accept',
    })).data;
    assert.equal(accepted.version, 2);
    const duplicate = (await founder.call('actOnTask', {
      spaceId: first, taskId, operationId: 'operation2', action: 'accept',
    })).data;
    assert.equal(duplicate.alreadyApplied, true);
    await founder.call('actOnTask', {
      spaceId: first, taskId, operationId: 'operation3', action: 'complete',
    });
    assert.equal((await db.doc(`spaces/${first}`).get()).get('activeTaskCount'), 0);
    await db.doc(`spaces/${first}/tasks/oldtask123`).set({
      title: 'Old completed task', status: 'completed',
      completedAt: '2026-01-01T00:00:00Z', completedLocalDate: '2026-01-01',
    });
    const basicHistory = (await founder.call('listCompletedTasks', { spaceId: first })).data;
    assert.deepEqual(basicHistory.tasks.map((item) => item.id), [taskId]);
    assert.equal(basicHistory.totalCount, 1);
    await assert.rejects(
      member.call('listCompletedTasks', { spaceId: first }),
      (error) => error.code === 'functions/permission-denied',
    );

    const invite = (await founder.call('createInvite', { spaceId: first })).data;
    assert.equal(invite.token.length, 32);
    assert.equal((await unverified.call('previewInvite', { token: invite.token })).data.spaceName, 'Home');
    await assert.rejects(
      member.call('createInvite', { spaceId: first }),
      (error) => error.code === 'functions/permission-denied',
    );
    assert.equal((await member.call('redeemInvite', { token: invite.token })).data.alreadyMember, false);
    assert.equal((await member.call('redeemInvite', { token: invite.token })).data.alreadyMember, true);
    const contestedTask = (await founder.call('createTask', {
      spaceId: first, title: 'Claim together',
    })).data.taskId;
    const claims = await Promise.allSettled([
      founder.call('actOnTask', {
        spaceId: first, taskId: contestedTask,
        operationId: 'claimfounder1', action: 'accept',
      }),
      member.call('actOnTask', {
        spaceId: first, taskId: contestedTask,
        operationId: 'claimmember1', action: 'accept',
      }),
    ]);
    assert.equal(claims.filter((claim) => claim.status === 'fulfilled').length, 1);
    assert.equal((await db.doc(`spaces/${first}/tasks/${contestedTask}`).get()).get('status'), 'accepted');
    const sharedTask = (await founder.call('createTask', {
      spaceId: first, title: 'Shared task', requestedUid: 'member123',
    })).data.taskId;
    await member.call('actOnTask', {
      spaceId: first, taskId: sharedTask, operationId: 'operation4', action: 'accept',
    });
    await member.call('actOnTask', {
      spaceId: first, taskId: sharedTask, operationId: 'operation5', action: 'complete',
    });
    assert.equal((await db.doc('accounts/member123').get()).get('tier'), 'basic');
    await founder.call('revokeInvite', { token: invite.token });
    await assert.rejects(
      unverified.call('previewInvite', { token: invite.token }),
      (error) => error.code === 'functions/not-found',
    );

    const grantEnv = {
      ...process.env,
      GCLOUD_PROJECT: projectId,
      FOUNDER_EMAIL: 'founder@example.test',
    };
    const grantScript = fileURLToPath(new URL('../scripts/grant-founder-plus.mjs', import.meta.url));
    const dryRun = execFileSync(process.execPath, [grantScript], {
      env: grantEnv, encoding: 'utf8',
    });
    assert.match(dryRun, /Dry run/);
    assert.equal((await db.doc('accounts/founder123').get()).get('tier'), 'basic');
    execFileSync(process.execPath, [grantScript, '--apply'], { env: grantEnv });
    assert.equal((await db.doc('accounts/founder123').get()).get('tier'), 'plus');
    const plusHistory = (await founder.call('listCompletedTasks', { spaceId: first })).data;
    assert.equal(plusHistory.tasks.length, 3);
    assert.equal(plusHistory.totalCount, 3);
    const memberHistory = (await founder.call('listCompletedTasks', {
      spaceId: first, personUid: 'member123',
    })).data;
    assert.deepEqual(memberHistory.tasks.map((item) => item.id), [sharedTask]);
    const fourth = (await makeSpace('Fourth')).data.spaceId;
    assert.ok(fourth);
    assert.equal((await db.doc('accounts/member123').get()).get('tier'), 'basic');
    assert.equal((await db.doc('config/founderPlusGrant').get()).get('uid'), 'founder123');
  } finally {
    await Promise.all([founder, member, unverified].map(({ app }) => deleteApp(app)));
  }
});
