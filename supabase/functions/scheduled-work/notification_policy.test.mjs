import assert from 'node:assert/strict';
import { test } from 'node:test';
import { socialEligible, pushEnabled } from './notification_policy.mjs';
test('unset preferences default on but explicit opt-outs stay off', () => {
  assert.equal(pushEnabled({},{}),true);
  assert.equal(pushEnabled({enabled:false},{}),false);
  assert.equal(pushEnabled({}, {enabled:false}),false);
  assert.equal(socialEligible({},'photos','2026-10-01'),true);
  assert.equal(socialEligible({photos:false},'photos','2026-10-01'),false);
});
test('rollout, preference and membership times exclude historical backlog', () => {
  assert.equal(socialEligible({},'moods','2026-09-29'),false);
  assert.equal(socialEligible({},'photos','2026-09-30T14:40:37Z'),false);
  assert.equal(socialEligible({},'photos','2026-09-30T14:40:38Z'),true);
  assert.equal(socialEligible({},'photos','2026-10-01','2026-10-02'),false);
  assert.equal(socialEligible({updatedAt:'2026-10-03'},'reactions','2026-10-02'),false);
  assert.equal(socialEligible({updatedAt:'2026-10-01'},'reactions','2026-10-02'),true);
});
