import { test } from 'node:test';
import assert from 'node:assert/strict';
import { locationSession } from './location_session.mjs';
const now = new Date('2026-09-30T07:00:00Z');
const input = { uid: 'alice', space: { memberUids: ['alice','bob'] }, name: 'Alice', lat: 14.6, lng: 121, accuracy: 10, durationMinutes: 15, now };
test('expiry uses trusted time and immutable recipient snapshot, not client timestamps', () => {
  const session = locationSession({ ...input, startedAt: '2099-01-01', expiresAt: '2099-01-01', recipientUids: ['mallory'] });
  assert.equal(session.startedAt, now.toISOString());
  assert.equal(session.expiresAt, '2026-09-30T07:15:00.000Z');
  assert.deepEqual(session.recipientUids, ['alice','bob']);
  input.space.memberUids.push('later');
  assert.deepEqual(session.recipientUids, ['alice','bob']);
  input.space.memberUids.pop();
});
test('nonmembers, deleted spaces and invalid positions/durations are refused', () => {
  for (const patch of [{uid:'mallory'}, {space:null}, {space:{...input.space,deletionStatus:'pending'}}, {durationMinutes:90}, {lat:NaN}, {lat:91}, {lng:181}, {accuracy:-1}, {accuracy:10001}]) {
    assert.throws(() => locationSession({ ...input, ...patch }));
  }
});
