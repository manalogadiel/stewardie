import assert from 'node:assert/strict';
import test from 'node:test';
import {
  accountLimits,
  basicHistoryStart,
  DomainError,
  localCalendarDate,
  transitionTask,
  validateFounderTarget,
} from '../lib/domain.mjs';

const task = {
  status: 'requested', ownerUid: null, requestedUid: 'jamie',
  offeredUid: null, completedAt: null,
};

test('personal Plus changes only account caps', () => {
  assert.deepEqual(accountLimits('basic'), { ownedSpaces: 3, memberships: 20 });
  assert.deepEqual(accountLimits('plus'), { ownedSpaces: 20, memberships: 50 });
});

test('Basic history uses space-local calendar dates across midnight', () => {
  const instant = new Date('2026-09-23T01:00:00Z');
  assert.equal(localCalendarDate(instant, 'Asia/Manila'), '2026-09-23');
  assert.equal(basicHistoryStart(instant, 'Asia/Manila'), '2026-09-20');
  assert.equal(localCalendarDate(instant, 'America/Los_Angeles'), '2026-09-22');
  assert.equal(basicHistoryStart(instant, 'America/Los_Angeles'), '2026-09-19');
});

test('a request is not accepted until the recipient acts', () => {
  assert.equal(transitionTask(task, 'accept', 'jamie').ownerUid, 'jamie');
  assert.throws(() => transitionTask(task, 'accept', 'alex'), DomainError);
  assert.deepEqual(transitionTask(task, 'decline', 'jamie'), {
    status: 'unclaimed', ownerUid: null, requestedUid: null,
    offeredUid: null, completedAt: null,
  });
});

test('help offers do not replace an owner without confirmation', () => {
  const needingHelp = { ...task, status: 'needsHelp', ownerUid: 'jamie', requestedUid: null };
  const offered = transitionTask(needingHelp, 'offerHelp', 'alex');
  assert.equal(offered.ownerUid, 'jamie');
  assert.equal(offered.offeredUid, 'alex');
  assert.equal(transitionTask(offered, 'confirmHandoff', 'jamie').ownerUid, 'alex');
  assert.throws(() => transitionTask(offered, 'confirmHandoff', 'alex'), DomainError);
});

test('completion remains available for a Basic owner', () => {
  const accepted = { ...task, status: 'accepted', ownerUid: 'jamie', requestedUid: null };
  const done = transitionTask(accepted, 'complete', 'jamie', '2026-09-23T10:00:00Z');
  assert.equal(done.status, 'completed');
  assert.equal(done.completedAt, '2026-09-23T10:00:00Z');
  assert.throws(() => transitionTask(done, 'complete', 'jamie'), DomainError);
});

test('founder grant requires the exact verified account', () => {
  const record = { uid: 'stable-uid', email: 'owner@example.com', emailVerified: true };
  assert.equal(validateFounderTarget(record, 'OWNER@example.com'), 'stable-uid');
  assert.throws(() => validateFounderTarget({ ...record, emailVerified: false }, record.email), DomainError);
  assert.throws(() => validateFounderTarget(record, 'other@example.com'), DomainError);
});
