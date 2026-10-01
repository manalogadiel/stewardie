import test from 'node:test';
import assert from 'node:assert/strict';
import {timestampBatch, pendingPushes} from './query_plan.mjs';

test('event cursor is exclusive and preserves equal-time documents by name', () => {
  const time = '2026-10-01T02:00:00Z';
  const name = 'projects/demo/databases/(default)/documents/spaces/x/events/a';
  const q = timestampBatch('events', 'createdAt', time, {time, name});
  assert.equal(q.limit, 100);
  assert.equal(q.startAt.before, false);
  assert.deepEqual(q.startAt.values, [{timestampValue: time}, {referenceValue: name}]);
  assert.deepEqual(q.orderBy.map(x=>x.field.fieldPath), ['createdAt','__name__']);
});
test('reactions on old photos are queried independently as descendants', () => {
  assert.equal(timestampBatch('reactions','createdAt','2026-10-01T00:00:00Z',undefined,true).from[0].allDescendants,true);
});

test('cursor retains server timestamp precision', () => {
  const time = '2026-10-01T02:00:00.123456Z';
  const q = timestampBatch('events','createdAt',time,{time,name:'projects/demo/databases/(default)/documents/spaces/x/events/a'});
  assert.equal(q.startAt.values[0].timestampValue,time);
});
test('push query excludes delivered history and rotates pending items', () => {
  const q = pendingPushes('projects/demo/databases/(default)/documents/accounts/u/activity/z');
  assert.equal(q.where.fieldFilter.value.stringValue, 'pending');
  assert.equal(q.where.fieldFilter.op, 'EQUAL');
  assert.equal(q.limit,100);
  assert.equal(q.startAt.before,false);
  assert.equal(pendingPushes().startAt,undefined);
});
