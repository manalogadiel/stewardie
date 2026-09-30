import { test } from 'node:test';
import assert from 'node:assert/strict';
import { historyStart, hasPlus, taskVisible } from '../../../../supabase/functions/_shared/history_policy.mjs';

test('Basic starts at local midnight three calendar dates ago', () => {
  const now = new Date('2026-09-30T01:00:00Z');
  assert.equal(historyStart(now, 'Asia/Manila').toISOString(), '2026-09-26T16:00:00.000Z');
  assert.equal(historyStart(now, 'America/Los_Angeles').toISOString(), '2026-09-26T07:00:00.000Z');
  assert.equal(historyStart(now, 'Pacific/Kiritimati').toISOString(), '2026-09-26T10:00:00.000Z');
});

test('history boundaries follow daylight-saving transitions', () => {
  assert.equal(historyStart(new Date('2026-03-11T16:00:00Z'), 'America/New_York').toISOString(), '2026-03-08T05:00:00.000Z');
  assert.equal(historyStart(new Date('2026-11-04T17:00:00Z'), 'America/New_York').toISOString(), '2026-11-01T04:00:00.000Z');
});

test('Basic boundary is inclusive, Plus requires an active grant, unfinished work stays visible', () => {
  const now = new Date('2026-09-30T01:00:00Z');
  const space = { timeZone: 'Asia/Manila' };
  const basic = { tier: 'basic' };
  assert.equal(taskVisible({ status: 'completed', completedAt: '2026-09-26T16:00:00Z' }, basic, space, now), true);
  assert.equal(taskVisible({ status: 'completed', completedAt: '2026-09-26T15:59:59.999Z' }, basic, space, now), false);
  assert.equal(taskVisible({ status: 'accepted', createdAt: '2020-01-01' }, basic, space, now), true);
  assert.equal(hasPlus({ tier: 'plus', subscriptionExpiresAt: now.toISOString() }, now), false);
  assert.equal(hasPlus({ tier: 'basic', founderGrant: true }, now), false);
  assert.equal(taskVisible({ status: 'completed', completedAt: '2020-01-01' }, { tier: 'plus', founderGrant: true }, space, now), true);
});
