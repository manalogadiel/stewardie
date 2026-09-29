import assert from 'node:assert/strict';
import { test } from 'node:test';

import { anonymizeTask, prepareDeletion, processDeletion } from '../lib/account-deletion.mjs';

function fake(uid, { members = ['owner', uid], owner = 'owner', requestStatus = 'pending',
  priorSpaces = [], deletionStatus = null } = {}) {
  const request = { exists: true, get: (field) => ({ uid, email: 'member@example.com',
    status: requestStatus, spaceIds: priorSpaces })[field] };
  const space = { id: 'home', get: (field) => ({ memberUids: members, ownerUid: owner })[field] };
  const db = {
    doc: (path) => ({ get: async () => path === `deletionRequests/${uid}` ? request :
      { get: () => undefined } }),
    collection: (path) => path === 'spaceDeletionJobs'
      ? { where: () => ({ get: async () => ({ docs: deletionStatus
        ? [{ get: () => deletionStatus }] : [] }) }) }
      : { get: async () => ({ docs: [space] }) },
  };
  const auth = { getUser: async () => ({ uid, email: 'member@example.com' }) };
  const sb = { from: () => ({ select: () => ({ eq: () => ({ order: () => ({
    range: async () => ({ data: [], error: null }),
  }) }) }) }) };
  return { db, auth, sb, uid };
}

test('shared task keeps coordination but loses deleted member attribution', () => {
  const patch = anonymizeTask({ creatorUid: 'member', requestedUid: 'member',
    ownerUid: null, status: 'requested', version: 2,
    activity: [{ uid: 'member', name: 'Private Name', action: 'help_requested' }] }, 'member');
  assert.equal(patch.creatorUid, 'deleted-account');
  assert.equal(patch.status, 'unclaimed');
  assert.equal(patch.requestedUid, null);
  assert.equal(patch.version, 3);
  assert.deepEqual(patch.activity[0],
    { uid: null, name: 'Former member', action: 'help_requested' });
});

test('non-owner deletion dry run has no writes', async () => {
  const result = await processDeletion({ ...fake('member') });
  assert.deepEqual(result, { applied: false, sharedSpaces: 1, soloSpaces: 0, photos: 0 });
});

test('owner of a shared space must transfer ownership first', async () => {
  await assert.rejects(prepareDeletion(fake('owner', {
    members: ['owner', 'member'], owner: 'owner',
  })), /Transfer ownership/);
});

test('account deletion waits for unfinished space cleanup', async () => {
  await assert.rejects(prepareDeletion(fake('member', { deletionStatus: 'failed' })),
    /Finish pending space deletion/);
});

test('a sole owner may proceed, but a missing request may not', async () => {
  const inventory = await prepareDeletion(fake('member', {
    members: ['member'], owner: 'member',
  }));
  assert.equal(inventory.summary.soloSpaces, 1);
  await assert.rejects(prepareDeletion(fake('member', { requestStatus: 'complete' })),
    /valid open deletion request/);
});

test('retry inventory still includes a shared space after membership was revoked', async () => {
  const inventory = await prepareDeletion(fake('member', { members: ['owner'],
    requestStatus: 'needsAttention', priorSpaces: ['home'] }));
  assert.equal(inventory.summary.sharedSpaces, 1);
});
