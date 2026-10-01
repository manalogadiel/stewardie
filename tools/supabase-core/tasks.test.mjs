import {PGlite} from '@electric-sql/pglite';
import {readFile} from 'node:fs/promises';
import test,{before,after} from 'node:test';
import assert from 'node:assert/strict';
const db=new PGlite();let seq=0,space,task;
const call=async(uid,action,payload={})=>(await db.query('select public.stewardie_core_action($1,$2,$3::jsonb) result',[uid,action,JSON.stringify(payload)])).rows[0].result;
const mutate=(uid,action,payload={})=>call(uid,action,{operationId:`task_${++seq}`,...payload});
before(async()=>{
  await db.exec('create role anon;create role authenticated;create role service_role;');
  for(const file of ['202610010001_core_foundation.sql','202610010002_import_receipts.sql','202610010003_space_workflows.sql','202610010004_task_workflows.sql'])
    await db.exec(await readFile(new URL(`../../supabase/migrations/${file}`,import.meta.url),'utf8'));
  space=(await mutate('creator','createSpace',{name:'Home'})).spaceId;
  const code=(await mutate('creator','createInvite',{spaceId:space})).code;
  await mutate('member','joinSpace',{code});
  task=(await mutate('creator','createTask',{spaceId:space,title:'Wash',requestedUid:'member'})).taskId;
});
after(()=>db.close());
test('task content edits validate fields, preserve metadata and reject stale writes',async()=>{
  await db.query("update stewardie_core.tasks set details=details||'{\"photoIds\":[\"keep-photo\"]}' where id=$1",[task]);
  const args={spaceId:space,taskId:task,expectedVersion:1,patch:{title:'Wash dishes',pin:{lat:13,lng:121,label:'Home',source:'manual'},notes:'After lunch'},operationId:'edit-once'};
  assert.equal((await call('member','updateTask',args)).version,2);
  assert.equal((await call('member','updateTask',args)).version,2);
  const row=(await call('member','getTask',{spaceId:space,taskId:task})).task;
  assert.equal(row.title,'Wash dishes');assert.deepEqual(row.details.photoIds,['keep-photo']);
  await assert.rejects(mutate('creator','updateTask',{...args,expectedVersion:1,operationId:'stale'}),/changed/);
  await assert.rejects(mutate('creator','updateTask',{spaceId:space,taskId:task,expectedVersion:2,patch:{creatorUid:'member'}}),/Unsupported/);
  await assert.rejects(mutate('member','updateTask',{spaceId:space,taskId:task,expectedVersion:2,patch:{requestedUid:'creator'}}),/handoff/);
  await assert.rejects(mutate('creator','updateTask',{spaceId:space,taskId:task,expectedVersion:2,patch:{requestedUid:'stranger'}}),/current member/);
});
test('subtasks share version protection and invalid content never commits',async()=>{
  const subtasks=[{id:'sub-1',title:'Rinse',done:true}];
  assert.equal((await mutate('member','setSubtasks',{spaceId:space,taskId:task,expectedVersion:2,subtasks})).version,3);
  await assert.rejects(mutate('member','setSubtasks',{spaceId:space,taskId:task,expectedVersion:3,subtasks:[{title:'Bad',done:'true'}]}),/Invalid subtask/);
  await assert.rejects(mutate('member','updateTask',{spaceId:space,taskId:task,expectedVersion:3,patch:{pin:{lat:100,lng:121,label:'Invalid'}}}),/Invalid place/);
  await assert.rejects(mutate('member','createTask',{spaceId:space,title:'New',pin:{lat:'13',lng:121,label:'Invalid'}}),/Invalid place/);
  const row=(await call('creator','getTask',{spaceId:space,taskId:task})).task;
  assert.equal(row.version,3);assert.deepEqual(row.details.subtasks,subtasks);
});
test('creator reassignment emits one direct request and acceptance still works',async()=>{
  await mutate('creator','updateTask',{spaceId:space,taskId:task,expectedVersion:3,patch:{requestedUid:null}});
  await mutate('creator','updateTask',{spaceId:space,taskId:task,expectedVersion:4,patch:{requestedUid:'member'}});
  const e=(await db.query("select * from stewardie_core.events where entity_id=$1 and event_type='taskAssigned' order by id desc limit 1",[task])).rows[0];
  assert.deepEqual(e.recipient_uids,['member']);assert.equal(e.task_version,5);
  await mutate('member','actOnTask',{spaceId:space,taskId:task,expectedVersion:5,action:'accept'});
  await mutate('member','actOnTask',{spaceId:space,taskId:task,expectedVersion:6,action:'complete'});
  await assert.rejects(mutate('creator','updateTask',{spaceId:space,taskId:task,expectedVersion:7,patch:{title:'No'}}),/Completed tasks/);
});
test('single-task reads enforce history and membership; safe deletion does not require Plus',async()=>{
  await db.query("update stewardie_core.tasks set completed_at=now()-interval '10 days',completed_local_date=current_date-10 where id=$1",[task]);
  await assert.rejects(call('creator','getTask',{spaceId:space,taskId:task}),/history unavailable/);
  await db.query("update stewardie_core.accounts set founder_grant=true where uid='creator'");
  assert.equal((await call('creator','getTask',{spaceId:space,taskId:task})).task.id,task);
  await assert.rejects(call('stranger','getTask',{spaceId:space,taskId:task}),/access ended/);
  await assert.rejects(mutate('stranger','deleteTask',{spaceId:space,taskId:task,expectedVersion:7}),/access ended/);
  const args={spaceId:space,taskId:task,expectedVersion:7,operationId:'delete-task-once'};
  assert.equal((await call('member','deleteTask',args)).removed,true);
  assert.equal((await call('member','deleteTask',args)).removed,true);
  assert.equal((await db.query("select count(*)::int n from stewardie_core.events where entity_id=$1 and event_type='taskCancelled'",[task])).rows[0].n,1);
  await mutate('member','leaveSpace',{spaceId:space});
  await assert.rejects(call('member','deleteTask',args),/access ended/);
});
