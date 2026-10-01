import {createHash} from 'node:crypto';

export function canonical(value) {
  if(Array.isArray(value)) return `[${value.map(canonical).join(',')}]`;
  if(value && typeof value==='object') return `{${Object.keys(value).sort().map(k=>`${JSON.stringify(k)}:${canonical(value[k])}`).join(',')}}`;
  return JSON.stringify(value);
}
export const checksum = value => createHash('sha256').update(canonical(value)).digest('hex');
const fail = message => {throw new Error(message);};
const id = value => typeof value==='string' && /^[A-Za-z0-9_-]{1,150}$/.test(value) ? value : fail('Invalid source ID');
const date = value => typeof value==='string' && Number.isFinite(Date.parse(value)) ? value : fail('Missing or invalid source timestamp');
const name = value => typeof value==='string' && value.trim().length>=1 && value.trim().length<=60 ? value.trim() : fail('Invalid name');
const day = value => typeof value==='string' && /^\d{4}-\d{2}-\d{2}$/.test(value) && new Date(`${value}T00:00:00Z`).toISOString().slice(0,10)===value ? value : fail('Invalid calendar date');
const rows = list => Array.isArray(list) ? list : fail('Missing export collection');
function unique(list,key) {const seen=new Set(); for(const row of list) {const k=key(row);if(seen.has(k))fail('Duplicate source record');seen.add(k);} }

// Input must be an operator-produced, read-only Firebase Admin export.
export function planImport(bundle) {
  if(bundle.schemaVersion!==1 || bundle.checksum!==checksum(bundle.data)) fail('Export checksum mismatch');
  const data=bundle.data;
  const accounts=rows(data.accounts).map(({id:uid,data:a})=>({uid:id(uid),
    founder_grant:uid===data.founderUid && (a.founderGrant===true || a.entitlementSource==='founder'),
    subscription_expires_at:a.tier==='plus' && a.subscription?.active===true && a.subscription?.entitlement==='stewardie_plus'
      && a.subscription?.lastVerifiedAt && a.subscriptionExpiresAt ? date(a.subscriptionExpiresAt) : null,
    created_at:date(a.createdAt ?? bundle.exportedAt)}));
  unique(accounts,x=>x.uid);
  const accountIds=new Set(accounts.map(x=>x.uid));
  const spaces=[],members=[],tasks=[],invites=[],warnings=[];
  const excluded=new Set();
  for(const source of rows(data.spaces)) {
    const s=source.data, sid=id(source.id);
    if(s.deletionStatus==='pending') {excluded.add(sid);continue;}
    if(!accountIds.has(s.ownerUid))fail('Space owner has no exported account');
    const zone=s.timeZone ?? 'Asia/Manila';
    try {new Intl.DateTimeFormat('en',{timeZone:zone}).format();} catch {fail('Invalid space time zone');}
    spaces.push({id:sid,name:name(s.name),kind:s.kind ?? 'other',time_zone:zone,owner_uid:s.ownerUid,
      require_approval:s.requireApproval===true,created_at:date(s.createdAt),deleted_at:null});
    const expected=new Set(rows(s.memberUids).map(id));
    if(expected.size!==s.memberUids.length || !expected.has(s.ownerUid) || expected.size>20)fail('Invalid membership roster');
    if(s.pendingOwnerUid!=null && (s.pendingOwnerUid===s.ownerUid || !expected.has(s.pendingOwnerUid)))fail('Invalid ownership nominee');
    spaces[spaces.length-1].pending_owner_uid=s.pendingOwnerUid ?? null;
    if(source.collections.pendingJoins?.length)warnings.push({spaceId:sid,issue:'Join requests retained in export; migrate before cutover'});
    const active=rows(source.collections.members).filter(x=>x.data.status==='active');
    unique(active,x=>x.id);
    if(active.length!==expected.size)fail('Membership roster differs from active member records');
    for(const {id:uid,data:m} of active) {
      if(!expected.has(uid) || !accountIds.has(uid) || m.uid!==uid)fail('Invalid member identity');
      if(!['owner','admin','member'].includes(m.role) || (m.role==='owner')!==(uid===s.ownerUid))fail('Invalid member role');
      members.push({space_id:sid,uid,name:name(m.name),role:m.role,joined_at:date(m.joinedAt)});
    }
    let activeTasks=0;
    for(const {id:tid,data:t} of rows(source.collections.tasks)) {
      if(!['unclaimed','requested','accepted','needsHelp','completed'].includes(t.status))fail('Unknown task state');
      if(typeof t.title!=='string' || t.title.trim().length<1 || t.title.trim().length>100 || !Number.isInteger(t.version) || t.version<1)fail('Invalid task title/version');
      if(t.status!=='completed') {
        activeTasks++;
        for(const uid of [t.ownerUid,t.requestedUid,t.offeredUid]) if(uid!=null && !expected.has(uid))fail('Unfinished task assigned to absent member; repair source before import');
      }
      if(t.status==='requested' && !t.requestedUid || ['accepted','needsHelp'].includes(t.status) && !t.ownerUid)fail('Task state has no responsible member');
      const completed=t.status==='completed';
      if(!completed && t.completedAt!=null)fail('Unfinished task has completion timestamp');
      const details={...t};
      for(const key of ['title','creatorUid','ownerUid','requestedUid','offeredUid','status','scheduledLocalDate','completedAt','completedLocalDate','version','createdAt','updatedAt']) delete details[key];
      // Account cleanup can remove historical creator attribution. Keep it
      // anonymous rather than assigning the record to the space owner.
      tasks.push({space_id:sid,id:id(tid),title:t.title.trim(),creator_uid:t.creatorUid == null || t.creatorUid === '' ? '' : id(t.creatorUid),owner_uid:t.ownerUid ?? null,
        requested_uid:t.requestedUid ?? null,offered_uid:t.offeredUid ?? null,status:t.status,
        scheduled_local_date:day(t.scheduledLocalDate),completed_at:completed?date(t.completedAt):null,
        completed_local_date:completed?day(t.completedLocalDate):null,version:t.version,details,
        created_at:date(t.createdAt),updated_at:date(t.updatedAt)});
    }
    if(activeTasks>300)fail('Active task cap exceeded');
    if(s.activeTaskCount!=null && s.activeTaskCount!==activeTasks)warnings.push({spaceId:sid,issue:'Stored task counter differs; SQL uses real rows'});
  }
  unique(spaces,x=>x.id); unique(members,x=>`${x.space_id}/${x.uid}`); unique(tasks,x=>`${x.space_id}/${x.id}`);
  const spaceIds=new Set(spaces.map(x=>x.id));
  for(const {id:code,data:v} of rows(data.invites)) {
    if(excluded.has(v.spaceId))continue;
    if(!spaceIds.has(v.spaceId)) {warnings.push({issue:'Orphan invite excluded'});continue;}
    // Existing tokens are case-sensitive: preserve them verbatim.
    invites.push({code:id(code),space_id:v.spaceId,created_by:id(v.createdBy ?? v.createdByUid ?? v.creatorUid),
      expires_at:date(v.expiresAt),revoked:v.revoked===true,redeemed_uid:v.redeemedUid ?? null,require_approval:v.requireApproval===true});
  }
  unique(invites,x=>x.code);
  return {checksum:bundle.checksum,accounts,spaces,members,tasks,invites,warnings,
    counts:{accounts:accounts.length,spaces:spaces.length,members:members.length,tasks:tasks.length,invites:invites.length,excludedSpaces:excluded.size}};
}

