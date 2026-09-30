import { test } from 'node:test';
import assert from 'node:assert/strict';
import { joinPlan } from './join_space.mjs';

const now = new Date('2026-09-30T00:00:00Z');
const base = { uid: 'bob', token: 'ABCDEF', name: 'Bob', now,
  invite: { spaceId: 'home', expiresAt: '2026-10-01T00:00:00Z', revoked: false, redeemedUid: null },
  space: { ownerUid: 'alice', memberUids: ['alice'] }, account: { tier: 'basic', spaceIds: [], ownedSpaceIds: [] },
};
test('join creates an ordinary member and atomic event recipient snapshot', () => {
  const plan = joinPlan(base);
  assert.deepEqual(plan.memberUids, ['alice','bob']);
  assert.deepEqual(plan.spaceIds, ['home']);
  assert.equal(plan.member.role, 'member');
  assert.deepEqual(plan.event.recipientUids, ['alice','bob']);
  assert.equal(plan.event.actorUid, 'bob');
});
test('expired, revoked, redeemed, deleted and unapproved invitations are rejected', () => {
  for (const change of [{ revoked: true }, { redeemedUid: 'other' }, { expiresAt: now.toISOString() }]) {
    assert.throws(() => joinPlan({ ...base, invite: { ...base.invite, ...change } }));
  }
  assert.throws(() => joinPlan({ ...base, space: { ...base.space, deletionStatus: 'pending' } }));
  const approval = { ...base, space: { ...base.space, requireApproval: true } };
  assert.throws(() => joinPlan(approval));
  assert.throws(() => joinPlan({ ...approval, pending: { status: 'approved', token: 'WRONG' } }));
  assert.equal(joinPlan({ ...approval, pending: { status: 'approved', token: base.token } }).alreadyJoined, false);
});
test('acknowledgement retries are idempotent and never promote roles or tiers', () => {
  assert.deepEqual(joinPlan({ ...base, invite: { ...base.invite, redeemedUid: 'bob' }, space: { ...base.space, memberUids: ['alice','bob'] } }), { alreadyJoined: true });
  assert.equal(base.account.tier, 'basic');
});
test('Basic and personal Plus retain their protected space limits', () => {
  assert.throws(() => joinPlan({ ...base, space: { ...base.space, memberUids: Array.from({length:20}, (_,i)=>`u${i}`) } }));
  const account = { tier: 'basic', spaceIds: Array.from({length:3}, (_,i)=>`s${i}`) };
  assert.throws(() => joinPlan({ ...base, account }));
  assert.equal(joinPlan({ ...base, account: { ...account, tier: 'plus', founderGrant: true } }).spaceIds.length, 4);
  assert.throws(() => joinPlan({ ...base, account: { ...account, tier: 'plus' } }));
});

