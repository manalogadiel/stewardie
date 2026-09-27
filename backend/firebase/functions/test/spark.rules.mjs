import {readFileSync} from 'node:fs';
import {test, before, after, beforeEach} from 'node:test';
import {initializeTestEnvironment, assertFails, assertSucceeds} from '@firebase/rules-unit-testing';
import {serverTimestamp, Timestamp as ClientTimestamp, arrayUnion, increment} from 'firebase/firestore';
let env;
before(async()=>{env=await initializeTestEnvironment({projectId:'demo-stewardie-spark',firestore:{host:'127.0.0.1',port:8080,rules:readFileSync(new URL('../../firestore.rules',import.meta.url),'utf8')}});});
after(async()=>env?.cleanup());
const db=(uid,verified=true)=>env.authenticatedContext(uid,{email_verified:verified}).firestore();
const now=()=>serverTimestamp();
beforeEach(async()=>{
 await env.clearFirestore();
 await env.withSecurityRulesDisabled(async c=>{
  const d=c.firestore();
  for(const uid of ['alice','bob']) await d.doc(`accounts/${uid}`).set({tier:uid==='alice'?'plus':'basic',founderGrant:uid==='alice',spaceIds:['home'],ownedSpaceIds:uid==='alice'?['home']:[]});
  await d.doc('spaces/home').set({name:'Home',kind:'family',timeZone:'UTC',ownerUid:'alice',memberUids:['alice','bob'],memberCount:2,activeTaskCount:1});
  for(const uid of ['alice','bob']) {await d.doc(`spaces/home/members/${uid}`).set({uid,name:uid,role:uid==='alice'?'owner':'member',status:'active'});await d.doc(`accounts/${uid}/spaceRefs/home`).set({name:'Home'});}
  await d.doc('spaces/home/tasks/task').set({title:'Dishes',creatorUid:'alice',status:'requested',requestedUid:'bob',ownerUid:null,offeredUid:null,version:1,completedAt:null});
  await d.doc('spaces/home/tasks/old').set({title:'Old',status:'completed',completedAt:ClientTimestamp.fromMillis(Date.now()-10*86400000)});
 });
});
test('Spark rejects outsiders, unverified users, forged tiers, roles, refs and invite lists',async()=>{
 await assertFails(db('outsider').doc('spaces/home').get());
 await assertFails(db('alice',false).doc('spaces/home').get());
 await assertFails(db('bob').doc('accounts/bob').update({tier:'plus'}));
 await assertFails(db('bob').doc('spaces/home/members/bob').update({role:'owner'}));
 await assertFails(db('outsider').doc('accounts/outsider/spaceRefs/home').set({name:'Home'}));
 await assertFails(db('bob').collection('invites').get());
 await assertSucceeds(db('alice').doc('spaces/home').get());
 await assertSucceeds(db('bob').collection('spaces/home/tasks').where('status','!=','completed').get());
});
test('Spark task acceptance is recipient-only and completion needs an atomic count change',async()=>{
 const d=db('bob'), task=d.doc('spaces/home/tasks/task');
 const accept={status:'accepted',ownerUid:'bob',requestedUid:null,offeredUid:null,version:2,updatedAt:now()};
 await assertFails(db('alice').doc('spaces/home/tasks/task').update({...accept,ownerUid:'alice'}));
 await assertSucceeds(task.update(accept));
 await assertFails(task.update({status:'completed',completedAt:now(),version:3,updatedAt:now()}));
 const batch=d.batch();batch.update(task,{status:'completed',completedAt:now(),version:3,updatedAt:now()});batch.update(d.doc('spaces/home'),{activeTaskCount:0,changedTaskId:'task'});
 batch.set(d.doc('spaces/home/taskCompletions/task'),{title:'Dishes',ownerUid:'bob',completedAt:now()});
 await assertSucceeds(batch.commit());
 await assertSucceeds(db('alice').doc('spaces/home/taskCompletions/task').get());
 await assertFails(db('outsider').doc('spaces/home/taskCompletions/task').get());
 await assertFails(db('alice').doc('spaces/home/taskCompletions/task').update({title:'Forged'}));
 await assertFails(db('alice').doc('spaces/home/taskCompletions/old').set({title:'Forged',ownerUid:'alice',completedAt:now()}));
 await assertFails(db('alice').collection('spaces/home/taskCompletions').get());
 await assertFails(db('bob').doc('spaces/home/tasks/old').get());
 await assertSucceeds(db('alice').doc('spaces/home/tasks/old').get());
});
test('Spark moods persist with expiry; peers cannot overwrite them or plans',async()=>{
 const utc=new Date();utc.setUTCHours(24,0,0,0);
 const mood={uid:'bob',mood:'happy',color:'sky',note:'Hello',updatedAt:now(),expiresAt:ClientTimestamp.fromDate(utc)};
 await assertSucceeds(db('bob').doc('spaces/home/checkIns/bob').set(mood));
 await assertSucceeds(db('alice').doc('spaces/home/checkIns/bob').get());
 await assertFails(db('alice').doc('spaces/home/checkIns/bob').set(mood));
 await assertFails(db('bob').doc('spaces/home/checkIns/bob').update({expiresAt:ClientTimestamp.fromMillis(Date.now()+7*86400000)}));
 const plan={ownerUid:'bob',title:'Walk',note:'',allDay:false,startMillis:1,endMillis:2,participants:['alice'],revision:1,reminder:'none',updatedAt:now()};
 await assertSucceeds(db('bob').doc('spaces/home/plans/walk').set(plan));
 await assertFails(db('alice').doc('spaces/home/plans/walk').update({ownerUid:'alice'}));
 await assertFails(db('alice').doc('spaces/home/plans/walk').delete());
});
test('location sessions restrict recipients and expire at the server',async()=>{
 const d=db('alice');
 const location={uid:'alice',name:'Alice',lat:14.6,lng:121,accuracy:25,
  recipientUids:['alice','bob'],durationMinutes:15,startedAt:now(),updatedAt:now(),
  expiresAt:ClientTimestamp.fromMillis(Date.now()+14*60000)};
 await assertFails(d.doc('spaces/home/locationSessions/alice').set({...location,lat:999}));
 await assertSucceeds(d.doc('spaces/home/locationSessions/alice').set(location));
 await assertSucceeds(db('bob').doc('spaces/home/locationSessions/alice').get());
 await assertFails(db('outsider').doc('spaces/home/locationSessions/alice').get());
 await assertFails(db('bob').collection('spaces/home/locationSessions').get());
 await assertFails(db('bob').doc('spaces/home/locationSessions/alice').delete());
 await assertSucceeds(d.doc('spaces/home/locationSessions/alice').delete());
});
test('routine quotas and private activity are enforced',async()=>{
 const d=db('bob');
 const routine={id:'morning',title:'Water plants',cadence:'daily',assignedUid:null,creatorUid:'bob',createdAt:now()};
 await assertFails(d.doc('spaces/home/routines/morning').set(routine));
 const batch=d.batch();
 batch.set(d.doc('spaces/home/routines/morning'),routine);
 batch.update(d.doc('spaces/home'),{routineCount:1,changedRoutineId:'morning'});
 await assertSucceeds(batch.commit());
 await assertFails(db('outsider').doc('spaces/home/routines/morning').delete());
 await assertFails(d.doc('accounts/bob/activity/test').set({title:'forged'}));
 await env.withSecurityRulesDisabled(async c=>{
  await c.firestore().doc('accounts/bob/activity/test').set({spaceId:'home',title:'Reminder',body:'Open the task',createdAt:ClientTimestamp.now(),readAt:null});
 });
 await assertSucceeds(d.doc('accounts/bob/activity/test').update({readAt:now()}));
 await assertFails(db('alice').doc('accounts/bob/activity/test').get());
 const preferences={enabled:true,quietStart:1320,quietEnd:420,timeZone:'Asia/Manila',updatedAt:now()};
 await assertSucceeds(d.doc('accounts/bob/notificationPrefs/global').set(preferences));
 await assertSucceeds(d.doc('accounts/bob/notificationPrefs/home').set(preferences));
 await assertFails(d.doc('accounts/bob/notificationPrefs/other').set(preferences));
 await assertFails(db('alice').doc('accounts/bob/notificationPrefs/global').get());
});
test('Spark creation preserves Plus and enforces protected account lists',async()=>{
 const d=db('alice'), b=d.batch();
 b.set(d.doc('spaces/new'),{name:'New',kind:'crew',timeZone:'UTC',ownerUid:'alice',memberUids:['alice'],memberCount:1,activeTaskCount:0,createdAt:now()});
 b.set(d.doc('spaces/new/members/alice'),{uid:'alice',name:'Alice',role:'owner',status:'active',joinedAt:now()});
 b.update(d.doc('accounts/alice'),{spaceIds:['home','new'],ownedSpaceIds:['home','new'],changedSpaceId:'new'});
 b.set(d.doc('accounts/alice/spaceRefs/new'),{spaceId:'new',name:'New',kind:'crew',joinedAt:now()});
 await assertSucceeds(b.commit());
 await assertFails(d.doc('accounts/alice').update({ownedSpaceIds:[],spaceIds:[],changedSpaceId:'home'}));
});
test('Spark invitation redemption is atomic, one-use, and owner issued',async()=>{
 const token='a'.repeat(32), invite={spaceId:'home',spaceName:'Home',kind:'family',creatorUid:'alice',createdAt:now(),expiresAt:ClientTimestamp.fromMillis(Date.now()+86400000),redeemedUid:null,revoked:false,requireApproval:false};
 await assertFails(db('bob').doc(`invites/${token}`).set({...invite,creatorUid:'bob'}));
 await assertSucceeds(db('alice').doc(`invites/${token}`).set(invite));
 const d=db('newcomer'),b=d.batch();
 b.update(d.doc(`invites/${token}`),{redeemedUid:'newcomer'});
 b.update(d.doc('spaces/home'),{memberUids:arrayUnion('newcomer'),memberCount:increment(1),joinToken:token});
 b.set(d.doc('spaces/home/members/newcomer'),{uid:'newcomer',name:'New',role:'member',status:'active',joinedAt:now(),joinToken:token});
 b.set(d.doc('accounts/newcomer'),{tier:'basic',spaceIds:['home'],ownedSpaceIds:[],changedSpaceId:'home'});
 b.set(d.doc('accounts/newcomer/spaceRefs/home'),{spaceId:'home',name:'Home',kind:'family',joinedAt:now()});
 await assertSucceeds(b.commit());
 await assertFails(db('outsider').doc(`invites/${token}`).update({redeemedUid:'outsider'}));
});
test('Spark removal releases tasks and revokes access; a member cannot remove peers',async()=>{
 const d=db('alice'),b=d.batch();
 b.update(d.doc('spaces/home'),{memberUids:['alice'],memberCount:1,removedUid:'bob'});
 b.update(d.doc('spaces/home/members/bob'),{status:'removed'});
 b.delete(d.doc('accounts/bob/spaceRefs/home'));
 b.update(d.doc('accounts/bob'),{spaceIds:[],ownedSpaceIds:[],changedSpaceId:'home'});
 b.update(d.doc('spaces/home/tasks/task'),{status:'unclaimed',requestedUid:null,ownerUid:null,offeredUid:null,version:2,updatedAt:now()});
 await assertSucceeds(b.commit());
 await assertFails(db('bob').doc('spaces/home').get());
 await assertFails(db('bob').doc('spaces/home/tasks/task').get());
});

