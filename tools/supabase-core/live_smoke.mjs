// Real Firebase identity + deployed Supabase gateway smoke test. Test credentials
// are temporary and kept only in ignored .local/migration, never printed.
import {readFile,writeFile} from 'node:fs/promises';
import {randomBytes} from 'node:crypto';
import assert from 'node:assert/strict';
import config from '../../backend/firebase/functions/node_modules/firebase-tools/lib/configstore.js';
import auth from '../../backend/firebase/functions/node_modules/firebase-tools/lib/auth.js';
const endpoint='https://ulexhxfxatzlobabitpr.supabase.co/functions/v1';
const project='stewardie';
const options=await readFile(new URL('../../lib/firebase_options.dart',import.meta.url),'utf8');
const apiKey=options.match(/FirebaseOptions web[\s\S]*?apiKey: '([^']+)'/)[1];
const credential=await auth.getAccessToken(config.configstore.get('tokens')?.refresh_token,['https://www.googleapis.com/auth/cloud-platform','https://www.googleapis.com/auth/firebase']);
async function admin(action,data) {
 const res=await fetch(`https://identitytoolkit.googleapis.com/v1/projects/${project}/${action}`,{method:'POST',headers:{Authorization:`Bearer ${credential.access_token}`,'content-type':'application/json'},body:JSON.stringify(data)});
 const result=await res.json();if(!res.ok)throw new Error(`Auth fixture failed (${res.status}: ${result.error?.message})`);return result;
}
const accounts=[];let space;
async function call(account,action,payload={},expected=200) {
 const res=await fetch(`${endpoint}/core-data`,{method:'POST',headers:{Authorization:`Bearer ${account?.token??'invalid'}`,'content-type':'application/json'},body:JSON.stringify({action,payload})});
 const data=await res.json();assert.equal(res.status,expected,`${action}: ${JSON.stringify(data)}`);return data;
}
try {
 await call(null,'listSpaces',{},401);
 for(const label of ['owner','member','stranger']) {
   const uid=`core_smoke_${randomBytes(10).toString('hex')}`,email=`${uid}@example.com`,password=randomBytes(24).toString('base64url');
   await admin('accounts',{localId:uid,email,password,emailVerified:true,displayName:`Smoke ${label}`});
   accounts.push({uid,label});
   const res=await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${apiKey}`,{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({email,password,returnSecureToken:true})});
   const signed=await res.json();if(!res.ok)throw new Error(`Fixture sign in failed (${res.status})`);
   accounts.at(-1).token=signed.idToken;
 }
 await writeFile(new URL('../../.local/migration/live-fixtures.json',import.meta.url),JSON.stringify(accounts),{mode:0o600});
 const [owner,member,stranger]=accounts;
 const create={name:'Supabase smoke test',kind:'friends',timeZone:'Asia/Manila',operationId:'smoke_create'};
 space=(await call(owner,'createSpace',create)).spaceId;
 assert.equal((await call(owner,'createSpace',create)).spaceId,space);
 const code=(await call(owner,'createInvite',{spaceId:space,operationId:'smoke_invite'})).code;
 assert.equal((await call(member,'joinSpace',{code,operationId:'smoke_join'})).spaceId,space);
 assert.equal((await call(member,'docList',{path:`accounts/${member.uid}/spaceRefs`})).rows.length,1);
 const batch=await call(owner,'docReadBatch',{reads:[{action:'docRead',payload:{path:`spaces/${space}`}},{action:'docRead',payload:{path:`accounts/${member.uid}`}}]});
 assert.equal(batch.results[0].data.data.name,'Supabase smoke test');assert.equal(batch.results[1].status,403);
 await call(stranger,'getSpace',{spaceId:space},403);
 const task=(await call(owner,'createTask',{spaceId:space,title:'Test a cloud task',requestedUid:member.uid,operationId:'smoke_task'})).taskId;
 assert.equal(task,'smoke_task');
 await call(stranger,'actOnTask',{spaceId:space,taskId:task,action:'accept',expectedVersion:1,operationId:'bad_accept'},403);
 await call(member,'actOnTask',{spaceId:space,taskId:task,action:'accept',expectedVersion:1,operationId:'smoke_accept'});
 await call(member,'actOnTask',{spaceId:space,taskId:task,action:'complete',expectedVersion:2,operationId:'smoke_complete'});
 assert.equal((await call(owner,'getTask',{spaceId:space,taskId:task})).task.status,'completed');
 await call(owner,'docWrite',{path:`profiles/${owner.uid}`,data:{imageBase64:'test-avatar'}});
 assert.equal((await call(member,'docRead',{path:`profiles/${owner.uid}`})).data.imageBase64,'test-avatar');
 await call(stranger,'docRead',{path:`profiles/${owner.uid}`},403);
 await call(member,'docWrite',{path:`spaces/${space}/checkIns/${member.uid}`,data:{mood:'happy',note:'Cloud check'}});
 assert.ok((await call(owner,'docRead',{path:`spaces/${space}/checkIns/${member.uid}`})).data.expiresAt);
 const plan=await call(owner,'savePlan',{spaceId:space,title:'Cloud calendar',startMillis:Date.now()+3600000,endMillis:Date.now()+7200000,allDay:false,participants:[member.uid],operationId:'smoke_plan'});
 assert.equal((await call(member,'docRead',{path:`spaces/${space}/plans/${plan.planId}`})).data.title,'Cloud calendar');
 await call(owner,'removePlan',{spaceId:space,planId:plan.planId,expectedRevision:1,operationId:'smoke_remove_plan'});
 await call(member,'docWrite',{path:`accounts/${member.uid}`,data:{tier:'plus'}},403);
 await call(owner,'startLocationSession',{spaceId:space,durationMinutes:15,lat:13.76,lng:121.05,accuracy:12,operationId:'smoke_location'});
 assert.equal((await call(member,'readLocations',{spaceId:space})).sessions.length,1);
 await call(owner,'stopLocationSession',{spaceId:space});
 assert.equal((await call(member,'readLocations',{spaceId:space})).sessions.length,0);
 const inbox=await call(owner,'docList',{path:`accounts/${owner.uid}/activity`});assert.ok(inbox.rows.length>=2);
 const media=await fetch(`${endpoint}/media`,{method:'POST',headers:{Authorization:`Bearer ${owner.token}`,'content-type':'application/json'},body:JSON.stringify({action:'list',space})});
 assert.equal(media.status,200,`Media: ${await media.text()}`);
 const photo=await readFile(new URL('../../.local/migration/smoke-photo.jpg',import.meta.url));
 const id=`smoke_photo_${randomBytes(6).toString('hex')}`,form=new FormData();
 form.set('id',id);form.set('space',space);form.set('caption','Cloud smoke test');
 form.set('photo',new Blob([photo],{type:'image/jpeg'}),'photo.jpg');form.set('thumbnail',new Blob([photo],{type:'image/jpeg'}),'thumb.jpg');
 const uploaded=await fetch(`${endpoint}/media?action=upload`,{method:'POST',headers:{Authorization:`Bearer ${owner.token}`},body:form});
 assert.equal(uploaded.status,200,`Upload: ${await uploaded.text()}`);
 async function mediaCall(account,body) {
   const res=await fetch(`${endpoint}/media`,{method:'POST',headers:{Authorization:`Bearer ${account.token}`,'content-type':'application/json'},body:JSON.stringify({space,id,...body})});
   const data=await res.json();assert.equal(res.status,200,`Media ${body.action}: ${JSON.stringify(data)}`);return data;
 }
 const downloaded=await fetch(`${endpoint}/media`,{method:'POST',headers:{Authorization:`Bearer ${member.token}`,'content-type':'application/json'},body:JSON.stringify({space,id,action:'download'})});
 assert.equal(downloaded.status,200);assert.equal((await downloaded.arrayBuffer()).byteLength,photo.length);
 await mediaCall(member,{action:'react',type:'heart'});
 await mediaCall(owner,{action:'delete'});
 await call(owner,'removeMember',{spaceId:space,memberUid:member.uid,operationId:'smoke_remove'});
 await call(member,'getTask',{spaceId:space,taskId:task},403);
 assert.equal((await call(member,'docList',{path:`accounts/${member.uid}/activity`})).rows.length,0);
 await call(owner,'deleteSpace',{spaceId:space,operationId:'smoke_delete'});
 await call(owner,'getSpace',{spaceId:space},403);
 console.log(JSON.stringify({success:true,checks:['verified authentication','create retry','invite/join','space selection data','nonmember denial','accept/complete','profile access','forged Plus denial','location start/stop','event inbox','media without Firestore','removal denial','delete hiding']}));
}finally {
 // Only disposable authentication accounts created by this script are removed.
 for(const account of accounts)try{await admin('accounts:delete',{localId:account.uid});}catch{console.error('Disposable auth cleanup needs retry');}
 await writeFile(new URL('../../.local/migration/live-cleanup.json',import.meta.url),JSON.stringify({uids:accounts.map(a=>a.uid),space}));
}
