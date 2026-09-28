import assert from 'node:assert/strict';
import test from 'node:test';
import { initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';

import { processDeletion } from '../lib/account-deletion.mjs';

assert.ok(process.env.FIREBASE_AUTH_EMULATOR_HOST);
assert.ok(process.env.FIRESTORE_EMULATOR_HOST);
const projectId = 'demo-stewardie-spark';
const app = initializeApp({ projectId }, `deletion-${Date.now()}`);
const auth = getAuth(app);
const db = getFirestore(app);

class FakeQuery {
  constructor(state, table, mode = 'select', payload = null, filters = []) {
    Object.assign(this, { state, table, mode, payload, filters });
  }
  select() { return this; }
  order() { return this; }
  eq(field, value) { return new FakeQuery(this.state, this.table, this.mode,
    this.payload, [...this.filters, [field, value]]); }
  update(payload) { return new FakeQuery(this.state, this.table, 'update', payload, this.filters); }
  delete() { return new FakeQuery(this.state, this.table, 'delete', null, this.filters); }
  result() {
    const values = this.state[this.table];
    const matched = values.filter((row) => this.filters.every(([field, value]) => row[field] === value));
    if (this.mode === 'delete') this.state[this.table] = values.filter((row) => !matched.includes(row));
    if (this.mode === 'update') matched.forEach((row) => Object.assign(row, this.payload));
    return { data: matched, error: null };
  }
  range(start, end) { const result = this.result(); return Promise.resolve({
    ...result, data: result.data.slice(start, end + 1) }); }
  then(resolve, reject) { return Promise.resolve(this.result()).then(resolve, reject); }
}

function fakeSupabase(customRows) {
  const state = { media_items: customRows ?? [
    { id: 'shared-photo', space_id: 'shared', uploader_uid: 'member', completed_by: null },
    { id: 'solo-photo', space_id: 'solo', uploader_uid: 'member', completed_by: null },
    { id: 'old-photo', space_id: 'solo', uploader_uid: 'former', completed_by: 'member' },
    { id: 'other-photo', space_id: 'shared', uploader_uid: 'owner', completed_by: 'member' },
  ], media_daily: [{ uid: 'member', day: '2026-09-28', count: 2 }] };
  const objects = new Set(state.media_items.flatMap((row) => [
    `${row.space_id}/${row.uploader_uid}/${row.id}/photo.jpg`,
    `${row.space_id}/${row.uploader_uid}/${row.id}/thumb.jpg`,
  ]));
  return { state, objects,
    from: (table) => new FakeQuery(state, table),
    storage: { from: () => ({
      remove: async (paths) => { paths.forEach((path) => objects.delete(path));
        return { data: paths, error: null }; },
      list: async (prefix) => ({ data: [...new Set([...objects]
        .filter((path) => path.startsWith(`${prefix}/`))
        .map((path) => ({ name: path.slice(prefix.length + 1).split('/')[0] })))],
      error: null }),
    }) },
  };
}

test('a disposable two-space account is removed without deleting shared tasks', async () => {
  await auth.createUser({ uid: 'member', email: 'member@example.com',
    emailVerified: true, password: 'LocalOnly!123456' });
  await db.doc('deletionRequests/member').set({ uid: 'member',
    email: 'member@example.com', status: 'pending' });
  await db.doc('accounts/member').set({ tier: 'basic', spaceIds: ['shared', 'solo'] });
  await db.doc('accounts/owner').set({ tier: 'basic', spaceIds: ['shared'] });
  await db.doc('spaces/shared').set({ ownerUid: 'owner', memberUids: ['owner', 'member'],
    memberCount: 2, routineCount: 1 });
  await db.doc('spaces/solo').set({ ownerUid: 'member', memberUids: ['member'],
    memberCount: 1, routineCount: 1 });
  await db.doc('spaces/shared/tasks/task').set({ creatorUid: 'member', requestedUid: 'member',
    ownerUid: null, offeredUid: null, title: 'Shared task', status: 'requested', version: 1,
    activity: [{ uid: 'member', name: 'Private Name' }] });
  await db.doc('spaces/shared/plans/member-plan').set({ ownerUid: 'member',
    participants: ['owner'], revision: 1 });
  await db.doc('spaces/shared/plans/other-plan').set({ ownerUid: 'owner',
    participants: ['member'], revision: 1 });
  await db.doc('spaces/shared/checkIns/member').set({ uid: 'member', mood: 'calm' });
  await db.doc('spaces/shared/routines/member-routine').set({ creatorUid: 'member' });
  await db.doc('spaces/solo/routines/solo-routine').set({ creatorUid: 'member' });
  await db.doc('spaces/solo/moments/old').set({ creatorUid: 'member' });
  await db.doc('accounts/owner/blocks/member').set({ blockedUid: 'member' });
  const sb = fakeSupabase();
  try {
    const preview = await processDeletion({ db, auth, sb, uid: 'member' });
    assert.deepEqual(preview, { applied: false, sharedSpaces: 1, soloSpaces: 1, photos: 3 });
    assert.equal(sb.objects.size, 8);
    const result = await processDeletion({ db, auth, sb, uid: 'member', apply: true });
    assert.equal(result.applied, true);
    await assert.rejects(auth.getUser('member'), /no user record/i);
    assert.equal((await db.doc('accounts/member').get()).exists, false);
    assert.equal((await db.doc('deletionRequests/member').get()).exists, false);
    assert.equal((await db.doc('spaces/solo').get()).exists, false);
    const shared = await db.doc('spaces/shared').get();
    assert.deepEqual(shared.get('memberUids'), ['owner']);
    const task = await db.doc('spaces/shared/tasks/task').get();
    assert.equal(task.get('creatorUid'), 'deleted-account');
    assert.equal(task.get('status'), 'unclaimed');
    assert.equal(task.get('activity')[0].name, 'Former member');
    assert.equal((await db.doc('spaces/shared/plans/member-plan').get()).exists, false);
    assert.deepEqual((await db.doc('spaces/shared/plans/other-plan').get()).get('participants'), []);
    assert.equal((await db.doc('accounts/owner/blocks/member').get()).exists, false);
    assert.equal(sb.objects.size, 2);
    assert.deepEqual(sb.state.media_items.map((row) => row.id), ['other-photo']);
    assert.equal(sb.state.media_items[0].completed_by, null);
  } finally {
    await db.recursiveDelete(db.collection('spaces'));
    await db.recursiveDelete(db.collection('accounts'));
    await db.recursiveDelete(db.collection('deletionRequests'));
    await auth.deleteUser('member').catch(() => {});
  }
});

test('a partial media failure is visible and retry resumes after access revocation', async () => {
  await auth.createUser({ uid: 'retry', email: 'retry@example.com',
    emailVerified: true, password: 'LocalOnly!123456' });
  await db.doc('deletionRequests/retry').set({ uid: 'retry',
    email: 'retry@example.com', status: 'pending' });
  await db.doc('accounts/retry').set({ tier: 'basic', spaceIds: ['retry-space'] });
  await db.doc('spaces/retry-space').set({ ownerUid: 'owner',
    memberUids: ['owner', 'retry'], memberCount: 2 });
  await db.doc('spaces/retry-space/tasks/task').set({ title: 'Keep',
    creatorUid: 'retry', ownerUid: 'retry', requestedUid: null, offeredUid: null,
    status: 'accepted', version: 1 });
  const sb = fakeSupabase([{ id: 'retry-photo', space_id: 'retry-space',
    uploader_uid: 'retry', completed_by: null }]);
  const storage = sb.storage.from('moments');
  const remove = storage.remove;
  let failOnce = true;
  sb.storage.from = () => ({ ...storage, remove: async (paths) => {
    if (failOnce) { failOnce = false; return { data: null,
      error: { message: 'Simulated storage outage' } }; }
    return remove(paths);
  } });
  try {
    await assert.rejects(processDeletion({ db, auth, sb, uid: 'retry', apply: true }),
      /Simulated storage outage/);
    assert.equal((await db.doc('deletionRequests/retry').get()).get('status'), 'needsAttention');
    assert.deepEqual((await db.doc('spaces/retry-space').get()).get('memberUids'), ['owner']);
    assert.equal((await auth.getUser('retry')).disabled, true);
    const result = await processDeletion({ db, auth, sb, uid: 'retry', apply: true });
    assert.equal(result.applied, true);
    assert.equal((await db.doc('spaces/retry-space/tasks/task').get()).get('status'), 'unclaimed');
    assert.equal((await db.doc('deletionRequests/retry').get()).exists, false);
  } finally {
    await db.recursiveDelete(db.collection('spaces'));
    await db.recursiveDelete(db.collection('accounts'));
    await db.recursiveDelete(db.collection('deletionRequests'));
    await auth.deleteUser('retry').catch(() => {});
  }
});

test('historical task attribution is removed after a member already left', async () => {
  await auth.createUser({ uid: 'past', email: 'past@example.com',
    emailVerified: true, password: 'LocalOnly!123456' });
  await db.doc('deletionRequests/past').set({ uid: 'past',
    email: 'past@example.com', status: 'pending' });
  await db.doc('accounts/past').set({ tier: 'basic', spaceIds: [] });
  await db.doc('spaces/former').set({ ownerUid: 'owner',
    memberUids: ['owner'], memberCount: 1 });
  await db.doc('spaces/former/tasks/old').set({ title: 'Keep',
    creatorUid: 'past', ownerUid: null, requestedUid: null, offeredUid: null,
    status: 'unclaimed', version: 1 });
  await db.doc('spaces/former/taskCompletions/old').set({ title: 'Earlier task',
    ownerUid: 'past' });
  await db.doc('spaces/former/locationSessions/owner').set({ uid: 'owner',
    recipientUids: ['owner', 'past'] });
  const sb = fakeSupabase([]);
  try {
    assert.equal((await processDeletion({ db, auth, sb, uid: 'past' })).sharedSpaces, 1);
    await processDeletion({ db, auth, sb, uid: 'past', apply: true });
    assert.equal((await db.doc('spaces/former/tasks/old').get()).get('creatorUid'),
      'deleted-account');
    assert.equal((await db.doc('spaces/former/taskCompletions/old').get()).get('ownerUid'), null);
    assert.deepEqual((await db.doc('spaces/former/locationSessions/owner').get())
      .get('recipientUids'), ['owner']);
    assert.equal((await db.doc('spaces/former').get()).exists, true);
  } finally {
    await db.recursiveDelete(db.collection('spaces'));
    await db.recursiveDelete(db.collection('accounts'));
    await db.recursiveDelete(db.collection('deletionRequests'));
    await auth.deleteUser('past').catch(() => {});
  }
});
