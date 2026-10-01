import {PGlite} from '@electric-sql/pglite';
import {readFile} from 'node:fs/promises';
import test,{before,after} from 'node:test';
import assert from 'node:assert/strict';
const db=new PGlite(); let seq=0,space,member,admin;
const call=async(uid,action,payload={})=>(await db.query('select public.stewardie_core_action($1,$2,$3::jsonb) result',[uid,action,JSON.stringify(payload)])).rows[0].result;
const mutate=(uid,action,payload={})=>call(uid,action,{operationId:`wf_${++seq}`,...payload});
async function join(uid) {
  const code=(await mutate('owner','createInvite',{spaceId:space})).code;
  return mutate(uid,'joinSpace',{code,displayName:uid});
}
before(async()=>{
  await db.exec('create role anon;create role authenticated;create role service_role;');
  for(const name of ['202610010001_core_foundation.sql','202610010002_import_receipts.sql','202610010003_space_workflows.sql','202610010004_task_workflows.sql'])
    await db.exec(await readFile(new URL(`../../supabase/migrations/${name}`,import.meta.url),'utf8'));
  space=(await mutate('owner','createSpace',{name:'Family'})).spaceId;
  member=await join('member');admin=await join('admin');
  await db.query("update stewardie_core.members set role='admin' where space_id=$1 and uid='admin'",[space]);
});
after(()=>db.close());
test('space details and rename require membership and manager role',async()=>{
  assert.equal(member.spaceId,space);assert.equal(admin.spaceId,space);
  await assert.rejects(call('stranger','getSpace',{spaceId:space}),/access ended/);
  await assert.rejects(mutate('member','renameSpace',{spaceId:space,name:'X'}),/managers/);
  await mutate('admin','renameSpace',{spaceId:space,name:' Together '});
  assert.equal((await call('member','getSpace',{spaceId:space})).name,'Together');
  await assert.rejects(mutate('owner','renameSpace',{spaceId:space,name:''}),/space name/);
});
test('invite previews expose only join metadata and reject revoked codes',async()=>{
  const code=(await mutate('owner','createInvite',{spaceId:space})).code;
  assert.match(code,/^[A-HJ-NP-Z]{10}$/);
  const preview=await call('visitor','previewInvite',{code});
  assert.equal(preview.spaceId,space);assert.equal(preview.members,undefined);
  await mutate('owner','revokeInvite',{spaceId:space,code});
  await assert.rejects(call('visitor','previewInvite',{code}),/expired/);
  await assert.rejects(mutate('member','setJoinApprovalPolicy',{spaceId:space,requireApproval:true}),/Only the owner/);
  await assert.rejects(mutate('owner','setJoinApprovalPolicy',{spaceId:space,requireApproval:'true'}),/approval policy/);
});
test('approval reserves invite without granting access; only manager may resolve',async()=>{
  await mutate('owner','setJoinApprovalPolicy',{spaceId:space,requireApproval:true});
  const code=(await mutate('owner','createInvite',{spaceId:space})).code;
  const args={code,displayName:'Applicant',operationId:'pending_once'};
  assert.equal((await call('applicant','requestJoin',args)).pending,true);
  assert.equal((await call('applicant','requestJoin',args)).pending,true);
  await assert.rejects(call('applicant','getSpace',{spaceId:space}),/access ended/);
  await assert.rejects(mutate('other','requestJoin',{code}),/already used/);
  await assert.rejects(mutate('member','resolveJoin',{spaceId:space,memberUid:'applicant',decision:'approve'}),/managers/);
  assert.equal((await call('member','getSpace',{spaceId:space})).pendingJoins.length,0);
  assert.equal((await call('owner','getSpace',{spaceId:space})).pendingJoins.length,1);
  await mutate('owner','resolveJoin',{spaceId:space,memberUid:'applicant',decision:'approve'});
  assert.equal((await call('applicant','listSpaces')).spaces[0].spaceId,space);
  await db.query('update stewardie_core.spaces set require_approval=false where id=$1',[space]);
});
test('approval rechecks account quota and revoked invitations',async()=>{
  await db.query('update stewardie_core.spaces set require_approval=true where id=$1',[space]);
  const code=(await mutate('owner','createInvite',{spaceId:space})).code;
  await mutate('capped','requestJoin',{code});
  for(let i=0;i<3;i++)await mutate('capped','createSpace',{name:`Cap ${i}`});
  await assert.rejects(mutate('owner','resolveJoin',{spaceId:space,memberUid:'capped',decision:'approve'}),/space limit/);
  await mutate('owner','revokeInvite',{spaceId:space,code});
  await assert.rejects(mutate('owner','resolveJoin',{spaceId:space,memberUid:'capped',decision:'approve'}),/unavailable/);
  await db.query('update stewardie_core.spaces set require_approval=false where id=$1',[space]);
});
test('departure releases active assignments, preserves completed tasks and deduplicates retries',async()=>{
  const active=(await mutate('owner','createTask',{spaceId:space,title:'Wash',requestedUid:'member'})).taskId;
  const done=(await mutate('owner','createTask',{spaceId:space,title:'Done',requestedUid:'member'})).taskId;
  await mutate('member','actOnTask',{spaceId:space,taskId:done,action:'accept',expectedVersion:1});
  await mutate('member','actOnTask',{spaceId:space,taskId:done,action:'complete',expectedVersion:2});
  const args={spaceId:space,operationId:'leave_once'};
  await call('member','leaveSpace',args);await call('member','leaveSpace',args);
  await assert.rejects(call('member','getSpace',{spaceId:space}),/access ended/);
  const tasks=(await call('owner','listTasks',{spaceId:space})).tasks;
  assert.equal(tasks.find(t=>t.id===active).status,'unclaimed');
  assert.equal(tasks.find(t=>t.id===active).version,2);
  assert.equal(tasks.find(t=>t.id===done).status,'completed');
  assert.equal(tasks.find(t=>t.id===done).ownerUid,'member');
  assert.equal((await db.query("select count(*)::int n from stewardie_core.events where event_type='left'")).rows[0].n,1);
  await assert.rejects(mutate('owner','leaveSpace',{spaceId:space}),/Transfer ownership/);
});
test('ownership requires explicit nominee acceptance and maintains one owner',async()=>{
  await db.query("insert into stewardie_core.accounts(uid,founder_grant) values('ownedCap',true)");
  await join('ownedCap');
  for(let i=0;i<3;i++)await mutate('ownedCap','createSpace',{name:`Owned ${i}`});
  await db.query("update stewardie_core.accounts set founder_grant=false where uid='ownedCap'");
  await mutate('owner','offerOwnership',{spaceId:space,memberUid:'ownedCap'});
  await assert.rejects(mutate('ownedCap','acceptOwnership',{spaceId:space}),/owned-space limit/);
  assert.equal((await call('owner','getSpace',{spaceId:space})).ownerUid,'owner');
  await assert.rejects(mutate('admin','offerOwnership',{spaceId:space,memberUid:'applicant'}),/Only the owner/);
  await mutate('owner','offerOwnership',{spaceId:space,memberUid:'applicant'});
  await assert.rejects(mutate('admin','acceptOwnership',{spaceId:space}),/not for you/);
  await mutate('applicant','acceptOwnership',{spaceId:space});
  const info=await call('owner','getSpace',{spaceId:space});
  assert.equal(info.ownerUid,'applicant');assert.equal(info.pendingOwnerUid,null);
  assert.equal(info.members.filter(m=>m.role==='owner').length,1);
  assert.equal(info.members.find(m=>m.uid==='owner').role,'member');
  await assert.rejects(mutate('admin','removeMember',{spaceId:space,memberUid:'applicant'}),/Transfer ownership/);
});
test('deletion immediately hides spaces, stops access, and exact owner retry is safe',async()=>{
  await assert.rejects(mutate('owner','deleteSpace',{spaceId:space}),/Only the owner/);
  const args={spaceId:space,operationId:'delete_once'};
  await call('applicant','deleteSpace',args);await call('applicant','deleteSpace',args);
  assert.equal((await call('applicant','listSpaces')).spaces.length,0);
  assert.equal((await call('owner','listSpaces')).spaces.length,0);
  await assert.rejects(call('owner','getSpace',{spaceId:space}),/access ended/);
  await assert.rejects(call('owner','listTasks',{spaceId:space}),/access ended/);
  await assert.rejects(call('owner','deleteSpace',args),/access ended/);
});
test('clients cannot execute either RPC or read pending requests directly',async()=>{
  await db.exec('set role authenticated');
  try {
    await assert.rejects(call('applicant','listSpaces'),/permission denied/);
    await assert.rejects(db.exec('select * from stewardie_core.join_requests'),/permission denied/);
    await assert.rejects(db.exec("select public.stewardie_core_base_action('applicant','listSpaces','{}')"),/permission denied/);
  }finally{await db.exec('reset role');}
});
