import {PGlite} from '@electric-sql/pglite';
import {readFile} from 'node:fs/promises';
import test, {before,after} from 'node:test';
import assert from 'node:assert/strict';
const db=new PGlite();
let seq=0;
const call=async(uid,action,payload={})=>(await db.query(
  'select public.stewardie_core_action($1,$2,$3::jsonb) result',
  [uid,action,JSON.stringify(payload)])).rows[0].result;
const mutate=(uid,action,payload={})=>call(uid,action,{operationId:`op_${++seq}`,...payload});
let space,task,invite;
before(async()=>{
  await db.exec('create role anon; create role authenticated; create role service_role;');
  await db.exec(await readFile(new URL('../../supabase/migrations/202610010001_core_foundation.sql',import.meta.url),'utf8'));
  for(const name of ['202610010002_import_receipts.sql','202610010003_space_workflows.sql','202610010004_task_workflows.sql'])
    await db.exec(await readFile(new URL(`../../supabase/migrations/${name}`,import.meta.url),'utf8'));
});
after(()=>db.close());
test('create and retry preserve one space; forged Plus cannot bypass Basic cap',async()=>{
  const args={name:'Home',displayName:'A',operationId:'stable_create'};
  space=(await call('a','createSpace',args)).spaceId;
  assert.equal((await call('a','createSpace',args)).spaceId,space);
  await assert.rejects(call('a','createSpace',{...args,name:'Other'}),/already used/);
  await mutate('a','createSpace',{name:'Two',isPlus:true});
  await mutate('a','createSpace',{name:'Three',tier:'plus'});
  await assert.rejects(mutate('a','createSpace',{name:'Four',isPlus:true}),/space limit/);
  assert.equal((await call('a','listSpaces')).spaces.length,3);
});
test('invite and join enforce single use, role and current membership',async()=>{
  await assert.rejects(mutate('outsider','createInvite',{spaceId:space}),/access ended/);
  invite=(await mutate('a','createInvite',{spaceId:space})).code;
  const joined=await mutate('b','joinSpace',{code:invite,displayName:'B'});
  assert.equal(joined.spaceId,space);
  assert.equal((await call('b','listSpaces')).spaces.length,1);
  await assert.rejects(mutate('c','joinSpace',{code:invite}),/already used/);
  await assert.rejects(mutate('b','createInvite',{spaceId:space}),/managers/);
});
test('assignment recipient alone accepts, stale writes fail, retries do not duplicate events',async()=>{
  task=(await mutate('a','createTask',{spaceId:space,title:'Wash dishes',requestedUid:'b'})).taskId;
  await assert.rejects(mutate('a','actOnTask',{spaceId:space,taskId:task,action:'accept',expectedVersion:1}),/cannot perform/);
  const args={spaceId:space,taskId:task,action:'accept',expectedVersion:1,operationId:'accept_once'};
  assert.equal((await call('b','actOnTask',args)).version,2);
  assert.equal((await call('b','actOnTask',args)).version,2);
  await assert.rejects(mutate('b','actOnTask',{spaceId:space,taskId:task,action:'complete',expectedVersion:1}),/changed/);
  await assert.rejects(mutate('a','actOnTask',{spaceId:space,taskId:task,action:'complete',expectedVersion:2}),/cannot perform/);
  await mutate('b','actOnTask',{spaceId:space,taskId:task,action:'complete',expectedVersion:2});
  const events=await db.query('select event_type,recipient_uids from stewardie_core.events where entity_id=$1 order by id',[task]);
  assert.deepEqual(events.rows.map(x=>x.event_type),['taskAssigned','covered','completed']);
  assert.deepEqual(events.rows[0].recipient_uids,['b']);
  assert.deepEqual(events.rows[2].recipient_uids,['a']);
});
test('outsiders and removed members cannot read tasks or replay mutations',async()=>{
  await assert.rejects(call('c','listTasks',{spaceId:space}),/access ended/);
  await db.query('delete from stewardie_core.members where space_id=$1 and uid=$2',[space,'b']);
  await assert.rejects(call('b','listTasks',{spaceId:space}),/access ended/);
  await assert.rejects(call('b','actOnTask',{spaceId:space,taskId:task,action:'accept',expectedVersion:1,operationId:'accept_once'}),/access ended/);
});
test('Basic hides old completion, retains unfinished tasks; trusted Plus keeps history',async()=>{
  await db.query("update stewardie_core.tasks set completed_at=now()-interval '10 days',completed_local_date=current_date-10 where id=$1",[task]);
  const active=await mutate('a','createTask',{spaceId:space,title:'Old unfinished task'});
  await db.query("update stewardie_core.tasks set created_at=now()-interval '30 days' where id=$1",[active.taskId]);
  assert.equal((await call('a','listTasks',{spaceId:space})).tasks.length,1);
  await db.query("update stewardie_core.accounts set subscription_expires_at=now()+interval '1 day' where uid='a'");
  assert.equal((await call('a','listTasks',{spaceId:space})).tasks.length,2);
  await db.query("update stewardie_core.accounts set subscription_expires_at=now()-interval '1 day' where uid='a'");
  assert.equal((await call('a','listTasks',{spaceId:space})).tasks.length,1);
});
test('spam and invalid recipients are rejected atomically',async()=>{
  await assert.rejects(mutate('a','createTask',{spaceId:space,title:'hhhhhhhh'}),/clear task name/);
  await assert.rejects(mutate('a','createTask',{spaceId:space,title:'Help',requestedUid:'c'}),/current space member/);
});
test('untrusted database roles cannot impersonate accounts or fabricate events',async()=>{
  await db.exec('set role anon');
  try {
    await assert.rejects(call('a','listSpaces'),/permission denied/);
    await assert.rejects(db.exec('select * from stewardie_core.spaces'),/permission denied/);
  } finally {await db.exec('reset role');}
  await db.exec('set role authenticated');
  try {
    await assert.rejects(call('a','createSpace',{name:'Forged',operationId:'evil'}),/permission denied/);
    await assert.rejects(db.exec("insert into stewardie_core.events(space_id,actor_uid,entity_id,event_type,recipient_uids) values('x','a','a','joined','{}')"),/permission denied/);
  } finally {await db.exec('reset role');}
});