test('blocking stops new direct requests and reports stay private',async()=>{
 const blocked={blockedUid:'alice',createdAt:now()};
 await assertSucceeds(db('bob').doc('accounts/bob/blocks/alice').set(blocked));
 await assertFails(db('alice').doc('accounts/bob/blocks/alice').get());
 const d=db('alice'),b=d.batch();
 b.set(d.doc('spaces/home/tasks/blocked'),{title:'Help',creatorUid:'alice',requestedUid:'bob',ownerUid:null,offeredUid:null,status:'requested',scheduledLocalDate:'2026-09-28',version:1,completedAt:null,createdAt:now(),updatedAt:now()});
 b.update(d.doc('spaces/home'),{activeTaskCount:2,changedTaskId:'blocked'});
 await assertFails(b.commit());
 const report={reporterUid:'bob',spaceId:'home',kind:'member',contentId:'alice',targetUid:'alice',reason:'harassment',status:'open',createdAt:now()};
 await assertSucceeds(db('bob').doc('safetyReports/example').set(report));
 await assertFails(db('bob').doc('safetyReports/example').get());
 const founder=env.authenticatedContext('alice',{email_verified:true,email:'gadielmanalo19@gmail.com'}).firestore();
 await assertSucceeds(founder.doc('safetyReports/example').get());
});

