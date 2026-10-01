import { test } from 'node:test';
import assert from 'node:assert/strict';
import { visibleLocations } from './visible_locations.mjs';

const now = new Date('2026-10-01T00:00:00Z');
const space = { memberUids: ['alice', 'bob', 'new-member'] };
const session = { uid: 'alice', recipientUids: ['alice', 'bob'], expiresAt: '2026-10-01T00:15:00Z', lat: 14, lng: 121 };

test('only recipients can see active locations; joining does not expand access', () => {
  assert.deepEqual(visibleLocations('bob', space, [session], now), [session]);
  assert.deepEqual(visibleLocations('new-member', space, [session], now), []);
  assert.throws(() => visibleLocations('outsider', space, [session], now), /no longer/);
});
test('expiry, stopped sessions and departed senders are excluded', () => {
  assert.deepEqual(visibleLocations('bob', space, [{ ...session, expiresAt: now.toISOString() }], now), []);
  assert.deepEqual(visibleLocations('bob', space, [], now), []);
  assert.deepEqual(visibleLocations('bob', { memberUids: ['bob'] }, [session], now), []);
  assert.throws(() => visibleLocations('bob', { ...space, deletionStatus: 'pending' }, [session], now), /no longer/);
});
test('invalid coordinates and missing audience are never exposed', () => {
  assert.deepEqual(visibleLocations('bob', space, [{ ...session, lat: 100 }, { ...session, recipientUids: undefined }], now), []);
});
