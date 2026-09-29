import assert from 'node:assert/strict';
import { test } from 'node:test';
import { eventInboxId, eventRecipients } from './event_delivery.mjs';

test('coverage uses its recipient snapshot after a task changes again', () => {
  const event = {
    type: 'covered', actorUid: 'bob',
    recipientUids: ['alice', 'bob', 'carol'],
    affectedUids: ['alice', 'bob'],
  };
  assert.deepEqual(eventRecipients(event, ['alice', 'bob', 'carol'], ['carol']), ['alice']);
});

test('removed and newly joined members cannot receive an old event', () => {
  const event = {
    type: 'joined', actorUid: 'alice',
    recipientUids: ['alice', 'bob', 'carol'],
  };
  assert.deepEqual(eventRecipients(event, ['alice', 'carol', 'dave']), ['carol']);
});

test('direct requests reach only their current target', () => {
  const event = {
    type: 'taskAssigned', actorUid: 'alice', targetUid: 'bob',
    recipientUids: ['alice', 'bob', 'carol'],
  };
  assert.deepEqual(eventRecipients(event, ['alice', 'bob', 'carol']), ['bob']);
  assert.deepEqual(eventRecipients(event, ['alice', 'carol']), []);
});

test('retries address the same inbox document and do not duplicate recipients', () => {
  const event = {
    type: 'completed', actorUid: 'bob',
    recipientUids: ['alice', 'alice', 'bob'], affectedUids: ['alice', 'bob'],
  };
  assert.deepEqual(eventRecipients(event, ['alice', 'bob']), ['alice']);
  assert.equal(eventInboxId('home', 'task_12'), eventInboxId('home', 'task_12'));
  assert.notEqual(eventInboxId('home', 'task_12'), eventInboxId('home', 'task_13'));
});