// Parameters protect content containing apostrophes, backslashes and SQL-like text.
export async function applyImport(db,plan) {
  await db.exec('begin');
  try {
    await db.query('select pg_advisory_xact_lock(73192841)');
    const receipt=await db.query('select checksum from stewardie_core.imports where checksum=$1',[plan.checksum]);
    if(receipt.rows.length) {await db.exec('commit');return {alreadyImported:true};}
    const occupied=await db.query('select count(*)::int count from stewardie_core.spaces');
    const accounts=await db.query('select count(*)::int count from stewardie_core.accounts');
    if(occupied.rows[0].count!==0 || accounts.rows[0].count!==0)fail('Destination is not empty; refuse overwrite or merge');
    for(const table of ['accounts','spaces','members','tasks','invites']) {
      if(!plan[table].length)continue;
      await db.query(`insert into stewardie_core.${table} select * from jsonb_populate_recordset(null::stewardie_core.${table},$1::jsonb)`,[JSON.stringify(plan[table])]);
    }
    await db.query('insert into stewardie_core.imports(checksum,counts) values($1,$2::jsonb)',[plan.checksum,JSON.stringify(plan.counts)]);
    await db.exec('commit');
    return {alreadyImported:false};
  } catch(error) {await db.exec('rollback');throw error;}
}

export function renderImportSql(plan) {
  const literal=x=>`'${JSON.stringify(x).replaceAll("'","''")}'::jsonb`;
  const statements=[`if not exists(select 1 from stewardie_core.imports where checksum='${plan.checksum}') then\nif exists(select 1 from stewardie_core.spaces) or exists(select 1 from stewardie_core.accounts) then raise exception 'Destination is not empty'; end if;`];
  for(const table of ['accounts','spaces','members','tasks','invites'])
    if(plan[table].length)statements.push(`insert into stewardie_core.${table} select * from jsonb_populate_recordset(null::stewardie_core.${table},${literal(plan[table])});`);
  statements.push(`insert into stewardie_core.imports(checksum,counts) values('${plan.checksum}',${literal(plan.counts)});\nend if;`);
  const body=statements.join('\n');
  let delimiter='$core_import$';
  while(body.includes(delimiter))delimiter=delimiter.slice(0,-1)+'_$';
  return `begin;\nset local standard_conforming_strings=on;\nselect pg_advisory_xact_lock(73192841);\ndo ${delimiter} begin\n${body}\nend ${delimiter};\ncommit;`;
}