test('Spark ownership requires consent and preserves account ownership quotas',async()=>{
 await assertFails(db('bob').doc('spaces/home').update({ownerUid:'bob'}));
 await assertSucceeds(db('alice').doc('spaces/home').update({pendingOwnerUid:'bob'}));
 const d=db('bob'), b=d.batch();
 b.update(d.doc('spaces/home'),{ownerUid:'bob',pendingOwnerUid:null});
 b.update(d.doc('accounts/bob'),{ownedSpaceIds:['home'],changedSpaceId:'home'});
 b.update(d.doc('accounts/alice'),{ownedSpaceIds:[],changedSpaceId:'home'});
 b.update(d.doc('spaces/home/members/bob'),{role:'owner'});
 b.update(d.doc('spaces/home/members/alice'),{role:'member'});
 await assertSucceeds(b.commit());
});
test('Spark Basic history query and deterministic task creation work without functions',async()=>{
 const d=db('bob');
 const cutoff=new Date();cutoff.setUTCHours(0,0,0,0);cutoff.setUTCDate(cutoff.getUTCDate()-3);
 await assertSucceeds(d.collection('spaces/home/tasks').where('status','==','completed').where('completedAt','>=',ClientTimestamp.fromDate(cutoff)).orderBy('completedAt','desc').get());
 const ref=d.doc('spaces/home/tasks/newtask');
 await assertSucceeds(d.runTransaction(async tx=>{
  const old=await tx.get(ref);const parent=await tx.get(d.doc('spaces/home'));
  if(old.exists)return;
  tx.set(ref,{title:'A new task',creatorUid:'bob',requestedUid:'alice',ownerUid:null,offeredUid:null,status:'requested',scheduledLocalDate:'2026-09-24',version:1,completedAt:null,createdAt:now(),updatedAt:now()});
  tx.update(d.doc('spaces/home'),{activeTaskCount:parent.data().activeTaskCount+1,changedTaskId:'newtask'});
 }));
});
