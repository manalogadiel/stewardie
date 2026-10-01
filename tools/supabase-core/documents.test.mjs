import {PGlite} from '@electric-sql/pglite';
import {readFile} from 'node:fs/promises';
import test,{before,after} from 'node:test';
import assert from 'node:assert/strict';
const db=new PGlite();let space,other,task,seq=0;
const rpc=async(fn,uid,action,payload={})=>(await db.query(`select public.${fn}($1,$2,$3::jsonb) result`,[uid,action,JSON.stringify(payload)])).rows[0].result;
const core=(uid,action,payload={})=>rpc('stewardie_core_action',uid,action,{operationId:`doc_${++seq}`,...payload});
const docs=(uid,action,payload={})=>rpc('stewardie_core_documents',uid,action,payload);
const feature=(uid,action,payload={})=>rpc('stewardie_core_features',uid,action,{operationId:`feature_${++seq}`,...payload});
before(async()=>{
 await db.exec('create role anon;create role authenticated;create role service_role;');
 for(const name of ['202610010001_core_foundation','202610010002_import_receipts','202610010003_space_workflows','202610010004_task_workflows','202610010005_documents','202610010006_features','202610010007_service_bridge','202610010008_task_identity','202610010009_cutover_hardening','202610010010_social_events','202610010011_notification_delivery','202610010012_default_preferences'])
   await db.exec(await readFile(new URL(`../../supabase/migrations/${name}.sql`,import.meta.url),'utf8'));
 space=(await core('owner','createSpace',{name:'Home'})).spaceId;
 other=(await core('owner','createSpace',{name:'Other'})).spaceId;
 for(const sid of [space,other]) {
   const code=(await core('owner','createInvite',{spaceId:sid})).code;
   await core('member','joinSpace',{code});
 }
 task=(await core('owner','createTask',{spaceId:space,title:'Wash',requestedUid:'member'})).taskId;
});
after(()=>db.close());
test('service bridge is protected and task IDs retain durable client identity',async()=>{
 await db.exec('set role authenticated');
 await assert.rejects(db.query("select public.stewardie_core_service('list','spaces','{}')"),/permission denied/);
 await db.exec('reset role');
 const payload={spaceId:space,title:'Client draft',operationId:'durable_client_id'};
 assert.equal((await core('owner','createTask',payload)).taskId,'durable_client_id');
 assert.equal((await core('owner','createTask',payload)).taskId,'durable_client_id');
 const result=(await db.query("select public.stewardie_core_service('list','spaces','{}') result")).rows[0].result;
 assert.equal(result.rows.length,2);
 await db.query("select public.stewardie_core_service('reconcile','accounts/member',$1::jsonb)",[JSON.stringify({tier:'plus',entitlementSource:'store',subscriptionExpiresAt:new Date(Date.now()+3600000).toISOString()})]);
 assert.equal((await docs('member','docRead',{path:'accounts/member'})).data.tier,'plus');
});
test('document views synthesize memberships and cannot grant Plus or forge events',async()=>{
 assert.equal((await docs('owner','docList',{path:'accounts/owner/spaceRefs'})).rows.length,2);
 assert.equal((await docs('owner','docRead',{path:`spaces/${space}`})).data.memberCount,2);
 await assert.rejects(docs('owner','docWrite',{path:'accounts/owner',data:{tier:'plus'}}),/Protected/);
 await assert.rejects(docs('owner','docWrite',{path:`spaces/${space}/events/fake`,data:{type:'completed'}}),/protected workflow/);
 await assert.rejects(docs('stranger','docRead',{path:`spaces/${space}`} ),/access ended/);
});
test('coalesced reads isolate denied paths and cannot smuggle a write',async()=>{
 const result=await docs('owner','docReadBatch',{reads:[
   {action:'docRead',payload:{path:`spaces/${space}`}},
   {action:'docRead',payload:{path:'accounts/stranger'}},
   {action:'docWrite',payload:{path:'accounts/owner',data:{tier:'plus'}}}]});
 assert.equal(result.results[0].data.data.name,'Home');
 assert.equal(result.results[1].status,403);assert.equal(result.results[2].status,503);
 assert.equal((await docs('owner','docRead',{path:'accounts/owner'})).data.tier,'basic');
});
test('profiles require self writes and current shared membership for reads',async()=>{
 await docs('owner','docWrite',{path:'profiles/owner',data:{imageBase64:'example',updatedAt:{_serverTime:true}}});
 assert.equal((await docs('member','docRead',{path:'profiles/owner'})).data.imageBase64,'example');
 await assert.rejects(docs('stranger','docRead',{path:'profiles/owner'}),/Profile access denied/);
 await assert.rejects(docs('member','docWrite',{path:'profiles/owner',data:{imageBase64:'forged'}}),/Profile access denied/);
 await feature('owner','profileName',{name:'Diel'});
 assert.equal((await docs('member','docRead',{path:`spaces/${space}/members/owner`})).data.name,'Diel');
});
test('preferences batch is atomic and cannot write another account',async()=>{
 await docs('member','docWrite',{path:'accounts/member/notificationPrefs/global',data:{enabled:false}});
 await docs('member','docWrite',{path:'accounts/member/notificationPrefs/global',mode:'createIfAbsent',data:{enabled:true}});
 assert.equal((await docs('member','docRead',{path:'accounts/member/notificationPrefs/global'})).data.enabled,false);
 await assert.rejects(docs('owner','docBatch',{writes:[{path:'accounts/owner/notificationPrefs/global',data:{enabled:true}},{path:'accounts/member/notificationPrefs/global',data:{enabled:false}}]}),/Account access denied/);
 assert.equal((await docs('owner','docRead',{path:'accounts/owner/notificationPrefs/global'})).data,null);
});
test('moods expire at space-local midnight and plans/routines enforce ownership and caps',async()=>{
 const path=`spaces/${space}/checkIns/member`;
 await docs('member','docWrite',{path,data:{mood:'happy',note:'Hello'}});
 assert.equal((await docs('owner','docRead',{path})).data.uid,'member');
 await db.query("update stewardie_core.documents set data=jsonb_set(data,'{localDate}','\"2000-01-01\"') where path=$1",[path]);
 assert.equal((await docs('owner','docRead',{path})).data,null);
 await feature('owner','savePlan',{spaceId:space,planId:'plan',title:'Dinner',startMillis:100,endMillis:200,allDay:false,expectedRevision:0});
 await assert.rejects(feature('owner','savePlan',{spaceId:space,planId:'plan',title:'Dinner',startMillis:100,endMillis:200,expectedRevision:0}),/plan changed/);
 await assert.rejects(feature('member','removePlan',{spaceId:space,planId:'plan'}),/creator/);
 for(let i=0;i<5;i++)await feature('owner','createRoutine',{spaceId:space,routineId:`r${i}`,title:'Dishes',cadence:'daily'});
 await assert.rejects(feature('owner','createRoutine',{spaceId:space,routineId:'r6',title:'Dishes',cadence:'daily'}),/five routines/);
});
test('live location is explicit, space scoped, server expired and stops after removal',async()=>{
 await feature('owner','startLocationSession',{spaceId:space,durationMinutes:15,lat:13,lng:121,accuracy:10});
 assert.equal((await feature('member','readLocations',{spaceId:space})).sessions.length,1);
 assert.equal((await feature('member','readLocations',{spaceId:other})).sessions.length,0);
 const initial=(await docs('owner','docRead',{path:`spaces/${space}/locationSessions/owner`})).data;
 await feature('owner','updateLocation',{spaceId:space,lat:13.1,lng:121,accuracy:10});
 assert.equal((await docs('owner','docRead',{path:`spaces/${space}/locationSessions/owner`})).data.expiresAt,initial.expiresAt);
 await assert.rejects(feature('stranger','readLocations',{spaceId:space}),/access ended/);
 await feature('owner','stopLocationSession',{spaceId:space});
 assert.equal((await feature('member','readLocations',{spaceId:space})).sessions.length,0);
});
test('inbox deduplicates events, read state persists and removal hides restricted items',async()=>{
 const path='accounts/member/activity';
 const first=await docs('member','docList',{path});const second=await docs('member','docList',{path});
 assert.deepEqual(first.rows.map(r=>r.id),second.rows.map(r=>r.id));
 const assignment=first.rows.find(r=>r.data.kind==='taskAssigned');assert.ok(assignment);
 await docs('member','docWrite',{path:`${path}/${assignment.id}`,mode:'update',data:{readAt:{_serverTime:true}}});
 assert.ok((await docs('member','docRead',{path:`${path}/${assignment.id}`})).data.readAt);
 await core('member','leaveSpace',{spaceId:space});
 assert.equal((await docs('member','docRead',{path:`${path}/${assignment.id}`})).data,null);
 assert.equal((await docs('member','docList',{path})).rows.some(r=>r.data.spaceId===space),false);
});
