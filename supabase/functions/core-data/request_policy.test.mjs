import test from 'node:test';
import assert from 'node:assert/strict';
import {parseCoreRequest,coreError} from './request_policy.mjs';
test('caller cannot supply an account identity',()=>{
  for(const key of ['uid','userId','p_uid']) assert.throws(()=>parseCoreRequest(JSON.stringify({action:'listSpaces',payload:{[key]:'victim'}})));
});
test('unknown actions and oversized input are rejected',()=>{
  assert.throws(()=>parseCoreRequest('{"action":"grantPlus"}'));
  assert.throws(()=>parseCoreRequest(JSON.stringify({action:'createTask',payload:{notes:'x'.repeat(66000)}})));
  assert.deepEqual(parseCoreRequest('{"action":"listSpaces"}'),{action:'listSpaces',payload:{}});
});
test('server internals and sensitive SQL are not exposed',()=>{
  assert.equal(coreError({code:'XX000',message:'private SQL secret'}).status,503);
  assert.equal(coreError({code:'42501',message:'private'}).status,403);
  assert.equal(coreError({code:'P0001',message:'This task changed'}).status,409);
});
