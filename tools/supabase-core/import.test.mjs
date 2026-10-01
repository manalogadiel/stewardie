import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {PGlite} from '@electric-sql/pglite';
import {checksum,planImport,applyImport,renderImportSql} from './import_plan.mjs';
const when='2026-10-01T01:02:03.456Z';
function fixture() {
  const account=(uid)=>({id:uid,data:{createdAt:when,tier:'plus'}});
  const roster=(uid,role)=>({id:uid,data:{uid,name:uid,role,status:'active',joinedAt:when}});
  const data={founderUid:'a',accounts:[account('a'),account('b')],invites:[{id:'Mixed_caseInvite',data:{spaceId:'original-space',creatorUid:'a',expiresAt:'2027-01-01T00:00:00Z'}}],
    spaces:[{id:'original-space',data:{name:"Our 'home'",ownerUid:'a',memberUids:['a','b'],timeZone:'Asia/Manila',createdAt:when},collections:{members:[roster('a','owner'),roster('b','member')],
    tasks:[{id:'original-task',data:{title:'Take photo',creatorUid:'a',requestedUid:'b',status:'requested',scheduledLocalDate:'2026-10-01',version:7,createdAt:when,updatedAt:when,
      pin:{latitude:13,longitude:121,source:'capture'},subtasks:[{done:false,title:'Keep'}],note:"Don't erase $core_import$; drop schema stewardie_core; --"}}]}}]};
  const bundle={schemaVersion:1,exportedAt:when,writesFrozen:true,data};bundle.checksum=checksum(data);return bundle;
}
async function database() {
 const db=new PGlite();await db.exec('create role anon;create role authenticated;create role service_role;');
 for(const file of ['202610010001_core_foundation.sql','202610010002_import_receipts.sql','202610010003_space_workflows.sql','202610010004_task_workflows.sql'])await db.exec(await readFile(new URL(`../../supabase/migrations/${file}`,import.meta.url),'utf8'));
 return db;
}
test('plan retains IDs, task metadata and case-sensitive invite; bare Plus does not grant access',()=>{
 const plan=planImport(fixture());assert.equal(plan.tasks[0].id,'original-task');assert.equal(plan.tasks[0].version,7);
 assert.equal(plan.invites[0].code,'Mixed_caseInvite');assert.equal(plan.tasks[0].details.pin.latitude,13);
 assert.equal(plan.accounts[0].founder_grant,false);assert.equal(plan.accounts[0].subscription_expires_at,null);
});
test('tampered export and inconsistent roster fail before import',()=>{
 const bundle=fixture();bundle.data.spaces[0].data.name='Changed';assert.throws(()=>planImport(bundle),/checksum/);
 bundle.checksum=checksum(bundle.data);bundle.data.spaces[0].collections.members.pop();bundle.checksum=checksum(bundle.data);
 assert.throws(()=>planImport(bundle),/roster differs/);
});
test('ownership nominees survive import; unresolved joins remain an explicit cutover gate',async()=>{
 const bundle=fixture();bundle.data.spaces[0].data.pendingOwnerUid='b';
 bundle.data.spaces[0].collections.pendingJoins=[{id:'applicant',data:{status:'pending'}}];
 bundle.checksum=checksum(bundle.data);const plan=planImport(bundle);
 assert.equal(plan.spaces[0].pending_owner_uid,'b');assert.match(plan.warnings[0].issue,/migrate before cutover/);
 const db=await database();try {
   await applyImport(db,plan);
   assert.equal((await db.query('select pending_owner_uid from stewardie_core.spaces')).rows[0].pending_owner_uid,'b');
 }finally{await db.close();}
});
test('parameterized import is atomic, deduplicated and generates no old activity',async()=>{
 const db=await database();try {
   const plan=planImport(fixture());assert.equal((await applyImport(db,plan)).alreadyImported,false);
   assert.equal((await applyImport(db,plan)).alreadyImported,true);
   const row=(await db.query('select * from stewardie_core.tasks')).rows[0];
   assert.equal(row.id,'original-task');assert.equal(row.details.subtasks[0].title,'Keep');
   assert.equal((await db.query('select count(*)::int count from stewardie_core.events')).rows[0].count,0);
   const changed=fixture();changed.data.spaces[0].data.name='Different';changed.checksum=checksum(changed.data);
   await assert.rejects(applyImport(db,planImport(changed)),/not empty/);
   assert.equal((await db.query('select count(*)::int count from stewardie_core.tasks')).rows[0].count,1);
 } finally {await db.close();}
});
test('reviewable SQL safely imports quotes and dollar delimiters, and retry is a no-op',async()=>{
 const db=await database();try {
   const plan=planImport(fixture());const sql=renderImportSql(plan);await db.exec(sql);await db.exec(sql);
   assert.equal((await db.query('select count(*)::int count from stewardie_core.members')).rows[0].count,2);
   assert.equal((await db.query('select details from stewardie_core.tasks')).rows[0].details.note,plan.tasks[0].details.note);
   const join=(await db.query("select public.stewardie_core_action('c','joinSpace',$1::jsonb) result",[JSON.stringify({code:'Mixed_caseInvite',operationId:'join-original'})])).rows[0].result;
   assert.equal(join.spaceId,'original-space');
 } finally {await db.close();}
});
test('a mid-import failure rolls back the entire batch',async()=>{
 const db=await database();try {
   const plan=planImport(fixture());plan.tasks[0].version=-1;
   await assert.rejects(applyImport(db,plan));
   assert.equal((await db.query('select count(*)::int count from stewardie_core.accounts')).rows[0].count,0);
   assert.equal((await db.query('select count(*)::int count from stewardie_core.imports')).rows[0].count,0);
 } finally {await db.close();}
});
