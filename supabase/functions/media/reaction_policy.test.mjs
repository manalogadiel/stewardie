import assert from 'node:assert/strict';
import { test } from 'node:test';
import { assertReactionAccess } from './reaction_policy.mjs';
const valid = {photo:{id:'p',space_id:'a',state:'ready',published_at:'2026-09-30'},photoId:'p',spaceId:'a',uid:'me',members:['me','author'],change:true,type:'like'};
test('only a real published canonical photo admits reactions', () => {
  assert.doesNotThrow(() => assertReactionAccess(valid));
  for (const photo of [null,{...valid.photo,id:'fake'},{...valid.photo,space_id:'b'},{...valid.photo,state:'deleted'},{...valid.photo,published_at:null}]) {
    assert.throws(() => assertReactionAccess({...valid,photo}), e => e.status === 404);
  }
});
test('removed, unauthorized and blocked accounts cannot react', () => {
  for (const patch of [{uid:'outsider'},{members:['author']},{blocked:true}]) {
    assert.throws(() => assertReactionAccess({...valid,...patch}), e => e.status === 403);
  }
});
test('six types and removal are allowed; arbitrary types are rejected', () => {
  for (const type of ['like','cheer','haha','sad','heart','mad',null]) assert.doesNotThrow(() => assertReactionAccess({...valid,type}));
  assert.throws(() => assertReactionAccess({...valid,type:'fake'}), e => e.status === 400);
});
